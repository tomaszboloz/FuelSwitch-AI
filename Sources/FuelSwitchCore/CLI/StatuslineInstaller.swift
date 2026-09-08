import Foundation

/// Installs and removes the generated statusline script, merging the
/// `statusLine` key into Claude Code's `settings.json` in place — every
/// other key already there (hooks, permissions, plugin config) is preserved,
/// same discipline as `CLISwitcher`'s handling of `~/.claude.json`.
public struct StatuslineInstaller: Sendable {
    public let settingsURL: URL
    public let scriptURL: URL

    public init(settingsURL: URL = StatuslineInstaller.defaultSettingsURL, scriptURL: URL = StatuslineInstaller.defaultScriptURL) {
        self.settingsURL = settingsURL
        self.scriptURL = scriptURL
    }

    public static var defaultSettingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
            .appendingPathComponent("settings.json")
    }

    public static var defaultScriptURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
            .appendingPathComponent("fuelswitch-statusline.sh")
    }

    public enum Error: Swift.Error {
        case invalidSettingsFile
    }

    /// Whether `statusLine` in settings.json currently points at our script —
    /// not just whether a `statusLine` key exists, since it may be the
    /// user's own.
    public var isInstalled: Bool {
        guard let settings = try? readSettings(),
              let statusLine = settings["statusLine"] as? [String: Any] else { return false }
        return statusLine["command"] as? String == scriptURL.path
    }

    public func install(cacheDirectory: URL = StatuslineCache.defaultDirectory) throws {
        let script = StatuslineScriptGenerator.script(cacheDirectory: cacheDirectory)
        try AtomicFileWriter.write(data: Data(script.utf8), to: scriptURL, permissions: 0o700)

        var settings = try readSettings()
        settings["statusLine"] = [
            "type": "command",
            "command": scriptURL.path
        ]
        try writeSettings(settings)
    }

    /// Clears `statusLine` only if it still points at our script — never
    /// clobber one the user configured by hand after installing ours — then
    /// deletes the generated script file.
    public func uninstall() throws {
        var settings = try readSettings()
        if let statusLine = settings["statusLine"] as? [String: Any],
           statusLine["command"] as? String == scriptURL.path {
            settings.removeValue(forKey: "statusLine")
            try writeSettings(settings)
        }
        try? FileManager.default.removeItem(at: scriptURL)
    }

    private func readSettings() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return [:] }
        let data = try Data(contentsOf: settingsURL)
        guard !data.isEmpty else { return [:] }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Error.invalidSettingsFile
        }
        return json
    }

    private func writeSettings(_ settings: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try AtomicFileWriter.write(data: data, to: settingsURL, permissions: 0o644)
    }
}
