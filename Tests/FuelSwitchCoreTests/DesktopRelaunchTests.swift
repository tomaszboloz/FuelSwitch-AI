import Testing
@testable import FuelSwitchCore

@Suite @MainActor struct DesktopRelaunchTests {
    @Test func waitsForStartupBeforeRequestingTheWindow() async throws {
        var ready = false
        var events: [String] = []
        try await CodexDesktopSync.finishLaunching(
            isReady: { ready }, isTerminated: { false },
            reopen: { events.append("reopen") },
            activate: { events.append("activate"); return true },
            attempts: 2,
            pause: { events.append("startup"); ready = true }
        )
        #expect(events == ["startup", "reopen", "activate"])
    }

    @Test func alreadyStartedBackgroundAppStillReceivesReopen() async throws {
        var reopened = false
        try await CodexDesktopSync.finishLaunching(
            isReady: { true }, isTerminated: { false },
            reopen: { reopened = true }, activate: { true }, pause: {}
        )
        #expect(reopened)
    }

    @Test func failedStartupDoesNotClaimSuccessfulRelaunch() async throws {
        var reopened = false
        await #expect(throws: CodexDesktopSync.SyncError.launchTimedOut) {
            try await CodexDesktopSync.finishLaunching(
                isReady: { false }, isTerminated: { false },
                reopen: { reopened = true }, activate: { true }, attempts: 2, pause: {}
            )
        }
        #expect(!reopened)
        await #expect(throws: CodexDesktopSync.SyncError.applicationNotFound) {
            try await CodexDesktopSync.finishLaunching(
                isReady: { true }, isTerminated: { true },
                reopen: { reopened = true }, activate: { true }, pause: {}
            )
        }
        #expect(!reopened)
    }

    @Test func reopenFailureIsReportedAndDoesNotActivate() async throws {
        var activated = false
        await #expect(throws: CodexDesktopSync.SyncError.applicationNotFound) {
            try await CodexDesktopSync.finishLaunching(
                isReady: { true }, isTerminated: { false },
                reopen: { throw CodexDesktopSync.SyncError.applicationNotFound },
                activate: { activated = true; return true }, pause: {}
            )
        }
        #expect(!activated)
    }
}
