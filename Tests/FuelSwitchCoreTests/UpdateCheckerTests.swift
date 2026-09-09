import Testing
import Foundation
@testable import FuelSwitchCore

@Test func aHigherVersionIsNewer() {
    #expect(UpdateChecker.isNewer("1.1", than: "1.0"))
    #expect(UpdateChecker.isNewer("2.0", than: "1.9"))
    #expect(UpdateChecker.isNewer("1.0.1", than: "1.0"))
}

@Test func theSameVersionIsNotNewer() {
    #expect(!UpdateChecker.isNewer("1.0", than: "1.0"))
    // Missing components count as zero, or 1.0 would forever offer to upgrade
    // itself to 1.0.0.
    #expect(!UpdateChecker.isNewer("1.0.0", than: "1.0"))
    #expect(!UpdateChecker.isNewer("1.0", than: "1.0.0"))
}

@Test func anOlderVersionIsNotNewer() {
    #expect(!UpdateChecker.isNewer("0.9", than: "1.0"))
    #expect(!UpdateChecker.isNewer("1.0", than: "1.0.1"))
}

/// Compared as text, 1.10 would sort before 1.9 and the tenth release would
/// never be offered to anyone.
@Test func componentsAreComparedAsNumbersNotText() {
    #expect(UpdateChecker.isNewer("1.10", than: "1.9"))
    #expect(!UpdateChecker.isNewer("1.9", than: "1.10"))
}

@Test func aLeadingVIsIgnored() {
    #expect(UpdateChecker.isNewer("v1.1", than: "1.0"))
    #expect(!UpdateChecker.isNewer("v1.0", than: "1.0"))
    #expect(UpdateChecker.number(from: "v2.3") == "2.3")
    #expect(UpdateChecker.number(from: "2.3") == "2.3")
}

/// A tag we cannot read is not grounds for telling someone to go and download
/// something.
@Test func anUnreadableVersionIsNeverNewer() {
    #expect(!UpdateChecker.isNewer("nightly", than: "1.0"))
    #expect(!UpdateChecker.isNewer("", than: "1.0"))
}

extension NetworkTests {
    @Suite struct UpdateCheckerTests {
        private func checker() -> UpdateChecker {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [MockProtocol.self]
            return UpdateChecker(
                session: URLSession(configuration: configuration),
                endpoint: URL(string: "https://example.invalid/latest")!
            )
        }

        private func feed(_ versions: [String], signed: Bool = true, scheme: String = "https") -> Data {
            let signature = signed ? Data(repeating: 1, count: 64).base64EncodedString() : ""
            let items = versions.map { version in
                """
                <item><sparkle:version>8</sparkle:version>
                <sparkle:shortVersionString>\(version)</sparkle:shortVersionString>
                <enclosure url="\(scheme)://example.invalid/\(version).zip" length="123" sparkle:edSignature="\(signature)"/>
                </item>
                """
            }.joined()
            return Data("<rss xmlns:sparkle=\"http://www.andymatuschak.org/xml-namespaces/sparkle\"><channel>\(items)</channel></rss>".utf8)
        }

        @Test func version110IsOfferedTo105FromTheInstallerFeed() async throws {
            MockProtocol.response = (200, feed(["1.1.0"]))
            let update = try await checker().check(currentVersion: "1.0.5")
            #expect(update?.version == "1.1.0")
            #expect(update?.url.absoluteString == "https://example.invalid/1.1.0.zip")
            #expect(MockProtocol.lastHeaders["Cache-Control"] == "no-cache")
        }

        @Test func onlySuccessfulChecksCanReportUpToDate() async throws {
            MockProtocol.response = (200, feed(["1.1.0"]))
            #expect(try await checker().check(currentVersion: "1.1.0") == nil)
            #expect(try await checker().check(currentVersion: "1.1.1") == nil)
        }

        @Test func feedOrderDoesNotHideTheNewestRelease() async throws {
            MockProtocol.response = (200, feed(["1.1.1", "1.0.5", "1.1.0"]))
            #expect(try await checker().check(currentVersion: "1.0.5")?.version == "1.1.1")
        }

        @Test func serverErrorsCannotMasqueradeAsUpToDate() async {
            for status in [403, 404, 429, 503] {
                MockProtocol.response = (status, Data())
                await #expect(throws: UpdateChecker.CheckError.httpStatus(status)) {
                    try await checker().check(currentVersion: "1.0.5")
                }
            }
        }

        @Test func missingOrInvalidFeedCannotMasqueradeAsUpToDate() async {
            for data in [Data("not XML".utf8), feed([]), feed(["nightly"]),
                         feed(["1.1.0"], signed: false), feed(["1.1.0"], scheme: "http"),
                         Data("<rss><channel><item>".utf8)] {
                MockProtocol.response = (200, data)
                await #expect(throws: UpdateChecker.CheckError.invalidFeed) {
                    try await checker().check(currentVersion: "1.0.5")
                }
            }
        }

        @Test func unavailableEndpointIsAnError() async {
            await #expect(throws: UpdateChecker.CheckError.invalidFeed) {
                try await UpdateChecker(endpoint: nil).check(currentVersion: "1.0.5")
            }
        }

        @Test func offlineCheckIsNotReportedAsUpToDate() async {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [OfflineUpdateProtocol.self]
            let offline = UpdateChecker(session: URLSession(configuration: configuration))
            await #expect(throws: URLError.self) {
                try await offline.check(currentVersion: "1.0.5")
            }
        }

        @Test(.enabled(if: ProcessInfo.processInfo.environment["FUELSWITCH_TEST_LIVE_UPDATES"] == "1"))
        func productionFeedOffersAnUpgradeFrom105() async throws {
            let update = try #require(await UpdateChecker().check(currentVersion: "1.0.5"))
            #expect(UpdateChecker.isNewer(update.version, than: "1.0.5"))
            #expect(update.url.host == "github.com")
        }

        @Test func appAndSparkleUseTheSameFeed() throws {
            let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .deletingLastPathComponent().deletingLastPathComponent()
            let data = try Data(contentsOf: root.appendingPathComponent("Resources/Info.plist"))
            let plist = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
            #expect(plist["SUFeedURL"] as? String == FuelSwitchConstants.updateFeedURL?.absoluteString)
        }
    }
}

private final class OfflineUpdateProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }
    override func stopLoading() {}
}

/// The release sequence this project actually intends to use. Each version has
/// to be newer than the one before it, all the way past the point where text
/// comparison would fall apart.
@Test func anOrdinaryReleaseSequenceAlwaysMovesForward() {
    let sequence = ["1.0", "1.1", "1.2", "1.9", "1.10", "1.11", "1.20", "2.0", "2.0.1", "2.1", "10.0"]
    for (index, version) in sequence.enumerated() where index > 0 {
        let previous = sequence[index - 1]
        #expect(
            UpdateChecker.isNewer(version, than: previous),
            "\(version) should be offered to someone running \(previous)"
        )
        #expect(
            !UpdateChecker.isNewer(previous, than: version),
            "\(previous) must never be offered to someone running \(version)"
        )
    }
}

/// Zero-padded versions are a trap rather than a fix. Components are read as
/// numbers, so 1.01 and 1.1 are the same version: a release numbered 1.01 would
/// never be offered to anyone already running 1.1, and vice versa. The padding
/// buys nothing either, since 1.10 already sorts after 1.9 on its own.
@Test func zeroPaddedVersionsAreIndistinguishableFromPlainOnes() {
    #expect(!UpdateChecker.isNewer("1.01", than: "1.1"))
    #expect(!UpdateChecker.isNewer("1.1", than: "1.01"))
    #expect(!UpdateChecker.isNewer("1.02", than: "1.2"))
    // Padded on its own it still orders correctly, which is exactly why the
    // problem stays hidden until the two styles meet.
    #expect(UpdateChecker.isNewer("1.02", than: "1.01"))
}
