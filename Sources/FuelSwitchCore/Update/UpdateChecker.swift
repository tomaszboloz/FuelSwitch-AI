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

/// Reads the same appcast as Sparkle. A GitHub tag alone is not an installable
/// update. Sparkle remains responsible for signature verification and install.
public struct UpdateChecker: Sendable {
    public enum CheckError: Error, Equatable {
        case invalidFeed
        case httpStatus(Int)
    }

    private let session: URLSession
    private let endpoint: URL?

    public init(
        session: URLSession = .shared,
        endpoint: URL? = FuelSwitchConstants.updateFeedURL
    ) {
        self.session = session
        self.endpoint = endpoint
    }

    /// Only a successful, valid response can mean "up to date". Callers may
    /// silence background failures, but must not turn them into that message.
    public func check(currentVersion: String) async throws -> AvailableUpdate? {
        guard let endpoint else { throw CheckError.invalidFeed }
        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("application/rss+xml, application/xml, text/xml", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("FuelSwitch-AI/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CheckError.invalidFeed }
        guard (200..<300).contains(http.statusCode) else { throw CheckError.httpStatus(http.statusCode) }
        let feed = AppcastReader()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = feed
        guard parser.parse(), !feed.releases.isEmpty, !feed.invalidItem else { throw CheckError.invalidFeed }
        return feed.releases.filter { Self.isNewer($0.version, than: currentVersion) }
            .max { Self.isNewer($1.version, than: $0.version) }
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

/// The public feed contains one or more complete, signed update enclosures.
/// Missing metadata is a broken check, not proof that the installed app is current.
private final class AppcastReader: NSObject, XMLParserDelegate {
    var releases: [AvailableUpdate] = []
    var invalidItem = false
    private var inItem = false
    private var version = ""
    private var element = ""
    private var url: URL?
    private var signed = false

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes: [String: String]) {
        element = elementName
        if elementName == "item" {
            inItem = true
            version = ""
            url = nil
            signed = false
        } else if inItem, elementName == "enclosure" {
            url = attributes["url"].flatMap(URL.init(string:))
            signed = attributes["sparkle:edSignature"].flatMap { Data(base64Encoded: $0) }?.count == 64
                && (Int(attributes["length"] ?? "") ?? 0) > 0
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inItem, element == "sparkle:shortVersionString" { version += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        element = ""
        guard elementName == "item" else { return }
        inItem = false
        let number = version.trimmingCharacters(in: .whitespacesAndNewlines)
        guard signed, let url, url.scheme == "https", url.host != nil,
              number.range(of: #"^\d+(\.\d+)*$"#, options: .regularExpression) != nil else {
            invalidItem = true
            return
        }
        releases.append(AvailableUpdate(version: number, url: url))
    }
}
