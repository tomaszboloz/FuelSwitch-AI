import Testing
import Foundation
@testable import FuelSwitchCore

// MARK: - Guarding the tests against hanging

/// An internal race: whoever reports a result first wins, and the second report
/// is simply ignored (no double `resume`, which would crash the process).
///
/// The result is buffered (`result`), exactly as in `CallbackListener.finish`:
/// both sides (`work` and the timeout) start as unstructured `Task {}` BEFORE
/// anyone gets to call `wait()`. If `report` simply discarded the result when no
/// continuation was registered (as an earlier version of this file did), the
/// winner of the race — reaching the line before `wait()` even ran — lost its
/// result for good, and `wait()` then registered a continuation nobody was left
/// to resume, so the timeout always won. That produced exactly the bimodal
/// distribution observed (0.4 s or the full time limit, nothing in between) and
/// had nothing to do with the length of the limit itself.
private actor Race<T: Sendable> {
    private var result: Result<T, Error>?
    private var continuation: CheckedContinuation<T, Error>?

    func wait() async throws -> T {
        if let result { return try result.get() }
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }

    func report(_ value: Result<T, Error>) {
        guard result == nil else { return }
        result = value
        if let continuation {
            self.continuation = nil
            continuation.resume(with: value)
        }
    }
}

private struct TimedOut: Error {}

/// The tests' own timeout. `.timeLimit` from the Testing library is NOT enough
/// here: its granularity is minutes, and beyond that — verified experimentally
/// before this file was written — it cannot interrupt a suspended
/// `CheckedContinuation` at all. The test framework then waits exactly as
/// `async let` or a `TaskGroup` would, because that is structured concurrency:
/// the parent task still has to wait for the child to finish, even a "cancelled"
/// one. So the race is run by hand on UNSTRUCTURED tasks (`Task { }`) — the
/// losing task is simply abandoned in the background instead of blocking the
/// return from this function, so a broken implementation ends in a legible test
/// failure rather than a hung suite.
///
/// The 10 s is only a hang guard, not an assertion about response time — a real
/// listener answers in a fraction of a second, while a 3 s threshold was
/// sometimes chased down by ordinary load on the test machine (parallel network
/// requests in other tests), which produced sporadic false failures. Raising it
/// weakens no assertion in this file: we still check the exact code and state,
/// just with more margin before declaring a task hung.
private func withTimeout<T: Sendable>(
    _ seconds: Double = 10,
    _ work: @escaping @Sendable () async throws -> T
) async throws -> T {
    let race = Race<T>()
    Task {
        do {
            let value = try await work()
            await race.report(.success(value))
        } catch {
            await race.report(.failure(error))
        }
    }
    Task {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        await race.report(.failure(TimedOut()))
    }
    return try await race.wait()
}

// MARK: - Tests
//
// These tests are deliberately not nested under `NetworkTests` (see
// UsageClientTests.swift). That shared `.serialized` parent exists solely to
// protect `MockProtocol`'s static, target-wide state — which these tests never
// touch. Each test here binds its own, independently allocated port (port 0 →
// a free port from the system), exactly as `AccountStoreTests` uses its own
// unique temporary directory per test rather than shared state. The
// port-in-use test is self-contained: it tries to rebind precisely the port it
// allocated for itself and still holds open in the same test function, so it
// does not depend on what other tests are doing elsewhere in parallel.

@Test func receivesTheCodeFromTheRedirect() async throws {
    let listener = CallbackListener(port: 0)
    let port = try listener.start(expectedState: "abc", expectedPath: "/callback")
    defer { listener.stop() }

    let waiting = Task { try await listener.waitForCode() }

    let url = URL(string: "http://127.0.0.1:\(port)/callback?code=XYZ123&state=abc")!
    _ = try await URLSession.shared.data(from: url)

    let code = try await withTimeout { try await waiting.value }
    #expect(code == "XYZ123")
}

@Test func rejectsAMismatchedState() async throws {
    let listener = CallbackListener(port: 0)
    let port = try listener.start(expectedState: "expected", expectedPath: "/callback")
    defer { listener.stop() }

    let waiting = Task { try await listener.waitForCode() }
    let url = URL(string: "http://127.0.0.1:\(port)/callback?code=X&state=impostor")!
    _ = try? await URLSession.shared.data(from: url)

    await #expect(throws: OAuthError.stateMismatch) {
        _ = try await withTimeout { try await waiting.value }
    }
}

@Test func anOccupiedPortGivesALegibleError() throws {
    let first = CallbackListener(port: 0)
    let port = try first.start(expectedState: "x", expectedPath: "/callback")
    defer { first.stop() }

    let second = CallbackListener(port: port)
    #expect(throws: OAuthError.portInUse(port)) { _ = try second.start(expectedState: "y", expectedPath: "/callback") }
}

// The result arrives before anyone calls `waitForCode()` — unlike
// `receivesTheCodeFromTheRedirect` (where the order is merely a matter of
// `Task { }` timing against a network request), here the request is fully
// complete (`await`) BEFORE the first call to `waitForCode()`. That forces the
// buffer path (`State.resultReady`) by construction rather than by luck in task
// scheduling.
@Test func buffersTheResultAheadOfWaitForCode() async throws {
    let listener = CallbackListener(port: 0)
    let port = try listener.start(expectedState: "buffer", expectedPath: "/callback")
    defer { listener.stop() }

    let url = URL(string: "http://127.0.0.1:\(port)/callback?code=BUFFER123&state=buffer")!
    _ = try await URLSession.shared.data(from: url)

    let code = try await withTimeout { try await listener.waitForCode() }
    #expect(code == "BUFFER123")
}

// Two complete requests reach the same listener, one after the other, both
// before anyone calls `waitForCode()`. The first finalises the state; the second
// has to be silently ignored (see `State.finished` in `finish`) rather than
// crashing the process with a second `resume` of the same continuation or
// overwriting the already buffered result.
@Test func aSecondReportDoesNotOverwriteTheResult() async throws {
    let listener = CallbackListener(port: 0)
    let port = try listener.start(expectedState: "race", expectedPath: "/callback")
    defer { listener.stop() }

    let firstURL = URL(string: "http://127.0.0.1:\(port)/callback?code=FIRST&state=race")!
    let secondURL = URL(string: "http://127.0.0.1:\(port)/callback?code=SECOND&state=race")!

    _ = try await URLSession.shared.data(from: firstURL)
    _ = try? await URLSession.shared.data(from: secondURL)

    let code = try await withTimeout { try await listener.waitForCode() }
    #expect(code == "FIRST")
}
