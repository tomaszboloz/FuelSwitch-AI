import Testing
import Foundation
@testable import FuelSwitchCore

private func mockProfileSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockProtocol.self]
    return URLSession(configuration: configuration)
}

/// The response shape verified live against a real account on 2026-09-04 — see
/// the controller's note on task 12.
private let sampleResponse = Data(#"""
{"account": {"uuid": "u-1", "email": "someone@example.com", "full_name": "Someone", "has_claude_max": true},
 "organization": {"uuid": "o-1", "name": "Org", "organization_type": "claude_max",
                  "rate_limit_tier": "default_claude_max_20x"},
 "application": {"uuid": "a-1", "name": "Claude Code"}}
"""#.utf8)

extension NetworkTests {
    @Suite struct AnthropicProfileTests {
        @Test func parsesTheEmailAndPlanFromTheResponse() async throws {
            MockProtocol.response = (200, sampleResponse)
            let profile = try await AnthropicProfileClient(session: mockProfileSession())
                .fetch(accessToken: "tok")
            #expect(profile.email == "someone@example.com")
            #expect(profile.plan == "default_claude_max_20x")
            #expect(profile.organizationName == "Org")
        }

        @Test func sendsTheRequiredHeaders() async throws {
            MockProtocol.response = (200, sampleResponse)
            _ = try await AnthropicProfileClient(session: mockProfileSession()).fetch(accessToken: "secret-tok")
            #expect(MockProtocol.lastHeaders["Authorization"] == "Bearer secret-tok")
            #expect(MockProtocol.lastHeaders["User-Agent"] == FuelSwitchConstants.anthropicUserAgent)
            #expect(MockProtocol.lastHeaders["Content-Type"] == "application/json")
        }

        @Test func anHttpErrorIsRecognised() async {
            MockProtocol.response = (401, Data())
            await #expect(throws: AnthropicProfileError.http(401)) {
                _ = try await AnthropicProfileClient(session: mockProfileSession()).fetch(accessToken: "tok")
            }
        }

        @Test func aMissingEmailThrowsRatherThanInventingAnIdentity() async {
            MockProtocol.response = (200, Data(#"{"account": {"uuid": "u-1"}}"#.utf8))
            await #expect(throws: AnthropicProfileError.responseWithoutEmail) {
                _ = try await AnthropicProfileClient(session: mockProfileSession()).fetch(accessToken: "tok")
            }
        }

        @Test func aMissingOrganizationGivesANilPlan() async throws {
            MockProtocol.response = (200, Data(#"{"account": {"email": "x@y.pl"}}"#.utf8))
            let profile = try await AnthropicProfileClient(session: mockProfileSession()).fetch(accessToken: "tok")
            #expect(profile.email == "x@y.pl")
            #expect(profile.plan == nil)
        }
    }
}
