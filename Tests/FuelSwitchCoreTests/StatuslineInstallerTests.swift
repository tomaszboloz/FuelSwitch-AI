import Testing
import Foundation
@testable import FuelSwitchCore

@Suite struct StatuslineInstallerTests {
    private func makeInstaller() -> (StatuslineInstaller, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("statusline-installer-tests-\(UUID().uuidString)")
        let installer = StatuslineInstaller(
            settingsURL: root.appendingPathComponent("settings.json"),
            scriptURL: root.appendingPathComponent("fuelswitch-statusline.sh")
        )
        return (installer, root)
    }

    @Test func isNotInstalledWhenSettingsFileDoesNotExist() throws {
        let (installer, root) = makeInstaller()
        #expect(installer.isInstalled == false)
        try? FileManager.default.removeItem(at: root)
    }

    @Test func installWritesTheScriptAndPointsStatusLineAtIt() throws {
        let (installer, root) = makeInstaller()
        try installer.install()
        #expect(installer.isInstalled)
        #expect(FileManager.default.fileExists(atPath: installer.scriptURL.path))
        try? FileManager.default.removeItem(at: root)
    }

    @Test func installPreservesUnrelatedExistingSettingsKeys() throws {
        let (installer, root) = makeInstaller()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let existing = try JSONSerialization.data(withJSONObject: ["someOtherKey": "keepMe"])
        try existing.write(to: installer.settingsURL)

        try installer.install()

        let data = try Data(contentsOf: installer.settingsURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["someOtherKey"] as? String == "keepMe")
        #expect((json?["statusLine"] as? [String: Any])?["command"] as? String == installer.scriptURL.path)
        try? FileManager.default.removeItem(at: root)
    }

    @Test func uninstallRemovesOurStatusLineAndScript() throws {
        let (installer, root) = makeInstaller()
        try installer.install()
        try installer.uninstall()
        #expect(installer.isInstalled == false)
        #expect(!FileManager.default.fileExists(atPath: installer.scriptURL.path))
        try? FileManager.default.removeItem(at: root)
    }

    @Test func uninstallDoesNotTouchAStatusLineTheUserPointedAtSomethingElse() throws {
        let (installer, root) = makeInstaller()
        try installer.install()

        var settings = try JSONSerialization.jsonObject(with: Data(contentsOf: installer.settingsURL)) as! [String: Any]
        settings["statusLine"] = ["type": "command", "command": "/usr/bin/some-other-script.sh"]
        try JSONSerialization.data(withJSONObject: settings).write(to: installer.settingsURL)

        try installer.uninstall()

        let data = try Data(contentsOf: installer.settingsURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect((json?["statusLine"] as? [String: Any])?["command"] as? String == "/usr/bin/some-other-script.sh")
        try? FileManager.default.removeItem(at: root)
    }
}
