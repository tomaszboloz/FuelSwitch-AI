import Foundation

public struct GeminiUsageClient: UsageProvider {
    private static let loadCodeAssistURL = URL(string: "https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist")!
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetch(account: Account) async throws -> AccountUsage {
        // Saved Antigravity credentials let inactive accounts refresh without
        // switching the app.
        if let access = try? await AntigravityQuotaSession.shared.accessToken(email: account.email, session: session),
           let usage = try? await fetchAntigravityQuota(accessToken: access, email: account.email) {
            return usage
        }
        // Every Antigravity window runs its own language server.
        if let localUsage = await fetchFromLocalLanguageServer(email: account.email) {
            return localUsage
        }

        throw UsageError.unavailableQuota
    }

    private func fetchFromLocalLanguageServer(email: String) async -> AccountUsage? {
        for server in AntigravityLanguageServer.running() where server.isStandaloneApp {
            guard let signedIn = await server.signedInEmail(),
                  signedIn.caseInsensitiveCompare(email) == .orderedSame else { continue }
            if let quota = await server.call("RetrieveUserQuotaSummary"),
               let usage = try? GeminiUsage.parseLocalQuota(quota, fetchedAt: Date()),
               let after = await server.signedInEmail(),
               after.caseInsensitiveCompare(email) == .orderedSame {
                return usage
            }
        }
        return nil
    }

    private func fetchAntigravityQuota(accessToken: String, email: String) async throws -> AccountUsage {
        var identityRequest = URLRequest(url: FuelSwitchConstants.geminiUserInfoURL)
        identityRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        identityRequest.timeoutInterval = 15
        let (identity, identityResponse) = try await session.data(for: identityRequest)
        try checkStatus(identityResponse, body: identity)
        guard let profile = try JSONSerialization.jsonObject(with: identity) as? [String: Any],
              (profile["email"] as? String)?.caseInsensitiveCompare(email) == .orderedSame
        else { throw UsageError.unavailableQuota }

        let project = try await companionProject(accessToken: accessToken)
        let url = URL(string: "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("antigravity/2.19.1", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["project": project])
        let (quota, response) = try await session.data(for: request)
        try checkStatus(response, body: quota)
        let summary = try JSONSerialization.jsonObject(with: quota)
        let wrapped = try JSONSerialization.data(withJSONObject: ["response": summary])
        return try GeminiUsage.parseLocalQuota(wrapped, fetchedAt: Date())
    }

    private func companionProject(accessToken: String) async throws -> String {
        var request = URLRequest(url: Self.loadCodeAssistURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("antigravity/2.12.2", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "metadata": [
                "ideType": "ANTIGRAVITY",
                "platform": "PLATFORM_UNSPECIFIED",
                "pluginType": "GEMINI",
            ],
        ])

        let (data, response) = try await session.data(for: request)
        try checkStatus(response, body: data)

        struct Bootstrap: Decodable { let cloudaicompanionProject: String? }
        guard let project = try JSONDecoder().decode(Bootstrap.self, from: data).cloudaicompanionProject,
              !project.isEmpty
        else {
            throw UsageError.unavailableQuota
        }
        return project
    }
}
