import Testing
import Foundation
@testable import FuelSwitchCore

private struct DummyProvider: UsageProvider {
    func fetch(account: Account) async throws -> AccountUsage {
        throw UsageError.unavailableQuota
    }
}

@Suite struct UsageProviderTests {
    private let dummy = DummyProvider()
    private let url = URL(string: "https://api.example.com")!

    @Test func checkStatusAccepts200Range() throws {
        for code in [200, 201, 204] {
            let response = HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil)!
            try dummy.checkStatus(response)
        }
    }

    @Test func checkStatusThrowsRateLimitedOn429() {
        let response = HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: nil)!
        #expect(throws: UsageError.rateLimited) {
            try dummy.checkStatus(response)
        }
    }

    @Test func checkStatusThrowsUnauthorizedOn401And403() {
        for code in [401, 403] {
            let response = HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil)!
            #expect(throws: UsageError.unauthorized) {
                try dummy.checkStatus(response)
            }
        }
    }

    @Test func checkStatusThrowsHttpErrorOn500Range() {
        for code in [500, 502, 503] {
            let response = HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil)!
            #expect(throws: UsageError.http(code)) {
                try dummy.checkStatus(response)
            }
        }
    }

    @Test func checkStatusHandlesNonHTTPResponse() throws {
        let response = URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        try dummy.checkStatus(response)
    }

    @Test func checkStatusRecognisesOrganizationRefusal() {
        let response = HTTPURLResponse(url: url, statusCode: 403, httpVersion: nil, headerFields: nil)!
        let body = Data("""
        {
            "type": "error",
            "error": {
                "details": {
                    "error_code": "oauth_not_allowed_for_organization"
                }
            }
        }
        """.utf8)

        #expect(throws: UsageError.organizationNotAllowed) {
            try dummy.checkStatus(response, body: body)
        }
    }
}
