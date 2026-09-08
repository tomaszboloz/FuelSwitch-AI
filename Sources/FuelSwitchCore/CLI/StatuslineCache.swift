import Foundation

/// A snapshot of one provider's active account usage, written after every
/// poll so the statusline script — a separate process launched by Claude
/// Code itself, with no access to this app's in-memory `Poller` — has
/// something to read. Freshness is bounded by the app's poll interval, not
/// by when the statusline script happens to run.
public struct StatuslineSnapshot: Codable, Sendable, Equatable {
    public let provider: Provider
    public let email: String
    public let sessionPercent: Double
    public let weeklyPercent: Double
    public let fetchedAt: Date

    public init(provider: Provider, email: String, sessionPercent: Double, weeklyPercent: Double, fetchedAt: Date) {
        self.provider = provider
        self.email = email
        self.sessionPercent = sessionPercent
        self.weeklyPercent = weeklyPercent
        self.fetchedAt = fetchedAt
    }
}

/// Caches one provider's snapshot in its own file, so the statusline script
/// can show Codex and Gemini usage alongside Claude's own — not just the
/// Claude Code session the script happens to be running inside of — without
/// needing to parse a multi-record JSON array with plain `grep`/`cut`.
public struct StatuslineCache: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public init(provider: Provider) {
        self.fileURL = StatuslineCache.defaultFileURL(for: provider)
    }

    public static var defaultDirectory: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FuelSwitch")
    }

    public static func defaultFileURL(for provider: Provider) -> URL {
        defaultFileURL(for: provider, in: defaultDirectory)
    }

    public static func defaultFileURL(for provider: Provider, in directory: URL) -> URL {
        directory.appendingPathComponent("statusline-cache-\(provider.rawValue).json")
    }

    public func read() throws -> StatuslineSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(StatuslineSnapshot.self, from: data)
    }

    public func write(_ snapshot: StatuslineSnapshot) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(snapshot)
        try AtomicFileWriter.write(data: data, to: fileURL, permissions: 0o600)
    }
}
