import Testing
import Foundation
@testable import FuelSwitchCore

/// The state (`response`, `lastHeaders`) is static and shared by the WHOLE test
/// target, not just this file — every `@Suite` that drives this mock (here and
/// in other files, such as the OAuth exchange tests) MUST be nested under
/// `NetworkTests` to inherit its `.serialized`. Without that, two tests from
/// different files can overwrite each other's expected response and last
/// headers in parallel — a race, not merely a memory hazard, so a lock would
/// not fix it.
final class MockProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var response: (Int, Data) = (200, Data())
    nonisolated(unsafe) static var lastHeaders: [String: String] = [:]
    /// The body of the last request. Foundation routinely moves `httpBody` into
    /// `httpBodyStream` before a request reaches `URLProtocol`, so reading
    /// `request.httpBody` alone is sometimes `nil` despite a body really having
    /// been sent — hence draining the stream by hand as a second source.
    nonisolated(unsafe) static var lastBody: Data? = nil

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lastHeaders = request.allHTTPHeaderFields ?? [:]
        Self.lastBody = Self.extractBody(request)
        let (statusCode, data) = Self.response
        let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}

    private static func extractBody(_ request: URLRequest) -> Data? {
        if let data = request.httpBody { return data }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var result = Data()
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            guard read > 0 else { break }
            result.append(buffer, count: read)
        }
        return result
    }
}

private func mockSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockProtocol.self]
    return URLSession(configuration: configuration)
}

private let account = Account(
    provider: .anthropic, email: "a@b.pl",
    accessToken: "tok", refreshToken: "r", expiresAt: .distantFuture
)

/// The shared parent of every suite that drives `MockProtocol`. Its
/// `.serialized` applies recursively to all nested suites — so each further
/// test file that swaps the network layer through this same mock (the OAuth
/// exchange tests, for instance) adds its suite as
/// `extension NetworkTests { @Suite struct ... { ... } }` and gets
/// serialisation automatically, rather than relying on someone remembering it.
@Suite(.serialized) struct NetworkTests {}

extension NetworkTests {
    @Suite struct UsageClientTests {
        @Test func anthropicSendsTheRequiredHeaders() async throws {
            MockProtocol.response = (200, Data(#"{"five_hour":{"utilization":7}}"#.utf8))
            _ = try await AnthropicUsageClient(session: mockSession()).fetch(account: account)
            #expect(MockProtocol.lastHeaders["anthropic-beta"] == "oauth-2025-04-20")
            #expect(MockProtocol.lastHeaders["User-Agent"] == FuelSwitchConstants.anthropicUserAgent)
            #expect(MockProtocol.lastHeaders["Authorization"] == "Bearer tok")
        }

        @Test func a429GivesARateLimitedError() async {
            MockProtocol.response = (429, Data(#"{"error":{"type":"rate_limit_error"}}"#.utf8))
            await #expect(throws: UsageError.rateLimited) {
                _ = try await AnthropicUsageClient(session: mockSession()).fetch(account: account)
            }
        }

        @Test func a401GivesAnUnauthorizedError() async {
            MockProtocol.response = (401, Data())
            await #expect(throws: UsageError.unauthorized) {
                _ = try await AnthropicUsageClient(session: mockSession()).fetch(account: account)
            }
        }

        /// The response observed live on 2026-09-05: an account holding a Max
        /// subscription whose OAuth token bound to the API Console
        /// organisation. Adding the account again changes nothing here, so this
        /// case has to be distinguishable from an ordinary token rejection.
        @Test func a403OrganizationRefusalIsDistinguished() async {
            MockProtocol.response = (403, Data(#"""
            {"type":"error","error":{"type":"permission_error","message":"OAuth authentication is currently not allowed for this organization.","details":{"error_code":"oauth_not_allowed_for_organization"}}}
            """#.utf8))
            await #expect(throws: UsageError.organizationNotAllowed) {
                _ = try await AnthropicUsageClient(session: mockSession()).fetch(account: account)
            }
        }

        @Test func anOrdinary403StillMeansUnauthorized() async {
            MockProtocol.response = (403, Data(#"{"error":{"type":"permission_error"}}"#.utf8))
            await #expect(throws: UsageError.unauthorized) {
                _ = try await AnthropicUsageClient(session: mockSession()).fetch(account: account)
            }
        }

        @Test func codexSendsTheAccountIdentifierHeader() async throws {
            MockProtocol.response = (200, Data(#"{"email":"a@b.pl"}"#.utf8))
            let codexAccount = Account(
                provider: .openai, email: "a@b.pl",
                accessToken: "tok2", refreshToken: "r", expiresAt: .distantFuture, accountId: "acc-1"
            )
            _ = try await CodexUsageClient(session: mockSession()).fetch(account: codexAccount)
            #expect(MockProtocol.lastHeaders["ChatGPT-Account-Id"] == "acc-1")
        }
    }
}
