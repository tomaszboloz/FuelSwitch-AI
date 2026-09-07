import Foundation
import CryptoKit

public struct PKCE: Sendable {
    public let verifier: String
    public let state: String

    public init(verifier: String, state: String) {
        self.verifier = verifier
        self.state = state
    }

    public static func generate() -> PKCE {
        PKCE(verifier: randomString(), state: randomString())
    }

    public var challenge: String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64URLEncoded
    }

    private static func randomString() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            preconditionFailure("SecRandomCopyBytes failed (status \(status)) — cannot generate PKCE safely")
        }
        return Data(bytes).base64URLEncoded
    }
}

extension PKCE: CustomStringConvertible, CustomDebugStringConvertible {
    /// The verifier is a secret — it never reaches a description, not even in
    /// the debugger. The state is not secret (it travels in the URL in the
    /// clear), so it can be shown.
    public var description: String { "PKCE(verifier: <redacted>, state: \(state))" }
    public var debugDescription: String { description }
}

extension Data {
    /// Base64 in its URL variant, unpadded — what RFC 7636 requires.
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
