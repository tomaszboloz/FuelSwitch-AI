import Foundation

extension LoginFlow {
    struct Identity: Equatable {
        let email: String
        let plan: String?
        let accountId: String?
        var organizationName: String? = nil
        var hasSubscription: Bool = false
    }

    /// Resolves account identity for the given provider from tokens or profile API.
    func accountIdentity(
        provider: Provider,
        tokens: Tokens,
        profileFactory: (String) async throws -> AnthropicProfile
    ) async throws -> Identity {
        switch provider {
        case .anthropic:
            let profile = try await profileFactory(tokens.accessToken)
            return Identity(
                email: profile.email,
                plan: profile.plan,
                accountId: nil,
                organizationName: profile.organizationName,
                hasSubscription: profile.hasSubscription
            )
        case .openai:
            let claims = tokens.idToken.map(JWT.claims) ?? [:]
            let auth = claims["https://api.openai.com/auth"] as? [String: Any]
            guard let email = claims["email"] as? String,
                  let accountId = auth?["chatgpt_account_id"] as? String
            else {
                throw OAuthError.incompleteCodexIdentity
            }
            return Identity(
                email: email,
                plan: auth?["chatgpt_plan_type"] as? String,
                accountId: accountId
            )
        case .gemini:
            return try await resolveGeminiIdentity(tokens: tokens)
        }
    }

    private func resolveGeminiIdentity(tokens: Tokens) async throws -> Identity {
        if let idToken = tokens.idToken {
            let claims = JWT.claims(idToken)
            if let email = claims["email"] as? String {
                return Identity(email: email, plan: "Gemini CLI", accountId: nil, organizationName: "Google")
            }
        }
        var request = URLRequest(url: FuelSwitchConstants.geminiUserInfoURL)
        request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
        if let (data, response) = try? await URLSession.shared.data(for: request),
           let http = response as? HTTPURLResponse, http.statusCode == 200,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let email = json["email"] as? String {
            return Identity(email: email, plan: "Gemini CLI", accountId: nil, organizationName: "Google")
        }
        if let active = CLISwitcher.activeGeminiEmail() {
            return Identity(email: active, plan: "Gemini CLI", accountId: nil, organizationName: "Google")
        }
        throw OAuthError.incompleteCodexIdentity
    }
}
