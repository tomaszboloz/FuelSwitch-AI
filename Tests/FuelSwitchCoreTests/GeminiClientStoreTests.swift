import Testing
import Foundation
@testable import FuelSwitchCore

@Suite struct GeminiClientStoreTests {
    private func makeTemporaryDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func loadReturnsNilWhenFileDoesNotExist() throws {
        let dir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = GeminiClientStore(directory: dir)
        #expect(store.load() == nil)
    }

    @Test func saveAndLoadRoundtripsCredentials() throws {
        let dir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = GeminiClientStore(directory: dir)

        let creds = GeminiClientCredentials(clientID: "test-client-id", clientSecret: "test-secret")
        try store.save(creds)

        let loaded = store.load()
        #expect(loaded == creds)
        #expect(loaded?.clientID == "test-client-id")
        #expect(loaded?.clientSecret == "test-secret")
    }

    @Test func saveOverwritesExistingCredentials() throws {
        let dir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = GeminiClientStore(directory: dir)

        try store.save(GeminiClientCredentials(clientID: "id1", clientSecret: "sec1"))
        try store.save(GeminiClientCredentials(clientID: "id2", clientSecret: "sec2"))

        let loaded = store.load()
        #expect(loaded?.clientID == "id2")
        #expect(loaded?.clientSecret == "sec2")
    }

    @Test func clearRemovesSavedFile() throws {
        let dir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = GeminiClientStore(directory: dir)

        try store.save(GeminiClientCredentials(clientID: "id", clientSecret: "sec"))
        #expect(store.load() != nil)

        try store.clear()
        #expect(store.load() == nil)

        // Clearing an already empty store does not throw
        try store.clear()
    }

    @Test func loadReturnsNilOnCorruptedData() throws {
        let dir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = GeminiClientStore(directory: dir)

        try Data("invalid json".utf8).write(to: store.fileURL)
        #expect(store.load() == nil)
    }
}
