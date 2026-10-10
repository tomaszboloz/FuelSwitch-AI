import Testing
import Foundation
@testable import FuelSwitchCore

@Suite struct AntigravityLanguageServerTests {
    @Test func isStandaloneAppIdentifiesAppBundle() {
        let appServer = AntigravityLanguageServer(
            pid: 1001,
            command: "/Applications/Antigravity.app/Contents/Resources/bin/language_server --csrf_token tok",
            csrfToken: "tok"
        )
        #expect(appServer.isStandaloneApp == true)

        let pluginServer = AntigravityLanguageServer(
            pid: 1002,
            command: "/Users/user/.vscode/extensions/google.gemini/language_server --csrf_token tok",
            csrfToken: "tok"
        )
        #expect(pluginServer.isStandaloneApp == false)
    }

    @Test func runningLanguageServersReturnsArray() {
        let servers = AntigravityLanguageServer.running()
        // Must succeed without crashing regardless of whether Antigravity is running
        #expect(servers.count >= 0)
    }

    @Test func portsReturnsArray() {
        let server = AntigravityLanguageServer(pid: 999999, command: "language_server --csrf_token x", csrfToken: "x")
        let p = server.ports()
        #expect(p.isEmpty)
    }

    @Test func callReturnsNilForUnreachablePort() async {
        let server = AntigravityLanguageServer(pid: 999999, command: "language_server --csrf_token x", csrfToken: "x")
        let data = await server.call("GetUserStatus")
        #expect(data == nil)
    }

    @Test func signedInEmailReturnsNilWhenCallFails() async {
        let server = AntigravityLanguageServer(pid: 999999, command: "language_server --csrf_token x", csrfToken: "x")
        let email = await server.signedInEmail()
        #expect(email == nil)
    }
}
