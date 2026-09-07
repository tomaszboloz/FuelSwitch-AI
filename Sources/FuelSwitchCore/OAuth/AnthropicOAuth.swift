import Foundation

public struct AnthropicOAuth: OAuthProvider {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public var requiredPort: UInt16 { 0 }

    public func authorizationURL(pkce: PKCE, redirectURI: String) -> URL {
        var components = URLComponents(url: FuelSwitchConstants.anthropicAuthorizeURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            .init(name: "client_id", value: FuelSwitchConstants.anthropicClientID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "scope", value: FuelSwitchConstants.anthropicScopes),
            .init(name: "code_challenge", value: pkce.challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: pkce.state),
        ]
        return components.url!
    }

    public func exchange(code: String, pkce: PKCE, redirectURI: String) async throws -> Tokens {
        try await TokenExchange.perform(
            url: FuelSwitchConstants.anthropicTokenURL,
            fields: [
                "grant_type": "authorization_code",
                "code": code,
                "redirect_uri": redirectURI,
                "client_id": FuelSwitchConstants.anthropicClientID,
                "code_verifier": pkce.verifier,
                "state": pkce.state,
            ],
            previousRefresh: nil,
            session: session
        )
    }

    public func refresh(refreshToken: String) async throws -> Tokens {
        try await TokenExchange.perform(
            url: FuelSwitchConstants.anthropicTokenURL,
            fields: [
                "grant_type": "refresh_token",
                "refresh_token": refreshToken,
                "client_id": FuelSwitchConstants.anthropicClientID,
            ],
            previousRefresh: refreshToken,
            session: session
        )
    }
}
