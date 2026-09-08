import Testing
import Foundation
@testable import FuelSwitchCore

/// Simulates an `accounts.json` written by a version of the app that
/// predates `nickname` — the field must decode to `nil`, not fail.
@Test func anAccountWithoutTheNicknameFieldDecodesWithANilNickname() throws {
    let json = """
    {
        "provider": "anthropic",
        "email": "a@b.pl",
        "accessToken": "tok",
        "refreshToken": "ref",
        "expiresAt": 1788500000,
        "needsReauth": false,
        "hasSubscription": true
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    let account = try decoder.decode(Account.self, from: json)
    #expect(account.nickname == nil)
    #expect(account.email == "a@b.pl")
}
