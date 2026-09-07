import Foundation

public enum CodexUsage {
    private struct Response: Decodable {
        struct RateLimit: Decodable {
            struct Window: Decodable {
                let usedPercent: Double?
                let resetAt: Double?
            }
            let primaryWindow: Window?
            let secondaryWindow: Window?
        }
        let email: String?
        let planType: String?
        let rateLimit: RateLimit?
    }

    private static func window(_ window: Response.RateLimit.Window?, label: String) -> LimitWindow {
        LimitWindow(
            percent: window?.usedPercent ?? 0,
            resetsAt: window?.resetAt.map { Date(timeIntervalSince1970: $0) },
            label: label
        )
    }

    public static func parse(
        _ data: Data,
        fetchedAt: Date
    ) throws -> (usage: AccountUsage, email: String?, plan: String?) {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(Response.self, from: data)

        let usage = AccountUsage(
            session: window(response.rateLimit?.primaryWindow, label: "5 hours"),
            weekly: window(response.rateLimit?.secondaryWindow, label: "Week"),
            scoped: [],
            fetchedAt: fetchedAt,
            staleness: .fresh
        )
        return (usage, response.email, response.planType)
    }
}

public struct CodexUsageClient: UsageProvider {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetch(account: Account) async throws -> AccountUsage {
        var request = URLRequest(url: FuelSwitchConstants.codexUsageURL)
        request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
        if let id = account.accountId {
            request.setValue(id, forHTTPHeaderField: "ChatGPT-Account-Id")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        try checkStatus(response)
        var parsed = try CodexUsage.parse(data, fetchedAt: Date()).usage

        // Concurrently query rate-limit-reset-credits if available
        let (resetCount, firstCreditId) = await fetchResetCredits(account: account)
        parsed = AccountUsage(
            session: parsed.session,
            weekly: parsed.weekly,
            scoped: parsed.scoped,
            fetchedAt: parsed.fetchedAt,
            staleness: parsed.staleness,
            resetCreditsAvailable: max(1, resetCount),
            resetCreditId: firstCreditId
        )
        return parsed
    }

    /// Queries the private ChatGPT wham endpoint for banked rate-limit reset credits.
    public func fetchResetCredits(account: Account) async -> (availableCount: Int, firstCreditId: String?) {
        var request = URLRequest(url: FuelSwitchConstants.codexResetCreditsURL)
        request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
        if let id = account.accountId {
            request.setValue(id, forHTTPHeaderField: "ChatGPT-Account-Id")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200
        else {
            return (0, nil)
        }

        struct CreditItem: Decodable {
            let creditId: String?
            let status: String?
        }
        struct CreditsResponse: Decodable {
            let availableCount: Int?
            let credits: [CreditItem]?
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let decoded = try? decoder.decode(CreditsResponse.self, from: data) else {
            return (0, nil)
        }

        let availableCredits = decoded.credits?.filter { $0.status == "available" } ?? []
        let count = decoded.availableCount ?? availableCredits.count
        let firstId = availableCredits.first?.creditId
        return (count, firstId)
    }

    /// Redeems a rate-limit reset credit to instantly reset usage limits.
    public func consumeResetCredit(account: Account, creditId: String?) async throws {
        var request = URLRequest(url: FuelSwitchConstants.codexResetConsumeURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
        if let id = account.accountId {
            request.setValue(id, forHTTPHeaderField: "ChatGPT-Account-Id")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "redeem_request_id": UUID().uuidString
        ]
        if let creditId {
            body["credit_id"] = creditId
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await session.data(for: request)
        try checkStatus(response)
    }
}
