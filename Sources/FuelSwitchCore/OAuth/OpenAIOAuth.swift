import Foundation

public struct OpenAIOAuth: OAuthProvider {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public var requiredPort: UInt16 { FuelSwitchConstants.openAIPort }

    public func authorizationURL(pkce: PKCE, redirectURI: String) -> URL {
        var components = URLComponents(url: FuelSwitchConstants.openAIAuthorizeURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            .init(name: "client_id", value: FuelSwitchConstants.openAIClientID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "scope", value: FuelSwitchConstants.openAIScopes),
            .init(name: "code_challenge", value: pkce.challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: pkce.state),
            .init(name: "id_token_add_organizations", value: "true"),
            .init(name: "codex_cli_simplified_flow", value: "true"),
        ]
        return components.url!
    }

    public func exchange(code: String, pkce: PKCE, redirectURI: String) async throws -> Tokens {
        try await TokenExchange.perform(
            url: FuelSwitchConstants.openAITokenURL,
            fields: [
                "grant_type": "authorization_code",
                "code": code,
                "redirect_uri": redirectURI,
                "client_id": FuelSwitchConstants.openAIClientID,
                "code_verifier": pkce.verifier,
            ],
            previousRefresh: nil,
            session: session
        )
    }

    public func refresh(refreshToken: String) async throws -> Tokens {
        try await TokenExchange.perform(
            url: FuelSwitchConstants.openAITokenURL,
            fields: [
                "grant_type": "refresh_token",
                "refresh_token": refreshToken,
                "client_id": FuelSwitchConstants.openAIClientID,
                "scope": FuelSwitchConstants.openAIRefreshScope,
            ],
            previousRefresh: refreshToken,
            session: session
        )
    }
}
