import Testing
import Foundation
@testable import FuelSwitchCore

@Suite struct GeminiUsageClientTests {
    @Test func fetchThrowsUnavailableQuotaWhenNoSessionExists() async {
        let client = GeminiUsageClient()
        let account = Account(provider: .gemini, email: "nonexistent.\(UUID().uuidString)@google.com")

        await #expect(throws: UsageError.unavailableQuota) {
            _ = try await client.fetch(account: account)
        }
    }
}
