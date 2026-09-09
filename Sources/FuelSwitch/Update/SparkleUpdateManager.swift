import Sparkle

/// Thin AppKit-adjacent glue around Sparkle's updater, matching the project's
/// convention of keeping framework wiring untested and out of FuelSwitchCore.
/// `UpdateChecker` (FuelSwitchCore) reads the same feed for in-app status; this
/// class owns both manual installation and the opt-in background path that
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
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    /// Start only after the saved check/download preferences have been applied.
    func start() {
        controller.startUpdater()
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
