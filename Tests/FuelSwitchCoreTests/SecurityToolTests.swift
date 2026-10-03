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

    @Test func quotesAndBackslashesCannotEscapeThePasswordArgument() throws {
        let data = Data("a\"b\\c".utf8)
        let command = try SecurityTool.writeCommand(service: "service", account: "account", data: data)
        #expect(String(decoding: command, as: UTF8.self).contains("-w \"a\\\"b\\\\c\""))
    }
}
