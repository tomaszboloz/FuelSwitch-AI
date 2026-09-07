import Testing
import Foundation
@testable import FuelSwitchCore

private func mockOAuthSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockProtocol.self]
    return URLSession(configuration: configuration)
}

/// Decodes the last request body captured by `MockProtocol` as a
/// string-to-string dictionary — both providers send text fields only.
private func sentBody() throws -> [String: String] {
    let data = try #require(MockProtocol.lastBody)
    return try #require(try JSONSerialization.jsonObject(with: data) as? [String: String])
}

extension NetworkTests {
    @Suite struct OAuthExchangeTests {
        @Test func aCodeExchangeReturnsTokensAndComputesTheExpiry() async throws {
            MockProtocol.response = (200, Data(#"""
            {"access_token":"a1","refresh_token":"r1","expires_in":28800}
            """#.utf8))
            let tokens = try await AnthropicOAuth(session: mockOAuthSession())
                .exchange(code: "code", pkce: PKCE(verifier: "v", state: "s"), redirectURI: "http://localhost:1/callback")
            #expect(tokens.accessToken == "a1")
            #expect(tokens.refreshToken == "r1")
            #expect(tokens.expiresAt.timeIntervalSinceNow > 28_000)
        }

        @Test func aRefreshReturnsTheRotatedRefreshToken() async throws {
            MockProtocol.response = (200, Data(#"""
            {"access_token":"a2","refresh_token":"NEW","expires_in":3600}
            """#.utf8))
            let tokens = try await AnthropicOAuth(session: mockOAuthSession()).refresh(refreshToken: "OLD")
            #expect(tokens.refreshToken == "NEW")
        }

        @Test func aMissingRefreshTokenInTheResponseKeepsTheOldOne() async throws {
            MockProtocol.response = (200, Data(#"{"access_token":"a3","expires_in":3600}"#.utf8))
            let tokens = try await AnthropicOAuth(session: mockOAuthSession()).refresh(refreshToken: "OLD")
            #expect(tokens.refreshToken == "OLD")
        }

        @Test func aMissingRefreshTokenOnCodeExchangeThrows() async {
            // On the code exchange path there is no earlier refresh token to
            // keep — its absence from the response is a broken server reply,
            // not a cue to "leave things as they were".
            MockProtocol.response = (200, Data(#"{"access_token":"a3b","expires_in":3600}"#.utf8))
            await #expect(throws: OAuthError.responseWithoutToken) {
                _ = try await AnthropicOAuth(session: mockOAuthSession())
                    .exchange(code: "code", pkce: PKCE(verifier: "v", state: "s"), redirectURI: "http://localhost:1/callback")
            }
        }

        @Test func anInvalidGrantErrorIsRecognised() async {
            MockProtocol.response = (400, Data(#"{"error":"invalid_grant"}"#.utf8))
            await #expect(throws: OAuthError.invalidGrant) {
                _ = try await AnthropicOAuth(session: mockOAuthSession()).refresh(refreshToken: "X")
            }
        }

        // F10: only a body of "error":"invalid_grant" means an invalid grant —
        // a bare 400/401 without that field has to take the `.http(code)` path
        // (backoff) rather than a permanent `needsReauth`. Previously EVERY
        // 400/401 (`invalid_scope`, `invalid_client` and so on) was mistakenly
        // mapped to `.invalidGrant`, which across eleven Codex accounts would
        // mean eleven pointless browser sign-ins.
        @Test func a400WithoutInvalidGrantInTheBodyGivesAnHttpError() async {
            MockProtocol.response = (400, Data(#"{"error":"invalid_scope"}"#.utf8))
            await #expect(throws: OAuthError.http(400)) {
                _ = try await AnthropicOAuth(session: mockOAuthSession()).refresh(refreshToken: "X")
            }
        }

        @Test func a401WithNoErrorBodyGivesAnHttpError() async {
            MockProtocol.response = (401, Data())
            await #expect(throws: OAuthError.http(401)) {
                _ = try await AnthropicOAuth(session: mockOAuthSession()).refresh(refreshToken: "X")
            }
        }

        @Test func readsTheEmailAndAccountFromTheIdToken() {
            let payload = Data(#"""
            {"email":"x@y.pl","https://api.openai.com/auth":{"chatgpt_account_id":"acc-9","chatgpt_plan_type":"pro"}}
            """#.utf8).base64URLEncoded
            let jwt = "header.\(payload).signature"
            let claims = JWT.claims(jwt)
            #expect(claims["email"] as? String == "x@y.pl")
            let auth = claims["https://api.openai.com/auth"] as? [String: Any]
            #expect(auth?["chatgpt_account_id"] as? String == "acc-9")
        }

        @Test func theOpenAIRefreshWorksWithTheNarrowedScope() async throws {
            // codex-check sends "openid profile email" when refreshing — a
            // narrower scope than at authorisation, because a refresh_token
            // requires a subset of the originally granted permissions.
            MockProtocol.response = (200, Data(#"{"access_token":"a4","refresh_token":"r4","expires_in":3600}"#.utf8))
            let tokens = try await OpenAIOAuth(session: mockOAuthSession()).refresh(refreshToken: "OLD")
            #expect(tokens.accessToken == "a4")
            #expect(FuelSwitchConstants.openAIRefreshScope == "openid profile email")
        }

        @Test func theAnthropicRefreshSendsExactlyTheExpectedBody() async throws {
            MockProtocol.response = (200, Data(#"{"access_token":"a5","refresh_token":"r5","expires_in":3600}"#.utf8))
            _ = try await AnthropicOAuth(session: mockOAuthSession()).refresh(refreshToken: "OLD")
            let body = try sentBody()
            #expect(body == [
                "grant_type": "refresh_token",
                "refresh_token": "OLD",
                "client_id": FuelSwitchConstants.anthropicClientID,
            ])
            #expect(body["scope"] == nil)
        }

        @Test func theOpenAIRefreshSendsExactlyTheExpectedBody() async throws {
            MockProtocol.response = (200, Data(#"{"access_token":"a6","refresh_token":"r6","expires_in":3600}"#.utf8))
            _ = try await OpenAIOAuth(session: mockOAuthSession()).refresh(refreshToken: "OLD")
            let body = try sentBody()
            #expect(body["scope"] == FuelSwitchConstants.openAIRefreshScope)
            #expect(body["scope"] != FuelSwitchConstants.openAIScopes)
            #expect(body == [
                "grant_type": "refresh_token",
                "refresh_token": "OLD",
                "client_id": FuelSwitchConstants.openAIClientID,
                "scope": FuelSwitchConstants.openAIRefreshScope,
            ])
        }

        @Test func theAnthropicCodeExchangeSendsExactlyTheExpectedBody() async throws {
            MockProtocol.response = (200, Data(#"{"access_token":"a7","refresh_token":"r7","expires_in":3600}"#.utf8))
            _ = try await AnthropicOAuth(session: mockOAuthSession())
                .exchange(code: "code-anthropic", pkce: PKCE(verifier: "verifier-anthropic", state: "state-anthropic"), redirectURI: "http://localhost:1/callback")
            let body = try sentBody()
            #expect(body["grant_type"] == "authorization_code")
            #expect(body["code_verifier"] == "verifier-anthropic")
            #expect(body["client_id"] == FuelSwitchConstants.anthropicClientID)
            #expect(body["code"] == "code-anthropic")
            #expect(body["redirect_uri"] == "http://localhost:1/callback")
            #expect(body["state"] == "state-anthropic")
        }

        @Test func theOpenAICodeExchangeSendsExactlyTheExpectedBody() async throws {
            MockProtocol.response = (200, Data(#"{"access_token":"a8","refresh_token":"r8","expires_in":3600}"#.utf8))
            _ = try await OpenAIOAuth(session: mockOAuthSession())
                .exchange(code: "code-openai", pkce: PKCE(verifier: "verifier-openai", state: "state-openai"), redirectURI: FuelSwitchConstants.openAIRedirectURI)
            let body = try sentBody()
            #expect(body["grant_type"] == "authorization_code")
            #expect(body["code_verifier"] == "verifier-openai")
            #expect(body["client_id"] == FuelSwitchConstants.openAIClientID)
            #expect(body["code"] == "code-openai")
            #expect(body["redirect_uri"] == FuelSwitchConstants.openAIRedirectURI)
        }

        @Test func descriptionsDoNotLeakSecrets() {
            let secretAccess = "SECRET-ACCESS-XYZ"
            let secretRefresh = "SECRET-REFRESH-XYZ"
            let secretId = "SECRET-ID-XYZ"
            let secretVerifier = "SECRET-VERIFIER-XYZ"

            let tokens = Tokens(
                accessToken: secretAccess,
                refreshToken: secretRefresh,
                expiresAt: .distantFuture,
                idToken: secretId
            )
            let pkce = PKCE(verifier: secretVerifier, state: "public-state")

            let secrets = [secretAccess, secretRefresh, secretId, secretVerifier]
            for description in [String(describing: tokens), String(reflecting: tokens), String(describing: pkce), String(reflecting: pkce)] {
                for secret in secrets {
                    #expect(!description.contains(secret))
                }
            }
        }
    }
}
