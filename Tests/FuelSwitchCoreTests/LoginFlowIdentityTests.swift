import Testing
import Foundation
@testable import FuelSwitchCore

@Suite struct LoginFlowIdentityTests {
    private func makeJWT(payload: [String: Any]) -> String {
        let header = Data(#"{"alg":"none"}"#.utf8).base64EncodedString()
        let data = try! JSONSerialization.data(withJSONObject: payload)
        let body = data.base64EncodedString()
        return "\(header).\(body).sig"
    }

    private func makeFlow() -> LoginFlow {
        LoginFlow(store: AccountStore(directory: URL(fileURLWithPath: "/tmp")), openURL: { _ in })
    }

    @Test func geminiIdentityFromIDToken() async throws {
        let flow = makeFlow()
        let jwt = makeJWT(payload: ["email": "gemini.user@example.com"])
        let tokens = Tokens(accessToken: "access", refreshToken: "refresh", expiresAt: Date().addingTimeInterval(3600), idToken: jwt)

        let identity = try await flow.accountIdentity(provider: .gemini, tokens: tokens) { _ in
            throw OAuthError.responseWithoutToken
        }

        #expect(identity.email == "gemini.user@example.com")
        #expect(identity.plan == "Gemini CLI")
        #expect(identity.organizationName == "Google")
    }

    @Test func openAIIdentityFromClaims() async throws {
        let flow = makeFlow()
        let jwt = makeJWT(payload: [
            "email": "codex@example.com",
            "https://api.openai.com/auth": [
                "chatgpt_account_id": "acc-12345",
                "chatgpt_plan_type": "plus"
            ]
        ])
        let tokens = Tokens(accessToken: "access", refreshToken: "refresh", expiresAt: Date().addingTimeInterval(3600), idToken: jwt)

        let identity = try await flow.accountIdentity(provider: .openai, tokens: tokens) { _ in
            throw OAuthError.responseWithoutToken
        }

        #expect(identity.email == "codex@example.com")
        #expect(identity.accountId == "acc-12345")
        #expect(identity.plan == "plus")
    }

    @Test func openAIIncompleteIdentityThrows() async {
        let flow = makeFlow()
        let jwt = makeJWT(payload: ["email": "codex@example.com"]) // missing auth dictionary
        let tokens = Tokens(accessToken: "access", refreshToken: "refresh", expiresAt: Date().addingTimeInterval(3600), idToken: jwt)

        await #expect(throws: OAuthError.incompleteCodexIdentity) {
            _ = try await flow.accountIdentity(provider: .openai, tokens: tokens) { _ in
                throw OAuthError.responseWithoutToken
            }
        }
    }

    @Test func anthropicIdentityUsesProfileFactory() async throws {
        let flow = makeFlow()
        let tokens = Tokens(accessToken: "anthropic-token", refreshToken: "r", expiresAt: Date().addingTimeInterval(3600))

        let profile = AnthropicProfile(email: "claudette@example.com", plan: "max", organizationName: "Anthropic HQ", hasSubscription: true)
        let identity = try await flow.accountIdentity(provider: .anthropic, tokens: tokens) { token in
            #expect(token == "anthropic-token")
            return profile
        }

        #expect(identity.email == "claudette@example.com")
        #expect(identity.plan == "max")
        #expect(identity.organizationName == "Anthropic HQ")
        #expect(identity.hasSubscription == true)
    }

    @Test func geminiWithoutIdentityThrowsWhenNoActiveCLI() async {
        let flow = makeFlow()
        let tokens = Tokens(accessToken: "invalid", refreshToken: "r", expiresAt: Date().addingTimeInterval(3600), idToken: nil)

        // Invalid token with no email claim
        do {
            _ = try await flow.accountIdentity(provider: .gemini, tokens: tokens) { _ in
                throw OAuthError.responseWithoutToken
            }
        } catch {
            #expect(error is OAuthError)
        }
    }
}
