import Testing
import Foundation
@testable import FuelSwitchCore

@Suite struct StatuslineCacheTests {
    private func makeTemporaryCache() -> StatuslineCache {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("statusline-cache-tests-\(UUID().uuidString).json")
        return StatuslineCache(fileURL: url)
    }

    @Test func readingBeforeAnyWriteReturnsNil() throws {
        let cache = makeTemporaryCache()
        #expect(try cache.read() == nil)
    }

    @Test func aWrittenSnapshotReadsBackIdentically() throws {
        let cache = makeTemporaryCache()
        let snapshot = StatuslineSnapshot(
            provider: .anthropic,
            email: "a@b.pl",
            sessionPercent: 42.5,
            weeklyPercent: 10.0,
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        try cache.write(snapshot)
        #expect(try cache.read() == snapshot)
        try? FileManager.default.removeItem(at: cache.fileURL)
    }

    @Test func aSecondWriteOverwritesTheFirst() throws {
        let cache = makeTemporaryCache()
        try cache.write(StatuslineSnapshot(provider: .openai, email: "a@b.pl", sessionPercent: 1, weeklyPercent: 2, fetchedAt: Date(timeIntervalSince1970: 1_700_000_000)))
        let second = StatuslineSnapshot(provider: .openai, email: "c@d.pl", sessionPercent: 3, weeklyPercent: 4, fetchedAt: Date(timeIntervalSince1970: 1_700_000_100))
        try cache.write(second)
        #expect(try cache.read() == second)
        try? FileManager.default.removeItem(at: cache.fileURL)
    }

    @Test func perProviderDefaultFileURLsAreDistinct() {
        let urls = Provider.allCases.map { StatuslineCache.defaultFileURL(for: $0) }
        #expect(Set(urls.map(\.path)).count == Provider.allCases.count)
    }
}
