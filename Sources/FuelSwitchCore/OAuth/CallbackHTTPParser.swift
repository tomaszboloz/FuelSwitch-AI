import Foundation
import Network

/// The outcome of parsing one complete HTTP request.
enum ParseOutcome {
    /// The request does not hit expected path — answered with statusCode without finalizing state.
    case skip(message: String, statusCode: Int)
    /// The request hits expected path — finalize state with result.
    case finalize(Result<String, Error>, message: String)
}

enum CallbackHTTPParser {
    /// Upper bound on the HTTP header bytes accumulated before a request is rejected.
    static let maximumRequestSize = 16 * 1024

    /// Parses raw HTTP request string.
    static func parse(_ request: String, expectedPath: String, expectedState: String) -> ParseOutcome {
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

    /// Sends an HTTP response on connection and closes it.
    static func respond(_ connection: NWConnection, message: String, statusCode: Int) {
        let statusLine = statusLine(for: statusCode)
        let icon = Bundle.main.url(forResource: "favicon", withExtension: "png")
            .flatMap { try? Data(contentsOf: $0) }
        let iconLink = icon.map { "<link rel=\"icon\" type=\"image/png\" href=\"data:image/png;base64,\($0.base64EncodedString())\">" } ?? ""
        let body = "<!doctype html><html><head><meta charset=\"utf-8\"><title>FuelSwitch AI</title>\(iconLink)</head><body>\(message)</body></html>"
        let response = """
        HTTP/1.1 \(statusLine)\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private static func statusLine(for code: Int) -> String {
        switch code {
        case 200: "200 OK"
        case 400: "400 Bad Request"
        case 404: "404 Not Found"
        case 413: "413 Payload Too Large"
        default: "\(code)"
        }
    }
}
