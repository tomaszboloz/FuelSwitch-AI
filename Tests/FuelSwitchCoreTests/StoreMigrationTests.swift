import Testing
import Foundation
@testable import FuelSwitchCore

private func tempDir() throws -> URL {
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

@Test func migrationMovesAccountsAndRemovesOldDirectory() throws {
    let root = try tempDir()
    let old = root.appendingPathComponent("Limity")
    let new = root.appendingPathComponent("FuelSwitch")
    try AccountStore(directory: old).upsert(sampleAccount())

    let migrated = try StoreMigration.run(from: old, to: new)

    #expect(migrated == true)
    #expect(try AccountStore(directory: new).load().map(\.email) == ["a@b.pl"])
    #expect(FileManager.default.fileExists(atPath: old.path) == false)
}

@Test func migratedFileKeeps0600Permissions() throws {
    let root = try tempDir()
    let old = root.appendingPathComponent("Limity")
    let new = root.appendingPathComponent("FuelSwitch")
    try AccountStore(directory: old).upsert(sampleAccount())

    _ = try StoreMigration.run(from: old, to: new)

    let attrs = try FileManager.default.attributesOfItem(
        atPath: AccountStore(directory: new).fileURL.path
    )
    let perms = try #require(attrs[.posixPermissions] as? NSNumber)
    #expect(perms.int16Value == 0o600)
}

@Test func migrationDoesNothingWhenNewStoreAlreadyHasData() throws {
    let root = try tempDir()
    let old = root.appendingPathComponent("Limity")
    let new = root.appendingPathComponent("FuelSwitch")
    try AccountStore(directory: old).upsert(sampleAccount(email: "old@b.pl"))
    try AccountStore(directory: new).upsert(sampleAccount(email: "new@b.pl"))

    let migrated = try StoreMigration.run(from: old, to: new)

    #expect(migrated == false)
    #expect(try AccountStore(directory: new).load().map(\.email) == ["new@b.pl"])
    #expect(try AccountStore(directory: old).load().map(\.email) == ["old@b.pl"])
}

@Test func migrationIsSafeWhenNothingToMigrate() throws {
    let root = try tempDir()
    let migrated = try StoreMigration.run(
        from: root.appendingPathComponent("Limity"),
        to: root.appendingPathComponent("FuelSwitch")
    )
    #expect(migrated == false)
}

@Test func migrationProceedsWhenNewDirectoryExistsButIsEmpty() throws {
    let root = try tempDir()
    let old = root.appendingPathComponent("Limity")
    let new = root.appendingPathComponent("FuelSwitch")
    try AccountStore(directory: old).upsert(sampleAccount())
    try FileManager.default.createDirectory(at: new, withIntermediateDirectories: true)

    let migrated = try StoreMigration.run(from: old, to: new)

    #expect(migrated == true)
    #expect(try AccountStore(directory: new).load().map(\.email) == ["a@b.pl"])
}

@Test func migrationIsNoOpWhenOldFileHoldsEmptyArray() throws {
    let root = try tempDir()
    let old = root.appendingPathComponent("Limity")
    let new = root.appendingPathComponent("FuelSwitch")
    try AccountStore(directory: old).save([])

    let migrated = try StoreMigration.run(from: old, to: new)

    #expect(migrated == false)
    #expect(FileManager.default.fileExists(atPath: old.path) == true)
}
