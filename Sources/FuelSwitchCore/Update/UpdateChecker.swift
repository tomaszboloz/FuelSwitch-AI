import Foundation

/// A release newer than the one running.
public struct AvailableUpdate: Equatable, Sendable {
    public let version: String
    public let url: URL

    public init(version: String, url: URL) {
        self.version = version
        self.url = url
    }
}

/// Asks GitHub whether a newer release exists, and nothing more.
///
/// This is deliberately not an auto-updater. Downloading and swapping a signed
/// bundle safely is Sparkle's job, and Sparkle brings its own update feed and
/// its own signing keys. What people actually need first is to find out that a
/// new version exists, so that is all this does: one request, a version
/// comparison, and a link.
public struct UpdateChecker: Sendable {
    private let session: URLSession
    private let endpoint: URL?

    public init(
        session: URLSession = .shared,
        endpoint: URL? = FuelSwitchConstants.latestReleaseURL
    ) {
        self.session = session
        self.endpoint = endpoint
    }

    private struct Release: Decodable {
        let tagName: String?
        let htmlUrl: String?
        let draft: Bool?
        let prerelease: Bool?
    }

    /// Returns the newer release, or `nil` when there is none. Never throws:
    /// a failed update check is not something to interrupt anyone about.
    public func check(currentVersion: String) async -> AvailableUpdate? {
        guard let endpoint else { return nil }
        var request = URLRequest(url: endpoint)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("FuelSwitch-AI/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode)
        else { return nil }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let release = try? decoder.decode(Release.self, from: data),
              release.draft != true,
              release.prerelease != true,
              let tag = release.tagName,
              let link = release.htmlUrl.flatMap(URL.init(string:)),
              Self.isNewer(tag, than: currentVersion)
        else { return nil }

        return AvailableUpdate(version: Self.number(from: tag), url: link)
    }

    /// Strips a leading "v" and anything that is not part of the number.
    static func number(from tag: String) -> String {
        tag.hasPrefix("v") || tag.hasPrefix("V") ? String(tag.dropFirst()) : tag
    }

    /// Compares dotted version numbers component by component, as numbers.
    /// Comparing them as text would put 1.10 before 1.9, and missing components
    /// count as zero so that 1.1 and 1.1.0 are the same version rather than an
    /// endless upgrade prompt.
    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        let left = components(number(from: candidate))
        let right = components(number(from: current))
        guard !left.isEmpty else { return false }

        for index in 0..<max(left.count, right.count) {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0
            if a != b { return a > b }
        }
        return false
    }

    private static func components(_ version: String) -> [Int] {
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        let numbers = parts.map { part -> Int? in
            Int(part.prefix(while: \.isNumber))
        }
        // A version we cannot read is not a version we should act on.
        guard !numbers.contains(where: { $0 == nil }) else { return [] }
        return numbers.compactMap { $0 }
    }
}
