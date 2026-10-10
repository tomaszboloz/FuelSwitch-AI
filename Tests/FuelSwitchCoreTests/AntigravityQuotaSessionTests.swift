import Testing
import Foundation
@testable import FuelSwitchCore

@Suite struct AntigravityQuotaSessionTests {
    @Test func accessTokenThrowsForNonexistentEmail() async {
        let session = URLSession.shared
        await #expect(throws: UsageError.unavailableQuota) {
            _ = try await AntigravityQuotaSession.shared.accessToken(
                email: "nonexistent.user.\(UUID().uuidString)@example.com",
                session: session
            )
        }
    }

    @Test func accessTokenReadsValidSnapshotWithoutNetwork() async throws {
        let testEmail = "snapshot.test.\(UUID().uuidString)@example.com"
        let dir = AntigravitySync.snapshotDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let snapshotURL = AntigravitySync.snapshotURL(for: testEmail, in: dir)
        defer { try? FileManager.default.removeItem(at: snapshotURL) }

        let jwtPayload = "{\"email\":\"\(testEmail)\"}".data(using: .utf8)!.base64EncodedString()
        let fakeJWT = "eyJhbGciOiJub25lIn0.\(jwtPayload).sig"

        let dict: [String: Any] = [
            "id_token": fakeJWT,
            "token": [
                "access_token": "cached-session-token",
                "expiry": "2099-01-01T00:00:00Z"
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: dict)
        try data.write(to: snapshotURL)

        let token = try await AntigravityQuotaSession.shared.accessToken(
            email: testEmail,
            session: URLSession.shared
        )
        #expect(token == "cached-session-token")
    }
}
