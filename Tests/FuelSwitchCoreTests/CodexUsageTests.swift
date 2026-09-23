import Testing
import Foundation
@testable import FuelSwitchCore

private final class CodexRequestCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var value: URLRequest?

    func store(_ request: URLRequest) {
        lock.lock()
        value = request
        lock.unlock()
    }

    func load() -> URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

private final class CodexURLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responseHandler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let responseHandler = Self.responseHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }
        let (response, data) = responseHandler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func codexTestAccount() -> Account {
    Account(
        provider: .openai,
        email: "codex@example.com",
        accessToken: "access-token",
        refreshToken: "refresh-token",
        expiresAt: .distantFuture,
        accountId: "workspace-id"
    )
}

private func codexStubSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [CodexURLProtocolStub.self]
    return URLSession(configuration: configuration)
}

private func requestBody(_ request: URLRequest) throws -> Data {
    if let body = request.httpBody { return body }
    let stream = try #require(request.httpBodyStream)
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1024)
    while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count <= 0 { break }
        data.append(buffer, count: count)
    }
    return data
}

private func codexFixture() throws -> Data {
    let url = Bundle.module.url(forResource: "Fixtures/codex_usage", withExtension: "json")
    return try Data(contentsOf: #require(url))
}

@Test func parsesBothCodexWindows() throws {
    let result = try CodexUsage.parse(codexFixture(), fetchedAt: Date())
    #expect(result.usage.session.percent == 100)
    #expect(result.usage.weekly.percent == 16)
    #expect(result.usage.scoped.isEmpty)
}

@Test func convertsTheEpochToADate() throws {
    let result = try CodexUsage.parse(codexFixture(), fetchedAt: Date())
    #expect(result.usage.session.resetsAt == Date(timeIntervalSince1970: 1_788_548_409))
}

@Test func extractsTheEmailAndPlan() throws {
    let result = try CodexUsage.parse(codexFixture(), fetchedAt: Date())
    #expect(result.email == "account@example.com")
    #expect(result.plan == "team")
}

@Test func aMissingRateLimitSectionGivesEmptyWindows() throws {
    let result = try CodexUsage.parse(Data(#"{"email":"a@b.pl"}"#.utf8), fetchedAt: Date())
    #expect(result.usage.session.percent == 0)
    #expect(result.usage.weekly.resetsAt == nil)
}

@Suite(.serialized)
struct CodexResetTests {
@Test
func consumeResetCreditPostsTheCreditAndRequestId() async throws {
    let capture = CodexRequestCapture()
    CodexURLProtocolStub.responseHandler = { request in
        capture.store(request)
        return (
            HTTPURLResponse(
                url: request.url!,
                statusCode: 204,
                httpVersion: nil,
                headerFields: nil
            )!,
            Data()
        )
    }
    defer { CodexURLProtocolStub.responseHandler = nil }

    try await CodexUsageClient(session: codexStubSession()).consumeResetCredit(
        account: codexTestAccount(),
        creditId: "credit-123"
    )

    let request = try #require(capture.load())
    #expect(request.httpMethod == "POST")
    #expect(request.url == FuelSwitchConstants.codexResetConsumeURL)
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access-token")
    #expect(request.value(forHTTPHeaderField: "ChatGPT-Account-Id") == "workspace-id")
    let body = try requestBody(request)
    let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: String])
    #expect(json["credit_id"] == "credit-123")
    #expect(UUID(uuidString: try #require(json["redeem_request_id"])) != nil)
}

@Test
func resetCreditsDoNotInventAnAvailableCredit() async throws {
    CodexURLProtocolStub.responseHandler = { request in
        let data = Data(#"{"available_count":0,"credits":[]}"#.utf8)
        return (
            HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!,
            data
        )
    }
    defer { CodexURLProtocolStub.responseHandler = nil }

    let result = await CodexUsageClient(session: codexStubSession()).fetchResetCredits(account: codexTestAccount())
    #expect(result.availableCount == 0)
    #expect(result.firstCreditId == nil)
}
}
