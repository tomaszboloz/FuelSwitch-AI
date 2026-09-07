import Testing
import Foundation
@testable import FuelSwitchCore

private func temporaryStoreDirectory() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func sampleAccount(email: String = "a@b.pl") -> Account {
    Account(
        provider: .anthropic, email: email,
        accessToken: "tok", refreshToken: "ref",
        expiresAt: Date(timeIntervalSince1970: 1_788_500_000)
    )
}

@Test func anEmptyStoreReturnsAnEmptyList() throws {
    let store = AccountStore(directory: try temporaryStoreDirectory())
    #expect(try store.load().isEmpty)
}

@Test func writingAndReadingPreservesTokens() throws {
    let store = AccountStore(directory: try temporaryStoreDirectory())
    try store.upsert(sampleAccount())
    let loaded = try store.load()
    #expect(loaded.count == 1)
    #expect(loaded[0].refreshToken == "ref")
}

@Test func upsertOverwritesAnAccountWithTheSameIdentifier() throws {
    let store = AccountStore(directory: try temporaryStoreDirectory())
    try store.upsert(sampleAccount())
    var changed = sampleAccount()
    changed.accessToken = "rotated"
    try store.upsert(changed)
    let loaded = try store.load()
    #expect(loaded.count == 1)
    #expect(loaded[0].accessToken == "rotated")
}

@Test func theFileHas600Permissions() throws {
    let store = AccountStore(directory: try temporaryStoreDirectory())
    try store.upsert(sampleAccount())
    let attributes = try FileManager.default.attributesOfItem(atPath: store.fileURL.path)
    let permissions = try #require(attributes[.posixPermissions] as? NSNumber)
    #expect(permissions.int16Value == 0o600)
}

@Test func removingAnAccountWorksByIdentifier() throws {
    let store = AccountStore(directory: try temporaryStoreDirectory())
    try store.upsert(sampleAccount(email: "a@b.pl"))
    try store.upsert(sampleAccount(email: "c@d.pl"))
    try store.remove(id: "anthropic:a@b.pl")
    #expect(try store.load().map(\.email) == ["c@d.pl"])
}

/// Regression guard: `replaceItemAt` keeps the destination file's permissions
/// from before the overwrite rather than those of the temporary file — so if
/// someone removed the trailing `setAttributes` after `replaceItemAt` as
/// "apparently redundant", the file holding the tokens would become
/// world-readable (0644).
@Test func aSecondWriteRepairsWrongPermissionsOnAnExistingFile() throws {
    let store = AccountStore(directory: try temporaryStoreDirectory())
    try store.upsert(sampleAccount())
    try FileManager.default.setAttributes(
        [.posixPermissions: NSNumber(value: Int16(0o644))],
        ofItemAtPath: store.fileURL.path
    )
    try store.upsert(sampleAccount(email: "c@d.pl"))
    let attributes = try FileManager.default.attributesOfItem(atPath: store.fileURL.path)
    let permissions = try #require(attributes[.posixPermissions] as? NSNumber)
    #expect(permissions.int16Value == 0o600)
}
