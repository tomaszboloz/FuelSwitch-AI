import AppKit
import Foundation

/// Opens an OAuth address in a browser session with no regular-profile
/// cookies. This prevents an existing Claude web session from silently being
/// used while the person is trying to add another account.
public struct PrivateBrowserLauncher {
    public enum LaunchError: Error, Equatable, LocalizedError {
        case noSupportedBrowser
        case commandFailed(browser: String)

        public var errorDescription: String? {
            switch self {
            case .noSupportedBrowser:
                "To add a Claude account privately, install Google Chrome, Microsoft Edge, Brave, or Firefox."
            case let .commandFailed(browser):
                "Could not open \(browser) in a private window."
            }
        }
    }

    private struct Browser: Equatable {
        let name: String
        let bundleIdentifier: String
        let privateArguments: [String]
    }

    private static let supportedBrowsers = [
        Browser(name: "Google Chrome", bundleIdentifier: "com.google.Chrome", privateArguments: ["--incognito"]),
        Browser(name: "Google Chrome Beta", bundleIdentifier: "com.google.Chrome.beta", privateArguments: ["--incognito"]),
        Browser(name: "Google Chrome Canary", bundleIdentifier: "com.google.Chrome.canary", privateArguments: ["--incognito"]),
        Browser(name: "Microsoft Edge", bundleIdentifier: "com.microsoft.edgemac", privateArguments: ["--inprivate"]),
        Browser(name: "Brave Browser", bundleIdentifier: "com.brave.Browser", privateArguments: ["--incognito"]),
        Browser(name: "Chromium", bundleIdentifier: "org.chromium.Chromium", privateArguments: ["--incognito"]),
        Browser(name: "Vivaldi", bundleIdentifier: "com.vivaldi.Vivaldi", privateArguments: ["--incognito"]),
        Browser(name: "Firefox", bundleIdentifier: "org.mozilla.firefox", privateArguments: ["-private-window"]),
    ]

    private let defaultApplicationURL: (URL) -> URL?
    private let applicationURL: (String) -> URL?
    private let bundleIdentifier: (URL) -> String?
    private let runCommand: (URL, [String]) throws -> Int32

    public init() {
        self.init(
            defaultApplicationURL: { NSWorkspace.shared.urlForApplication(toOpen: $0) },
            applicationURL: { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) },
            bundleIdentifier: { Bundle(url: $0)?.bundleIdentifier },
            runCommand: Self.runOpenCommand
        )
    }

    init(
        defaultApplicationURL: @escaping (URL) -> URL?,
        applicationURL: @escaping (String) -> URL?,
        bundleIdentifier: @escaping (URL) -> String?,
        runCommand: @escaping (URL, [String]) throws -> Int32
    ) {
        self.defaultApplicationURL = defaultApplicationURL
        self.applicationURL = applicationURL
        self.bundleIdentifier = bundleIdentifier
        self.runCommand = runCommand
    }

    /// The preferred browser is used when it supports a private-window command.
    /// Otherwise the first installed supported browser is chosen. Safari is not
    /// a fallback because macOS provides no reliable, supported way to force a
    /// new Safari private window from a URL launch.
    public func open(_ authorizationURL: URL) throws {
        guard let browser = selectBrowser(for: authorizationURL) else {
            throw LaunchError.noSupportedBrowser
        }

        let arguments = ["-na", browser.applicationURL.path, "--args"]
            + browser.definition.privateArguments
            + [authorizationURL.absoluteString]
        do {
            guard try runCommand(URL(fileURLWithPath: "/usr/bin/open"), arguments) == 0 else {
                throw LaunchError.commandFailed(browser: browser.definition.name)
            }
        } catch let error as LaunchError {
            throw error
        } catch {
            throw LaunchError.commandFailed(browser: browser.definition.name)
        }
    }

    private func selectBrowser(for authorizationURL: URL) -> (definition: Browser, applicationURL: URL)? {
        if let defaultURL = defaultApplicationURL(authorizationURL),
           let identifier = bundleIdentifier(defaultURL),
           let browser = Self.supportedBrowsers.first(where: { $0.bundleIdentifier == identifier }) {
            return (browser, defaultURL)
        }

        for browser in Self.supportedBrowsers {
            if let url = applicationURL(browser.bundleIdentifier) {
                return (browser, url)
            }
        }
        return nil
    }

    private static func runOpenCommand(executableURL: URL, arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}

/// Provider-specific browser policy for interactive OAuth.
///
/// Claude is deliberately isolated from normal browser cookies. Other
/// providers keep their existing browser behavior, including Gemini's explicit
/// account chooser in its OAuth request.
public struct OAuthBrowserLauncher {
    public enum LaunchError: Error, Equatable, LocalizedError {
        case standardBrowserUnavailable

        public var errorDescription: String? {
            "Could not open a browser for sign-in. Try again."
        }
    }

    private let openStandardURL: (URL) -> Bool
    private let openPrivateURL: (URL) throws -> Void

    public init() {
        self.init(
            openStandardURL: { NSWorkspace.shared.open($0) },
            openPrivateURL: { try PrivateBrowserLauncher().open($0) }
        )
    }

    init(
        openStandardURL: @escaping (URL) -> Bool,
        openPrivateURL: @escaping (URL) throws -> Void
    ) {
        self.openStandardURL = openStandardURL
        self.openPrivateURL = openPrivateURL
    }

    public func open(provider: Provider, authorizationURL: URL) throws {
        if provider == .anthropic {
            try openPrivateURL(authorizationURL)
        } else if !openStandardURL(authorizationURL) {
            throw LaunchError.standardBrowserUnavailable
        }
    }
}
