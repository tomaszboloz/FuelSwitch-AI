import Foundation
import Testing
@testable import FuelSwitchCore

@Suite struct SecurityToolTests {
    @Test func fullAntigravitySessionFitsTheInteractiveBuffer() throws {
        let json = Data(("{\"payload\":\"" + String(repeating: "x", count: 2200) + "\"}").utf8)
        let login = AntigravitySync.keyringValue(from: json)
        let command = try SecurityTool.writeCommand(service: "gemini", account: "antigravity", data: login)
        #expect(command.count < 4096)
        #expect(String(decoding: command, as: UTF8.self).contains("-w \"go-keyring-base64:"))
    }

    @Test func oversizedCredentialsFailBeforeAKeychainWrite() {
        #expect(throws: SecurityTool.WriteError.self) {
            try SecurityTool.writeCommand(service: "gemini", account: "antigravity", data: Data(repeating: 65, count: 5000))
        }
    }

    @Test func smallCredentialsStayOnStdin() {
        let invocation = SecurityTool.writeInvocation(service: "svc", account: "acct", data: Data("{\"a\":1}".utf8))
        #expect(invocation.arguments == ["-i"])
        #expect(invocation.input != nil)
    }

    @Test func claudeCredentialsWithMCPTokensAreWrittenWhole() {
        // Claude Code stores MCP OAuth tokens beside its own login, which
        // pushes the item well past the interactive 4096-byte line limit.
        let json = "{\"claudeAiOauth\":{\"accessToken\":\"a\"},\"mcpOAuth\":{\"x\":\"" + String(repeating: "m", count: 4500) + "\"}}"
        let invocation = SecurityTool.writeInvocation(service: "Claude Code-credentials", account: "user", data: Data(json.utf8))
        #expect(invocation.input == nil)
        #expect(invocation.arguments == ["add-generic-password", "-U", "-a", "user", "-s", "Claude Code-credentials", "-w", json])
    }

    @Test func oversizedBinaryCredentialsFallBackToHex() {
        let data = Data([0xC5, 0x82] + Array(repeating: UInt8(65), count: 3000))
        let invocation = SecurityTool.writeInvocation(service: "svc", account: "acct", data: data)
        #expect(invocation.input == nil)
        #expect(invocation.arguments.suffix(2).first == "-X")
        #expect(invocation.arguments.last?.hasPrefix("c582") == true)
    }

    @Test func quotesAndBackslashesCannotEscapeThePasswordArgument() throws {
        let data = Data("a\"b\\c".utf8)
        let command = try SecurityTool.writeCommand(service: "service", account: "account", data: data)
        #expect(String(decoding: command, as: UTF8.self).contains("-w \"a\\\"b\\\\c\""))
    }
}
