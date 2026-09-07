import Foundation
import Network

/// A small handle for carrying the result of starting `NWListener` from the
/// `stateUpdateHandler` callback (which runs on `queue`) back to the thread
/// that called `start(expectedState:)`, without capturing a mutable local in a
/// closure that outlives it on a Network.framework thread.
private final class StartHandle: @unchecked Sendable {
    let semaphore = DispatchSemaphore(value: 0)
    var error: Error?
}

/// An HTTP server that serves exactly one redirect from the browser. Codex
/// requires the fixed port 1455; Anthropic accepts any.
///
/// The redirect's result is buffered: if the HTTP request arrives before anyone
/// calls `waitForCode()`, the result waits to be collected; if `waitForCode()`
/// is called first, its continuation is stored and resumed when the request
/// arrives. All of that state is read and changed exclusively on `queue` (a
/// serial queue), so there is no window between checking "is anyone waiting"
/// and storing the result.
///
/// Because the port is sometimes fixed (Codex: 1455) and may be reused by a
/// later sign-in attempt, the listener ignores every request that does not hit
/// the expected redirect path (probes, `favicon.ico`, a late redirect from an
/// abandoned earlier attempt) — such a request gets a 404 and does NOT finalise
/// the state, so the listener stays armed for the real redirect.
public final class CallbackListener: @unchecked Sendable {
    /// The state of waiting for a redirect result — exactly one instance of
    /// this machine per listener lifetime (per sign-in).
    private enum State {
        /// Nothing has happened yet.
        case idle
        /// Someone is inside `waitForCode()`, waiting for a result.
        case awaitingWaiter(CheckedContinuation<String, Error>)
        /// The redirect result arrived before anyone started waiting.
        case resultReady(Result<String, Error>)
        /// The result has been delivered (from the buffer or straight to a
        /// waiter), or the listener was stopped. Further redirects and further
        /// `waitForCode()` calls are ignored or rejected — a continuation is
        /// resumed at most once.
        case finished
    }

    /// The outcome of parsing one complete HTTP request.
    private enum ParseOutcome {
        /// The request does not hit the expected path (or is malformed) — we
        /// answer it and leave the state untouched.
        case skip(message: String, statusCode: Int)
        /// The request hits the expected path — finalise the state with this
        /// result.
        case finalize(Result<String, Error>, message: String)
    }

    /// Upper bound on the HTTP header bytes accumulated before a request is
    /// rejected — guards against unbounded buffer growth for a broken or
    /// malicious client.
    private static let maximumRequestSize = 16 * 1024

    private let requestedPort: UInt16
    private var listener: NWListener?
    private var expectedState = ""
    private var expectedPath = "/callback"
    private var state: State = .idle
    private let queue = DispatchQueue(label: "ai.fuelswitch.callback")

    public init(port: UInt16) {
        self.requestedPort = port
    }

    /// Starts listening and returns the port actually in use (useful when 0 —
    /// any free port — was passed to `init`). `expectedState` has to be known
    /// before any connection is accepted, so that an incoming `state` is never
    /// compared against an empty string. `expectedPath` is the given provider's
    /// redirect path — Anthropic uses `/callback`, Codex `/auth/callback`.
    /// Deliberately without a default value: omitting this argument for Codex
    /// would have to end in `waitForCode()` hanging silently (a request to
    /// `/auth/callback` would fall into the mismatch branch and receive a 404
    /// without finalising the state) rather than in a compile error.
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

    /// Waits for the authorisation code from the one expected redirect. If the
    /// result has already arrived and is sitting in the buffer, it is returned
    /// straight away.
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
                    // Unsupported use (a second concurrent or repeated call to
                    // `waitForCode()`) — we do not leave the caller suspended.
                    continuation.resume(throwing: OAuthError.responseWithoutToken)
                }
            }
        }
    }

    /// Stops listening. If someone is suspended in `waitForCode()` right now,
    /// their continuation is resumed with `.cancelled` — otherwise
    /// `withCheckedThrowingContinuation` knows nothing about task cancellation
    /// and the caller would hang forever. The resume happens synchronously on
    /// `queue`, so it definitely precedes cancelling the listener itself below.
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
            // Both statements below have to sit inside the SAME `queue.sync` as
            // the state transition above — since F4, `stop()` is sometimes
            // called concurrently from two threads (once from `onCancel` in
            // `LoginFlow`, once from the `defer` after the same `await`
            // unblocks). Were these two statements outside the `sync`, two
            // parallel non-atomic writes of `nil` to a strong `var` could
            // double-release the `NWListener`. `queue.sync` is safe here
            // because `stop()` is never called from a Network.framework
            // callback running on `queue` — see the comment in
            // `LoginFlow.awaitCodeWithTimeout`.
            listener?.cancel()
            listener = nil
        }
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        read(connection, soFar: Data())
    }

    /// Accumulates bytes from successive `receive` calls until the HTTP header
    /// terminator (`\r\n\r\n`) appears, or the connection ends, breaks or
    /// exceeds the limit — the single `receive` of the first version lost
    /// requests that were split across several TCP packets.
    private func read(_ connection: NWConnection, soFar: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            var buffer = soFar
            if let data { buffer.append(data) }

            if buffer.count > Self.maximumRequestSize {
                self.respondAndSkip(connection, message: "<h1>Request too large</h1>", statusCode: 413)
                return
            }

            if buffer.range(of: Data("\r\n\r\n".utf8)) != nil {
                self.handleCompleteRequest(connection, data: buffer)
                return
            }

            if isComplete || error != nil || data == nil {
                // The connection broke or ended before the full headers
                // arrived — nothing sensible to parse, so the state is not
                // finalised.
                connection.cancel()
                return
            }

            self.read(connection, soFar: buffer)
        }
    }

    private func handleCompleteRequest(_ connection: NWConnection, data: Data) {
        guard let request = String(data: data, encoding: .utf8) else {
            respondAndSkip(connection, message: "<h1>Could not parse the request</h1>", statusCode: 400)
            return
        }
        switch parse(request) {
        case .skip(let message, let statusCode):
            respondAndSkip(connection, message: message, statusCode: statusCode)
        case .finalize(let result, let message):
            respond(connection, message: message, statusCode: 200)
            finish(result)
        }
    }

    /// Parses the raw HTTP request. The message returned to the browser NEVER
    /// contains the authorisation code or any other secret. The state is
    /// finalised only for requests that hit `expectedPath` — everything else
    /// (probes, favicons, a late redirect from a previous attempt) is skipped.
    private func parse(_ request: String) -> ParseOutcome {
        guard let line = request.split(separator: "\r\n").first,
              let pathWithQuery = line.split(separator: " ").dropFirst().first,
              let components = URLComponents(string: "http://localhost\(pathWithQuery)")
        else {
            return .skip(message: "<h1>Could not parse the request</h1>", statusCode: 400)
        }
        guard components.path == expectedPath else {
            return .skip(message: "<h1>Not found</h1>", statusCode: 404)
        }
        let items = components.queryItems ?? []
        let state = items.first { $0.name == "state" }?.value
        guard state == expectedState else {
            return .finalize(.failure(OAuthError.stateMismatch), message: "<h1>The state parameter does not match</h1>")
        }
        guard let code = items.first(where: { $0.name == "code" })?.value else {
            return .finalize(.failure(OAuthError.responseWithoutToken), message: "<h1>No authorisation code</h1>")
        }
        return .finalize(.success(code), message: "<h1>Signed in. You can close this tab.</h1>")
    }

    private func respond(_ connection: NWConnection, message: String, statusCode: Int) {
        let statusLine: String
        switch statusCode {
        case 200: statusLine = "200 OK"
        case 400: statusLine = "400 Bad Request"
        case 404: statusLine = "404 Not Found"
        case 413: statusLine = "413 Payload Too Large"
        default: statusLine = "\(statusCode)"
        }
        let response = """
        HTTP/1.1 \(statusLine)\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(message.utf8.count)\r
        Connection: close\r
        \r
        \(message)
        """
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    /// Answers a request that does NOT hit the expected path (or is malformed
    /// or too large) and deliberately leaves `state` alone — the listener stays
    /// armed for the real redirect.
    private func respondAndSkip(_ connection: NWConnection, message: String, statusCode: Int) {
        respond(connection, message: message, statusCode: statusCode)
    }

    /// Delivers the result to a waiter, if one is already waiting, or buffers
    /// it for later. Called only from the `receive` callback which — thanks to
    /// `connection.start(queue: queue)` — runs on the same serial queue as
    /// `waitForCode()`, so no further synchronisation is needed here.
    private func finish(_ result: Result<String, Error>) {
        switch state {
        case .idle:
            state = .resultReady(result)
        case .awaitingWaiter(let continuation):
            state = .finished
            continuation.resume(with: result)
        case .resultReady, .finished:
            // A further redirect after the result was already delivered or
            // buffered — ignored, so no continuation is ever resumed twice.
            break
        }
    }
}
