import Foundation

public struct Tokens: Sendable, Equatable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date
    public let idToken: String?

    public init(accessToken: String, refreshToken: String, expiresAt: Date, idToken: String? = nil) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.idToken = idToken
    }
}

extension Tokens: CustomStringConvertible, CustomDebugStringConvertible {
    /// Shows the shape without the secrets — the expiry date and whether an
    /// idToken is present — so that `print`/`po` in the debugger never spells
    /// out a real token.
    public var description: String {
        "Tokens(accessToken: <redacted>, refreshToken: <redacted>, expiresAt: \(expiresAt), idToken: \(idToken != nil ? "<redacted>" : "nil"))"
    }
    public var debugDescription: String { description }
}

public enum OAuthError: Error, Equatable {
    case invalidGrant
    case stateMismatch
    case portInUse(UInt16)
    case responseWithoutToken
    case http(Int)
    /// The sign-in was interrupted (for instance `CallbackListener.stop()` was
    /// called while someone was still awaiting `waitForCode()`) before the code
    /// arrived.
    case cancelled
    /// Nobody completed the sign-in in the browser within the allotted time
    /// (see `LoginFlow.loginTimeout`) — kept separate from `cancelled` so the
    /// UI can name it, instead of quietly implying the user chose to cancel.
    case timedOut
    /// Codex returned neither an email nor an account id
    /// (`chatgpt_account_id`) in the `id_token`. Storing such an account under
    /// a stand-in identity could silently overwrite another account
    /// (`Account.id` is `provider:email`) and would send usage requests without
    /// the required `ChatGPT-Account-Id` header.
    case incompleteCodexIdentity
}

public protocol OAuthProvider: Sendable {
    /// The port the loopback server has to listen on. Zero means any free port.
    var requiredPort: UInt16 { get }
    func authorizationURL(pkce: PKCE, redirectURI: String) -> URL
    func exchange(code: String, pkce: PKCE, redirectURI: String) async throws -> Tokens
    func refresh(refreshToken: String) async throws -> Tokens
}

struct TokenResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let idToken: String?
    let expiresIn: Double?
    let error: String?
}

enum TokenExchange {
    /// The single place where `invalid_grant` is decided — for both providers
    /// it means the same thing: this account has to be signed in again.
    static func perform(
        url: URL,
        fields: [String: String],
        previousRefresh: String?,
        session: URLSession
    ) async throws -> Tokens {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: fields)

        let (data, response) = try await session.data(for: request)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let result = try? decoder.decode(TokenResponse.self, from: data)

        // `invalid_grant` is the only "you must sign in again" signal, and it is
        // decided purely from the response body, never from the status code
        // alone. Every other 4xx (`invalid_scope`, `invalid_client` and the
        // like) used to land in this same branch merely because it carried a
        // 400 or a 401, which across eleven Codex accounts meant eleven
        // pointless browser sign-ins that all ended the same way, instead
        // of the ordinary backoff path.
        if result?.error == "invalid_grant" { throw OAuthError.invalidGrant }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw OAuthError.http(http.statusCode)
        }
        guard let access = result?.accessToken else { throw OAuthError.responseWithoutToken }
        // Anthropic rotates the refresh token; when the response carries none,
        // the existing one stands (passed in as `previousRefresh`). On the code
        // exchange path `previousRefresh` is always `nil` — no refresh token in
        // either place means a broken server response, not a cue to store an
        // empty token that would only detonate at the next refresh as a
        // misleading `invalid_grant`.
        guard let refreshToken = result?.refreshToken ?? previousRefresh else {
            throw OAuthError.responseWithoutToken
        }

        return Tokens(
            accessToken: access,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(result?.expiresIn ?? 3600),
            idToken: result?.idToken
        )
    }
}
