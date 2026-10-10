import Testing
import Foundation
@testable import FuelSwitchCore

@Suite struct CallbackHTTPParserTests {
    private let path = "/oauth/callback"
    private let state = "secure-random-state-123"

    @Test func parsesValidRequestSuccessfully() {
        let raw = "GET /oauth/callback?code=auth_code_xyz&state=secure-random-state-123 HTTP/1.1\r\nHost: localhost\r\n\r\n"
        let outcome = CallbackHTTPParser.parse(raw, expectedPath: path, expectedState: state)

        switch outcome {
        case .finalize(let result, let message):
            switch result {
            case .success(let code):
                #expect(code == "auth_code_xyz")
                #expect(message.contains("Signed in"))
            case .failure:
                Issue.record("Expected successful code extraction")
            }
        case .skip:
            Issue.record("Expected finalize outcome")
        }
    }

    @Test func skipsRequestWithWrongPath() {
        let raw = "GET /favicon.ico HTTP/1.1\r\nHost: localhost\r\n\r\n"
        let outcome = CallbackHTTPParser.parse(raw, expectedPath: path, expectedState: state)

        switch outcome {
        case .skip(let message, let statusCode):
            #expect(statusCode == 404)
            #expect(message.contains("Not found"))
        case .finalize:
            Issue.record("Expected skip outcome for wrong path")
        }
    }

    @Test func handlesMalformedRequests() {
        let badRequests = [
            "",
            "INVALID",
            "GET",
            "\r\n\r\n",
            "POST",
        ]
        for raw in badRequests {
            let outcome = CallbackHTTPParser.parse(raw, expectedPath: path, expectedState: state)
            switch outcome {
            case .skip(_, let code):
                #expect(code == 400)
            case .finalize:
                Issue.record("Expected skip 400 for malformed input '\(raw)'")
            }
        }
    }

    @Test func detectsStateMismatch() {
        let raw = "GET /oauth/callback?code=xyz&state=wrong-state HTTP/1.1\r\nHost: localhost\r\n\r\n"
        let outcome = CallbackHTTPParser.parse(raw, expectedPath: path, expectedState: state)

        switch outcome {
        case .finalize(let result, let message):
            switch result {
            case .success:
                Issue.record("Expected state mismatch error")
            case .failure(let error):
                #expect(error as? OAuthError == .stateMismatch)
                #expect(message.contains("state parameter does not match"))
            }
        case .skip:
            Issue.record("Expected finalize outcome")
        }
    }

    @Test func detectsMissingCode() {
        let raw = "GET /oauth/callback?state=secure-random-state-123 HTTP/1.1\r\nHost: localhost\r\n\r\n"
        let outcome = CallbackHTTPParser.parse(raw, expectedPath: path, expectedState: state)

        switch outcome {
        case .finalize(let result, let message):
            switch result {
            case .success:
                Issue.record("Expected missing token error")
            case .failure(let error):
                #expect(error as? OAuthError == .responseWithoutToken)
                #expect(message.contains("No authorisation code"))
            }
        case .skip:
            Issue.record("Expected finalize outcome")
        }
    }
}
