import Foundation

/// One assistant turn's token usage, extracted from a Claude Code project
/// transcript line. Claude Code writes one `.jsonl` file per session under
/// `~/.claude/projects/<sanitized-cwd>/`, one JSON object per line; only
/// `"type": "assistant"` lines carry a `message.usage` block.
public struct ClaudeLogEntry: Sendable, Equatable {
    public let date: Date
    public let model: String
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationTokens: Int
    public let cacheReadTokens: Int

    public init(date: Date, model: String, inputTokens: Int, outputTokens: Int, cacheCreationTokens: Int, cacheReadTokens: Int) {
        self.date = date
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
    }

    public var totalTokens: Int { inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens }
}

public enum ClaudeProjectLogParser {
    public static var defaultProjectsRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
            .appendingPathComponent("projects")
    }

    /// Parses one JSONL transcript file. Lines that aren't a well-formed
    /// assistant/usage entry are skipped rather than failing the whole file —
    /// real transcripts mix user/assistant/tool-result lines, and a session
    /// can be mid-write when this runs.
    public static func parseFile(at url: URL, calendar: Calendar = Calendar(identifier: .gregorian)) -> [ClaudeLogEntry] {
        guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else { return [] }

        var entries: [ClaudeLogEntry] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let entry = parseLine(String(line), calendar: calendar) else { continue }
            entries.append(entry)
        }
        return entries
    }

    static func parseLine(_ line: String, calendar: Calendar) -> ClaudeLogEntry? {
        guard let lineData = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
              json["type"] as? String == "assistant",
              let timestampString = json["timestamp"] as? String,
              let timestamp = Self.timestampFormatter.date(from: timestampString),
              let message = json["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any]
        else {
            return nil
        }

        return ClaudeLogEntry(
            date: calendar.startOfDay(for: timestamp),
            model: message["model"] as? String ?? "unknown",
            inputTokens: usage["input_tokens"] as? Int ?? 0,
            outputTokens: usage["output_tokens"] as? Int ?? 0,
            cacheCreationTokens: usage["cache_creation_input_tokens"] as? Int ?? 0,
            cacheReadTokens: usage["cache_read_input_tokens"] as? Int ?? 0
        )
    }

    /// Parses every `*.jsonl` file one level under each project directory of
    /// `projectsRoot`. Safe to call with a missing directory (fresh install,
    /// no Claude Code history yet) — returns an empty array.
    public static func parseAllProjects(projectsRoot: URL = defaultProjectsRoot) -> [ClaudeLogEntry] {
        guard let projectDirs = try? FileManager.default.contentsOfDirectory(at: projectsRoot, includingPropertiesForKeys: nil) else {
            return []
        }

        var entries: [ClaudeLogEntry] = []
        for dir in projectDirs {
            guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for file in files where file.pathExtension == "jsonl" {
                entries.append(contentsOf: parseFile(at: file))
            }
        }
        return entries
    }

    // Never mutated after creation; ISO8601DateFormatter.date(from:) is safe
    // to call concurrently once configured.
    nonisolated(unsafe) private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
