import Sparkle

/// Thin AppKit-adjacent glue around Sparkle's updater, matching the project's
/// convention of keeping framework wiring untested and out of FuelSwitchCore.
/// `UpdateChecker` (FuelSwitchCore) stays the always-on, side-effect-free "is
/// there a newer release" check used by the manual button in Settings; this
/// class owns the opt-in, unattended background check-and-install path that
/// Sparkle itself downloads, verifies (EdDSA), and installs.
@MainActor
final class SparkleUpdateManager {
    let controller: SPUStandardUpdaterController

    /// Background checks are off until the user opts in from Settings — no
    /// feature in this app ships as always-on with no switch to turn it off.
    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    /// Only meaningful once background checks are on; downloading and
    /// installing unattended is the riskier half, so it is its own switch.
    var automaticallyDownloadsUpdates: Bool {
        get { controller.updater.automaticallyDownloadsUpdates }
        set { controller.updater.automaticallyDownloadsUpdates = newValue }
    }

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
