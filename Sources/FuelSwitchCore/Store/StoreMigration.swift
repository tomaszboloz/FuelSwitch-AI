import Foundation

/// A one-off move of the data from the directory of the app's previous name.
/// The old directory disappears only once the new one can be read back — an
/// interruption halfway through leaves the data in the old place and nowhere
/// else.
public enum StoreMigration {
    /// Returns `true` when data was actually moved.
    @discardableResult
    public static func run(from old: URL, to new: URL) throws -> Bool {
        let oldStore = AccountStore(directory: old)
        let newStore = AccountStore(directory: new)

        guard FileManager.default.fileExists(atPath: oldStore.fileURL.path) else {
            return false
        }
        guard try newStore.load().isEmpty else { return false }

        let accounts = try oldStore.load()
        guard !accounts.isEmpty else { return false }

        try newStore.save(accounts)

        // Verify before deleting: the write may have succeeded where the read
        // does not.
        guard try newStore.load().count == accounts.count else { return false }

        try? FileManager.default.removeItem(at: old)
        return true
    }
}
