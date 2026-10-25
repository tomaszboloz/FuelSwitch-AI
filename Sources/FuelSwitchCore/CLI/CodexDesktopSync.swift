import AppKit

/// Desktop auth is cached in the running app-server. A graceful relaunch
/// reloads the persisted login; never kill processes or revoke OAuth tokens.
@MainActor
public enum CodexDesktopSync {
    public enum SyncError: Error { case applicationNotFound, quitRefused, quitTimedOut, launchTimedOut }
    public static let bundleIdentifier = "com.openai.codex"

    public static func performSwitch(
        enabled: Bool,
        writeCredentials: () throws -> Void,
        stop: () async throws -> URL = Self.stop,
        open: (URL) async throws -> Void = Self.open
    ) async throws {
        let url = enabled ? try await stop() : nil
        do { try writeCredentials() }
        catch {
            if let url { try? await open(url) }
            throw error
        }
        if let url {
            do { try await open(url) }
            catch { throw SyncError.applicationNotFound }
        }
    }

    public static func applicationURL() throws -> URL {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            throw SyncError.applicationNotFound
        }
        return url
    }

    public static func stop() async throws -> URL {
        let url = try applicationURL()
        let applications = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        for application in applications {
            guard application.terminate() else { throw SyncError.quitRefused }
        }
        try await waitForExit(isRunning: { applications.contains { !$0.isTerminated } })
        return url
    }

    static func waitForExit(
        isRunning: () -> Bool,
        attempts: Int = 100,
        pause: () async throws -> Void = { try await Task.sleep(for: .milliseconds(200)) }
    ) async throws {
        for _ in 0..<attempts {
            if !isRunning() { return }
            try await pause()
        }
        guard !isRunning() else { throw SyncError.quitTimedOut }
    }

    public static func open(_ url: URL) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        // Launch Services can still know about the instance we just quit.
        // Start a fresh process so it reloads the credentials written above.
        configuration.createsNewApplicationInstance = !NSWorkspace.shared.runningApplications.contains {
            !$0.isTerminated && $0.bundleURL?.standardizedFileURL == url.standardizedFileURL
        }
        let application = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        try await finishLaunching(
            isReady: { application.isFinishedLaunching },
            isTerminated: { application.isTerminated },
            reopen: {
                // Electron apps can finish starting with no window after a
                // programmatic quit. A normal open request to the now-ready
                // instance supplies the same reopen event as clicking its icon.
                let reopen = NSWorkspace.OpenConfiguration()
                reopen.activates = true
                _ = try await NSWorkspace.shared.openApplication(at: url, configuration: reopen)
            },
            activate: { application.activate(options: [.activateAllWindows]) }
        )
    }

    static func finishLaunching(
        isReady: () -> Bool,
        isTerminated: () -> Bool,
        reopen: () async throws -> Void,
        activate: () -> Bool,
        attempts: Int = 100,
        pause: () async throws -> Void = { try await Task.sleep(for: .milliseconds(200)) }
    ) async throws {
        for attempt in 0..<attempts {
            guard !isTerminated() else { throw SyncError.applicationNotFound }
            if isReady() {
                try await reopen()
                guard !isTerminated() else { throw SyncError.applicationNotFound }
                _ = activate()
                return
            }
            if attempt + 1 < attempts { try await pause() }
        }
        throw SyncError.launchTimedOut
    }
}
