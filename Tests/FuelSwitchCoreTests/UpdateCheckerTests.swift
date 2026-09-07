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

        @Test func aNewerReleaseIsReported() async {
            MockProtocol.response = (200, Data(#"""
            {"tag_name":"v1.4","html_url":"https://example.invalid/releases/v1.4","draft":false,"prerelease":false}
            """#.utf8))
            let update = await checker().check(currentVersion: "1.0")
            #expect(update?.version == "1.4")
            #expect(update?.url.absoluteString == "https://example.invalid/releases/v1.4")
        }

        @Test func theCurrentReleaseIsNotReported() async {
            MockProtocol.response = (200, Data(#"""
            {"tag_name":"v1.0","html_url":"https://example.invalid/releases/v1.0"}
            """#.utf8))
            #expect(await checker().check(currentVersion: "1.0") == nil)
        }

        @Test func draftsAndPrereleasesAreIgnored() async {
            for field in ["\"draft\":true", "\"prerelease\":true"] {
                MockProtocol.response = (200, Data("""
                {"tag_name":"v9.0","html_url":"https://example.invalid/x",\(field)}
                """.utf8))
                #expect(await checker().check(currentVersion: "1.0") == nil)
            }
        }

        /// A failed check is not worth interrupting anyone about, so it has to
        /// come back as "no update" rather than as an error.
        @Test func failuresAreSilent() async {
            MockProtocol.response = (503, Data())
            #expect(await checker().check(currentVersion: "1.0") == nil)

            MockProtocol.response = (200, Data("not json".utf8))
            #expect(await checker().check(currentVersion: "1.0") == nil)
        }
    }
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
