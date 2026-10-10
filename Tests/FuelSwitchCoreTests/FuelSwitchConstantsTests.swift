import Testing
import Foundation
@testable import FuelSwitchCore

@Suite struct FuelSwitchConstantsTests {
    @Test func endpointsHaveValidSchemesAndHosts() {
        #expect(FuelSwitchConstants.anthropicUsageURL.scheme == "https")
        #expect(FuelSwitchConstants.anthropicProfileURL.scheme == "https")
        #expect(FuelSwitchConstants.anthropicAuthorizeURL.scheme == "https")
        #expect(FuelSwitchConstants.anthropicTokenURL.scheme == "https")

        #expect(FuelSwitchConstants.codexUsageURL.scheme == "https")
        #expect(FuelSwitchConstants.codexResetCreditsURL.scheme == "https")
        #expect(FuelSwitchConstants.codexResetConsumeURL.scheme == "https")
        #expect(FuelSwitchConstants.openAIAuthorizeURL.scheme == "https")
        #expect(FuelSwitchConstants.openAITokenURL.scheme == "https")

        #expect(FuelSwitchConstants.geminiAuthorizeURL.scheme == "https")
        #expect(FuelSwitchConstants.geminiTokenURL.scheme == "https")
        #expect(FuelSwitchConstants.geminiUserInfoURL.scheme == "https")
    }

    @Test func clientIDsAndScopesAreNonEmpty() {
        #expect(!FuelSwitchConstants.anthropicClientID.isEmpty)
        #expect(!FuelSwitchConstants.anthropicScopes.isEmpty)
        #expect(!FuelSwitchConstants.anthropicBeta.isEmpty)

        #expect(!FuelSwitchConstants.openAIClientID.isEmpty)
        #expect(!FuelSwitchConstants.openAIScopes.isEmpty)
        #expect(!FuelSwitchConstants.openAIRefreshScope.isEmpty)
        #expect(FuelSwitchConstants.openAIPort == 1455)

        #expect(!FuelSwitchConstants.geminiScopes.isEmpty)
    }

    @Test func feedAndReleaseURLsAreValid() {
        #expect(FuelSwitchConstants.latestReleaseURL?.scheme == "https")
        #expect(FuelSwitchConstants.updateFeedURL?.scheme == "https")
    }

    @Test func geminiConfigurationProperties() {
        _ = FuelSwitchConstants.geminiClientID
        _ = FuelSwitchConstants.geminiClientSecret
        let configured = FuelSwitchConstants.geminiIsConfigured
        #expect(configured == (!FuelSwitchConstants.geminiClientID.isEmpty && !FuelSwitchConstants.geminiClientSecret.isEmpty))
    }
}
