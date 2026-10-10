import AppKit

extension AntigravitySync {
    @MainActor
    public static func performSwitch(
        enabled: Bool,
        swap: () throws -> Void,
        stop: () async throws -> [URL] = Self.stop,
        open: (URL) async throws -> Void = CodexDesktopSync.open,
        verify: () async throws -> Void = {}
    ) async throws {
        let urls = enabled ? try await stop() : []
        do { try swap() }
        catch {
            for url in urls { try? await open(url) }
            throw error
        }
        for url in urls {
            do { try await open(url) }
            catch { throw SyncError.applicationNotFound }
        }
        if enabled { try await verify() }
    }

    @MainActor
    public static func confirmSignedIn(
        email: String,
        attempts: Int = 40,
        read: () async -> String? = runningSignedInEmail,
        pause: () async throws -> Void = { try await Task.sleep(for: .milliseconds(500)) }
    ) async throws {
        for attempt in 0..<attempts {
            if let actual = await read(), actual.caseInsensitiveCompare(email) == .orderedSame { return }
            if attempt + 1 < attempts { try await pause() }
        }
        throw SyncError.accountMismatch
    }

    @MainActor
    static func relaunchURLs(runningURLs: [URL?], fallback: () throws -> URL) throws -> [URL] {
        var urls: [URL] = []
        for url in runningURLs.compactMap({ $0 }) where !urls.contains(url) { urls.append(url) }
        return urls.isEmpty ? [try fallback()] : urls
    }

    @MainActor
    public static func stop() async throws -> [URL] {
        let applications = bundleIdentifiers.flatMap {
            NSRunningApplication.runningApplications(withBundleIdentifier: $0)
        }
        let urls = try relaunchURLs(runningURLs: applications.map(\.bundleURL)) {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifiers[0]) else {
                throw SyncError.applicationNotFound
            }
            return url
        }
        for application in applications {
            guard application.terminate() else { throw SyncError.quitRefused }
        }
        do {
            try await CodexDesktopSync.waitForExit(isRunning: { applications.contains { !$0.isTerminated } })
        } catch {
            throw SyncError.quitTimedOut
        }
        return urls
    }
}
