import Foundation

/// An Anthropic account's identity, established solely from the server's
/// response — never from the alias or anything else the user typed. Anthropic,
/// unlike OpenAI, returns no `id_token`, so the email and plan can only be
/// learned after the code exchange, with one extra request.
public struct AnthropicProfile: Sendable, Equatable {
    public let email: String
    public let plan: String?
    /// The organisation this token authorised against. Anthropic binds a token
    /// to one organisation, and an account can hold several — a subscription
    /// and an API Console team, say. Only the subscription one reports usage,
    /// so when the endpoint refuses, this name is the only thing that tells the
    /// user which login they actually made.
    public let organizationName: String?
    /// Whether this login holds a Claude subscription at all. It is reported on
    /// the ACCOUNT, while the token is issued for one ORGANIZATION — so the two
    /// disagree exactly in the case worth explaining: a login that pays for a
    /// subscription whose token was issued for its API organisation instead.
    public let hasSubscription: Bool

    public init(
        email: String,
        plan: String?,
        organizationName: String? = nil,
        hasSubscription: Bool = false
    ) {
        self.email = email
        self.plan = plan
        self.organizationName = organizationName
        self.hasSubscription = hasSubscription
    }
}

public enum AnthropicProfileError: Error, Equatable {
    case http(Int)
    /// A 2xx response, but without `account.email` — there is nothing to build
    /// an account identity from.
    case responseWithoutEmail
}

public struct AnthropicProfileClient: Sendable {
    private struct Response: Decodable {
        struct AccountBody: Decodable {
            let email: String?
            let hasClaudeMax: Bool?
            let hasClaudePro: Bool?
        }
        struct Organization: Decodable {
            let name: String?
            let rateLimitTier: String?
        }
        let account: AccountBody?
        let organization: Organization?
    }

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetches the account identity with a freshly exchanged access token.
    /// Throws rather than returning any kind of stand-in — an account under a
    /// made-up identity is worse than no account.
    public func fetch(accessToken: String) async throws -> AnthropicProfile {
        var request = URLRequest(url: FuelSwitchConstants.anthropicProfileURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(FuelSwitchConstants.anthropicUserAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw AnthropicProfileError.http(http.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let result = try? decoder.decode(Response.self, from: data),
              let email = result.account?.email
        else {
            throw AnthropicProfileError.responseWithoutEmail
        }

        return AnthropicProfile(
            email: email,
            plan: result.organization?.rateLimitTier,
            organizationName: result.organization?.name,
            hasSubscription: (result.account?.hasClaudeMax ?? false)
                || (result.account?.hasClaudePro ?? false)
        )
    }
}
