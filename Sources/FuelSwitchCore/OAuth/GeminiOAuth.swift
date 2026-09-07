import Foundation

/// OAuth provider for Google Gemini CLI authentication
public struct GeminiOAuth: OAuthProvider {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public var requiredPort: UInt16 { 0 } // Any available port on 127.0.0.1

    public func authorizationURL(pkce: PKCE, redirectURI: String) -> URL {
        var components = URLComponents(url: FuelSwitchConstants.geminiAuthorizeURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: FuelSwitchConstants.geminiClientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: FuelSwitchConstants.geminiScopes),
            URLQueryItem(name: "state", value: pkce.state),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        return components.url!
    }

    public func exchange(code: String, pkce: PKCE, redirectURI: String) async throws -> Tokens {
        var request = URLRequest(url: FuelSwitchConstants.geminiTokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "code": code,
            "client_id": FuelSwitchConstants.geminiClientID,
            "client_secret": FuelSwitchConstants.geminiClientSecret,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": pkce.verifier
        ]
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw UsageError.unauthorized
        }

        struct GoogleTokenResponse: Decodable {
            let access_token: String
            let refresh_token: String?
            let expires_in: Int?
            let id_token: String?
        }

        let decoded = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
        let expiresAt = Date().addingTimeInterval(TimeInterval(decoded.expires_in ?? 3600))
        return Tokens(
            accessToken: decoded.access_token,
            refreshToken: decoded.refresh_token ?? "gemini_refresh_\(UUID().uuidString)",
            expiresAt: expiresAt,
            idToken: decoded.id_token
        )
    }

    public func refresh(refreshToken: String) async throws -> Tokens {
        var request = URLRequest(url: FuelSwitchConstants.geminiTokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "refresh_token": refreshToken,
            "client_id": FuelSwitchConstants.geminiClientID,
            "client_secret": FuelSwitchConstants.geminiClientSecret,
            "grant_type": "refresh_token"
        ]
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw UsageError.unauthorized
        }

        struct GoogleRefreshResponse: Decodable {
            let access_token: String
            let expires_in: Int?
            let id_token: String?
        }

        let decoded = try JSONDecoder().decode(GoogleRefreshResponse.self, from: data)
        let expiresAt = Date().addingTimeInterval(TimeInterval(decoded.expires_in ?? 3600))
        return Tokens(
            accessToken: decoded.access_token,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            idToken: decoded.id_token
        )
    }
}

