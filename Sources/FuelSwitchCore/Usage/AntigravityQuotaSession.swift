import Foundation

/// Quota authentication belongs to Antigravity, independently of Gemini CLI.
/// Read each saved session without replacing the active app's Keychain entry.
actor AntigravityQuotaSession {
    static let shared = AntigravityQuotaSession()

    func accessToken(email: String, session: URLSession) async throws -> String {
        let snapshot = AntigravitySync.snapshotURL(for: email, in: AntigravitySync.snapshotDirectory)
        let savedBeforeRefresh = try? Data(contentsOf: snapshot)
        let live = try? AntigravitySync.LoginStore.keychain.read()
        let data: Data
        if let live, AntigravitySync.email(fromStoredLogin: live)?.caseInsensitiveCompare(email) == .orderedSame {
            data = live
        } else {
            guard let saved = savedBeforeRefresh,
                  AntigravitySync.email(fromStoredLogin: saved)?.caseInsensitiveCompare(email) == .orderedSame
            else { throw UsageError.unavailableQuota }
            data = saved
        }

        let envelope = "go-keyring-base64:"
        let text = String(decoding: data, as: UTF8.self)
        let payload = text.hasPrefix(envelope)
            ? Data(base64Encoded: String(text.dropFirst(envelope.count))) : data
        guard let payload,
              var login = try JSONSerialization.jsonObject(with: payload) as? [String: Any],
              var token = login["token"] as? [String: Any],
              let access = token["access_token"] as? String, !access.isEmpty
        else { throw UsageError.unavailableQuota }

        if let expiry = token["expiry"] as? String,
           let date = AnthropicUsage.date(expiry), date.timeIntervalSinceNow > 120 {
            return access
        }

        guard let refresh = token["refresh_token"] as? String, !refresh.isEmpty,
              let idToken = login["id_token"] as? String ?? token["id_token"] as? String,
              let clientID = JWT.claims(idToken)["aud"] as? String
        else { throw UsageError.unavailableQuota }

        // Google's installed native client requires its bundled client secret.
        // Read it from the user's installed app; never embed it in FuelSwitch
        // or send a session to a different OAuth client. The binary can carry
        // both production and daily configurations; Google validates the pair.
        let secrets = Self.installedClientSecrets(clientID: clientID)
        for secret in secrets {
            var request = URLRequest(url: FuelSwitchConstants.geminiTokenURL)
            request.httpMethod = "POST"
            request.timeoutInterval = 15
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            var body = URLComponents()
            body.queryItems = [
                URLQueryItem(name: "client_id", value: clientID),
                URLQueryItem(name: "client_secret", value: secret),
                URLQueryItem(name: "refresh_token", value: refresh),
                URLQueryItem(name: "grant_type", value: "refresh_token"),
            ]
            request.httpBody = body.percentEncodedQuery?.data(using: .utf8)
            let (responseData, response) = try await session.data(for: request)
            guard let result = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
                throw UsageError.unavailableQuota
            }
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                if result["error"] as? String == "invalid_client" { continue }
                throw UsageError.unavailableQuota
            }
            guard let renewed = result["access_token"] as? String, !renewed.isEmpty,
                  let seconds = result["expires_in"] as? Double else { throw UsageError.unavailableQuota }
            if let renewedID = result["id_token"] as? String {
                guard (JWT.claims(renewedID)["email"] as? String)?.caseInsensitiveCompare(email) == .orderedSame
                else { throw UsageError.unavailableQuota }
                login["id_token"] = renewedID
            }
            token["access_token"] = renewed
            token["expiry"] = ISO8601DateFormatter().string(from: Date().addingTimeInterval(seconds))
            if let renewedRefresh = result["refresh_token"] as? String { token["refresh_token"] = renewedRefresh }
            login["token"] = token
            let updated = try JSONSerialization.data(withJSONObject: login)
            // Switching can save a newer session during the network request.
            // Never replace that session with the one this poll started with.
            if (try? Data(contentsOf: snapshot)) == savedBeforeRefresh {
                try AtomicFileWriter.write(
                    data: text.hasPrefix(envelope) ? AntigravitySync.keyringValue(from: updated) : updated,
                    to: snapshot, permissions: 0o600
                )
            }
            return renewed
        }
        throw UsageError.unavailableQuota
    }

    private static func installedClientSecrets(clientID: String) -> [String] {
        let roots = [URL(fileURLWithPath: "/Applications"),
                     FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
        let regex = try? NSRegularExpression(pattern: "GOCSPX-[A-Za-z0-9_-]{28}")
        for root in roots {
            let binary = root.appendingPathComponent("Antigravity.app/Contents/Resources/bin/language_server")
            guard let data = try? Data(contentsOf: binary, options: .mappedIfSafe),
                  data.range(of: Data(clientID.utf8)) != nil, let regex else { continue }
            let text = String(decoding: data, as: UTF8.self)
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            return Array(Set(matches.compactMap { Range($0.range, in: text).map { String(text[$0]) } })).sorted()
        }
        return []
    }
}
