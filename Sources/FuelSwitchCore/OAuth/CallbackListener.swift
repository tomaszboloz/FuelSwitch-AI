import Foundation
import Network

private final class StartHandle: @unchecked Sendable {
    let semaphore = DispatchSemaphore(value: 0)
    var error: Error?
}

/// An HTTP server that serves exactly one redirect from the browser.
public final class CallbackListener: @unchecked Sendable {
    private enum State {
        case idle, finished
        case awaitingWaiter(CheckedContinuation<String, Error>)
        case resultReady(Result<String, Error>)
    }

    private let requestedPort: UInt16
    private var listener: NWListener?
    private var expectedState = ""
    private var expectedPath = "/callback"
    private var state: State = .idle
    private let queue = DispatchQueue(label: "ai.fuelswitch.callback")

    public init(port: UInt16) {
        self.requestedPort = port
    }
    public func start(expectedState: String, expectedPath: String) throws -> UInt16 {
        self.expectedState = expectedState
        self.expectedPath = expectedPath

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = false
        let nwPort = NWEndpoint.Port(rawValue: requestedPort) ?? .any

        guard let listener = try? NWListener(using: parameters, on: nwPort) else {
            throw OAuthError.portInUse(requestedPort)
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }

        let handle = StartHandle()
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready: handle.semaphore.signal()
            case .failed(let error):
                handle.error = error
                handle.semaphore.signal()
            default: break
            }
        }
        listener.start(queue: queue)
        _ = handle.semaphore.wait(timeout: .now() + 3)
        if handle.error != nil || listener.port == nil {
            listener.cancel()
            throw OAuthError.portInUse(requestedPort)
        }
        self.listener = listener
        return listener.port!.rawValue
    }

    public func waitForCode() async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            queue.async {
                switch self.state {
                case .idle:
                    self.state = .awaitingWaiter(continuation)
                case .resultReady(let result):
                    self.state = .finished
                    continuation.resume(with: result)
                case .awaitingWaiter, .finished:
                    continuation.resume(throwing: OAuthError.responseWithoutToken)
                }
            }
        }
    }

    public func stop() {
        queue.sync {
            switch state {
            case .awaitingWaiter(let continuation):
                state = .finished
                continuation.resume(throwing: OAuthError.cancelled)
            case .idle, .resultReady:
                state = .finished
            case .finished:
                break
            }
            listener?.cancel()
            listener = nil
        }
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        read(connection, soFar: Data())
    }

    private func read(_ connection: NWConnection, soFar: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = soFar
            if let data { buffer.append(data) }

            if buffer.count > CallbackHTTPParser.maximumRequestSize {
                CallbackHTTPParser.respond(connection, message: "<h1>Request too large</h1>", statusCode: 413)
                return
            }

            if buffer.range(of: Data("\r\n\r\n".utf8)) != nil {
                self.handleCompleteRequest(connection, data: buffer)
                return
            }

            if isComplete || error != nil || data == nil {
                connection.cancel()
                return
            }

            self.read(connection, soFar: buffer)
        }
    }

    private func handleCompleteRequest(_ connection: NWConnection, data: Data) {
        guard let request = String(data: data, encoding: .utf8) else {
            CallbackHTTPParser.respond(connection, message: "<h1>Could not parse the request</h1>", statusCode: 400)
            return
        }
        switch CallbackHTTPParser.parse(request, expectedPath: expectedPath, expectedState: expectedState) {
        case .skip(let message, let statusCode):
            CallbackHTTPParser.respond(connection, message: message, statusCode: statusCode)
        case .finalize(let result, let message):
            CallbackHTTPParser.respond(connection, message: message, statusCode: 200)
            finish(result)
        }
    }

    private func finish(_ result: Result<String, Error>) {
        switch state {
        case .idle:
            state = .resultReady(result)
        case .awaitingWaiter(let continuation):
            state = .finished
            continuation.resume(with: result)
        case .resultReady, .finished:
            break
        }
    }
}
