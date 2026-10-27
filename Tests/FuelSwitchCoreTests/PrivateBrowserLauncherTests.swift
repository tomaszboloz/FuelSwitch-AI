import Foundation
import Testing
@testable import FuelSwitchCore

@Suite struct PrivateBrowserLauncherTests {
    private let authorizationURL = URL(string: "https://console.anthropic.com/oauth/authorize?state=secure-state&code_challenge=pkce-value")!

    @Test func preferredChromeOpensTheExactAuthorizationAddressInAnIncognitoWindow() throws {
        var capturedExecutable: URL?
        var capturedArguments: [String]?
        let chromeURL = URL(fileURLWithPath: "/Applications/Google Chrome.app")
        let launcher = PrivateBrowserLauncher(
            defaultApplicationURL: { _ in chromeURL },
            applicationURL: { _ in nil },
            bundleIdentifier: { _ in "com.google.Chrome" },
            runCommand: { executable, arguments in
                capturedExecutable = executable
                capturedArguments = arguments
                return 0
            }
        )

        try launcher.open(authorizationURL)

        #expect(capturedExecutable == URL(fileURLWithPath: "/usr/bin/open"))
        #expect(capturedArguments == [
            "-na", "/Applications/Google Chrome.app", "--args", "--incognito", authorizationURL.absoluteString,
        ])
    }

    @Test func fallsBackToFirefoxPrivateWindowWhenTheDefaultBrowserIsUnsupported() throws {
        var capturedArguments: [String]?
        let firefoxURL = URL(fileURLWithPath: "/Applications/Firefox.app")
        let launcher = PrivateBrowserLauncher(
            defaultApplicationURL: { _ in URL(fileURLWithPath: "/Applications/Safari.app") },
            applicationURL: { identifier in identifier == "org.mozilla.firefox" ? firefoxURL : nil },
            bundleIdentifier: { _ in "com.apple.Safari" },
            runCommand: { _, arguments in
                capturedArguments = arguments
                return 0
            }
        )

        try launcher.open(authorizationURL)

        #expect(capturedArguments == [
            "-na", "/Applications/Firefox.app", "--args", "-private-window", authorizationURL.absoluteString,
        ])
    }

    @Test func refusesToFallBackToANormalBrowserSession() {
        let launcher = PrivateBrowserLauncher(
            defaultApplicationURL: { _ in URL(fileURLWithPath: "/Applications/Safari.app") },
            applicationURL: { _ in nil },
            bundleIdentifier: { _ in "com.apple.Safari" },
            runCommand: { _, _ in 0 }
        )

        #expect(throws: PrivateBrowserLauncher.LaunchError.noSupportedBrowser) {
            try launcher.open(authorizationURL)
        }
    }

    @Test func reportsAFailedPrivateBrowserLaunch() {
        let chromeURL = URL(fileURLWithPath: "/Applications/Google Chrome.app")
        let launcher = PrivateBrowserLauncher(
            defaultApplicationURL: { _ in chromeURL },
            applicationURL: { _ in nil },
            bundleIdentifier: { _ in "com.google.Chrome" },
            runCommand: { _, _ in 1 }
        )

        #expect(throws: PrivateBrowserLauncher.LaunchError.commandFailed(browser: "Google Chrome")) {
            try launcher.open(authorizationURL)
        }
    }

    @Test func claudeAlwaysUsesThePrivateBrowserPath() throws {
        var usedPrivateBrowser = false
        let launcher = OAuthBrowserLauncher(
            openStandardURL: { _ in
                Issue.record("Claude must not use the standard browser session")
                return true
            },
            openPrivateURL: { url in
                usedPrivateBrowser = true
                #expect(url == authorizationURL)
            }
        )

        try launcher.open(provider: .anthropic, authorizationURL: authorizationURL)

        #expect(usedPrivateBrowser)
    }

    @Test func codexAndGeminiKeepUsingTheStandardBrowserPath() throws {
        var openedProviders = 0
        let launcher = OAuthBrowserLauncher(
            openStandardURL: { url in
                openedProviders += 1
                return url == authorizationURL
            },
            openPrivateURL: { _ in Issue.record("Only Claude should request a private browser") }
        )

        try launcher.open(provider: .openai, authorizationURL: authorizationURL)
        try launcher.open(provider: .gemini, authorizationURL: authorizationURL)

        #expect(openedProviders == 2)
    }

    @Test func reportsWhenTheStandardBrowserCannotBeOpened() {
        let launcher = OAuthBrowserLauncher(
            openStandardURL: { _ in false },
            openPrivateURL: { _ in Issue.record("Unexpected private browser launch") }
        )

        #expect(throws: OAuthBrowserLauncher.LaunchError.standardBrowserUnavailable) {
            try launcher.open(provider: .openai, authorizationURL: authorizationURL)
        }
    }
}
