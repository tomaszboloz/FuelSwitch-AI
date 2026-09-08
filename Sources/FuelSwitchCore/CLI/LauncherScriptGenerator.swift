import Foundation

/// Generates a shell snippet the user pastes into `~/.zshrc` (or similar):
/// one function per account, each opening the app's `fuelswitch://switch`
/// URL scheme to make that account the active CLI account without opening
/// the app UI first.
public enum LauncherScriptGenerator {
    public static func shellFunction(accounts: [Account]) -> String {
        guard !accounts.isEmpty else { return "" }

        var exampleNames = Set<String>()
        let exampleName = uniqueFunctionName(for: accounts[0], usedNames: &exampleNames)
        var lines = [
            "# FuelSwitch AI — per-profile launcher functions.",
            "# Paste into ~/.zshrc (or ~/.bashrc), open a new shell, then run e.g. `\(exampleName)`.",
            ""
        ]
        var usedNames = Set<String>()

        for account in accounts {
            let name = uniqueFunctionName(for: account, usedNames: &usedNames)
            guard let encodedId = account.id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { continue }
            lines.append("\(name)() {")
            lines.append("    open \"fuelswitch://switch?id=\(encodedId)\"")
            lines.append("}")
            lines.append("")
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .newlines) + "\n"
    }

    private static func uniqueFunctionName(for account: Account, usedNames: inout Set<String>) -> String {
        let base = sanitize(account.nickname ?? account.email)
        let stem = base.isEmpty ? "fs-account" : "fs-\(base)"
        var candidate = stem
        var suffix = 2
        while usedNames.contains(candidate) {
            candidate = "\(stem)-\(suffix)"
            suffix += 1
        }
        usedNames.insert(candidate)
        return candidate
    }

    /// Lowercase alphanumerics joined by single dashes — a safe, readable
    /// shell function name from an arbitrary nickname or email.
    private static func sanitize(_ raw: String) -> String {
        var result = ""
        var lastWasDash = false
        for scalar in raw.lowercased().unicodeScalars {
            if CharacterSet.asciiLowercaseAlphanumerics.contains(scalar) {
                result.unicodeScalars.append(scalar)
                lastWasDash = false
            } else if !lastWasDash && !result.isEmpty {
                result.append("-")
                lastWasDash = true
            }
        }
        if result.hasSuffix("-") { result.removeLast() }
        return result
    }
}

private extension CharacterSet {
    static let asciiLowercaseAlphanumerics = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789")
}
