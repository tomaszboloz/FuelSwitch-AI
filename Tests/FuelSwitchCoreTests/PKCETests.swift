import Testing
import Foundation
@testable import FuelSwitchCore

@Test func theChallengeIsUnpaddedBase64URL() {
    let pkce = PKCE.generate()
    #expect(!pkce.challenge.contains("="))
    #expect(!pkce.challenge.contains("+"))
    #expect(!pkce.challenge.contains("/"))
}

@Test func theChallengeIsTheSha256OfTheVerifier() {
    // The vector from RFC 7636, section 4.4.
    let pkce = PKCE(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk", state: "s")
    #expect(pkce.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
}

@Test func theAnthropicAuthorizationURLCarriesTheRequiredParameters() {
    let pkce = PKCE(verifier: "v", state: "st")
    let url = AnthropicOAuth().authorizationURL(pkce: pkce, redirectURI: "http://localhost:7777/callback")
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
    func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
    // The subscription sign-in, not the API console — the console URL issues
    // tokens for an API organisation, which reports no subscription limits.
    #expect(url.host == "claude.com")
    #expect(url.path == "/cai/oauth/authorize")
    #expect(value("client_id") == FuelSwitchConstants.anthropicClientID)
    #expect(value("response_type") == "code")
    #expect(value("code_challenge_method") == "S256")
    #expect(value("state") == "st")
    #expect(value("redirect_uri") == "http://localhost:7777/callback")
    #expect(value("scope") == FuelSwitchConstants.anthropicScopes)
}

@Test func theOpenAIAuthorizationURLCarriesTheCodexSpecificParameters() {
    let pkce = PKCE(verifier: "v", state: "st")
    let url = OpenAIOAuth().authorizationURL(pkce: pkce, redirectURI: FuelSwitchConstants.openAIRedirectURI)
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
    func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
    #expect(url.host == "auth.openai.com")
    #expect(value("id_token_add_organizations") == "true")
    #expect(value("codex_cli_simplified_flow") == "true")
    #expect(value("scope") == FuelSwitchConstants.openAIScopes)
}
