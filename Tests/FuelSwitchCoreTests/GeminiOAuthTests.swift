import Testing
import Foundation
@testable import FuelSwitchCore

extension NetworkTests {
    @Suite struct GeminiOAuthTests {
        private func mockSession() -> URLSession {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [MockProtocol.self]
            return URLSession(configuration: configuration)
        }

        @Test func authorizationURLHasRequiredGoogleParams() {
            let oauth = GeminiOAuth(session: mockSession())
            #expect(oauth.requiredPort == 0)

            let pkce = PKCE(verifier: "test-verifier", state: "test-state")
            let url = oauth.authorizationURL(pkce: pkce, redirectURI: "http://localhost:8080/callback")

            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            #expect(components?.scheme == "https")
            #expect(components?.host == "accounts.google.com")
            #expect(components?.path == "/o/oauth2/v2/auth")

            let items = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            #expect(items["response_type"] == "code")
            #expect(items["redirect_uri"] == "http://localhost:8080/callback")
            #expect(items["state"] == "test-state")
            #expect(items["code_challenge"] == pkce.challenge)
            #expect(items["code_challenge_method"] == "S256")
            #expect(items["access_type"] == "offline")
            #expect(items["prompt"] == "select_account consent")
        }

        @Test func exchangeReturnsTokensOnSuccess() async throws {
            MockProtocol.response = (200, Data("""
            {
                "access_token": "g_access_123",
                "refresh_token": "g_refresh_456",
                "expires_in": 3600,
                "id_token": "header.payload.signature"
            }
            """.utf8))

            let oauth = GeminiOAuth(session: mockSession())
            let pkce = PKCE(verifier: "test-verifier", state: "test-state")
            let tokens = try await oauth.exchange(code: "g_code_789", pkce: pkce, redirectURI: "http://localhost:8080/callback")

            #expect(tokens.accessToken == "g_access_123")
            #expect(tokens.refreshToken == "g_refresh_456")
            #expect(tokens.idToken == "header.payload.signature")
            #expect(tokens.expiresAt.timeIntervalSinceNow > 3500)
        }

        @Test func exchangeThrowsOnHTTPError() async {
            MockProtocol.response = (401, Data("Unauthorized".utf8))
            let oauth = GeminiOAuth(session: mockSession())
            let pkce = PKCE(verifier: "test-verifier", state: "test-state")

            await #expect(throws: UsageError.unauthorized) {
                _ = try await oauth.exchange(code: "bad_code", pkce: pkce, redirectURI: "http://localhost:8080/callback")
            }
        }

        @Test func refreshReturnsRefreshedTokens() async throws {
            MockProtocol.response = (200, Data("""
            {
                "access_token": "new_access_token",
                "expires_in": 3600,
                "id_token": "new.id.token"
            }
            """.utf8))

            let oauth = GeminiOAuth(session: mockSession())
            let tokens = try await oauth.refresh(refreshToken: "existing_refresh_token")

            #expect(tokens.accessToken == "new_access_token")
            #expect(tokens.refreshToken == "existing_refresh_token")
            #expect(tokens.idToken == "new.id.token")
        }

        @Test func refreshThrowsOnHTTPError() async {
            MockProtocol.response = (400, Data("Bad Request".utf8))
            let oauth = GeminiOAuth(session: mockSession())

            await #expect(throws: UsageError.unauthorized) {
                _ = try await oauth.refresh(refreshToken: "invalid_refresh_token")
            }
        }
    }
}
