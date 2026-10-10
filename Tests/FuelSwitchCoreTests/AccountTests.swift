import Testing
import Foundation
@testable import FuelSwitchCore

@Suite struct AccountTests {
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

    @Test func providerPropertiesAndIdentifiable() {
        for provider in Provider.allCases {
            #expect(!provider.displayName.isEmpty)
            #expect(!provider.menuBarLabel.isEmpty)
            #expect(!provider.monogram.isEmpty)
            #expect(provider.id == provider.rawValue)
        }
    }

    @Test func accountIdIsCaseInsensitiveEmail() {
        let acc1 = Account(provider: .anthropic, email: "User@Domain.Com")
        let acc2 = Account(provider: .anthropic, email: "user@domain.com")
        #expect(acc1.id == acc2.id)
        #expect(acc1.id == "anthropic:user@domain.com")
    }

    @Test func accountDescriptionMasksSensitiveTokens() {
        let account = Account(
            provider: .anthropic,
            email: "secret@example.com",
            plan: "Pro",
            accessToken: "secret_access_token_12345",
            refreshToken: "secret_refresh_token_67890"
        )
        let desc = account.description
        #expect(!desc.contains("secret_access_token_12345"))
        #expect(!desc.contains("secret_refresh_token_67890"))
        #expect(desc.contains("redacted"))
    }
}
