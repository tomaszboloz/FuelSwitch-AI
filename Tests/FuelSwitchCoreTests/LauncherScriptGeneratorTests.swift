import Testing
import Foundation
@testable import FuelSwitchCore

private func account(email: String, nickname: String? = nil, provider: Provider = .anthropic) -> Account {
    Account(provider: provider, email: email, accessToken: "tok", refreshToken: "ref", nickname: nickname)
}

@Suite struct LauncherScriptGeneratorTests {
    @Test func anEmptyAccountListProducesAnEmptyScript() {
        #expect(LauncherScriptGenerator.shellFunction(accounts: []).isEmpty)
    }

    @Test func oneFunctionPerAccountNamedAfterItsNickname() {
        let script = LauncherScriptGenerator.shellFunction(accounts: [
            account(email: "a@b.com", nickname: "Work"),
            account(email: "c@d.com", nickname: "Personal")
        ])

        #expect(script.contains("fs-work() {"))
        #expect(script.contains("fs-personal() {"))
    }

    @Test func fallsBackToASanitizedEmailWhenThereIsNoNickname() {
        let script = LauncherScriptGenerator.shellFunction(accounts: [
            account(email: "Jane.Doe+work@example.com")
        ])

        #expect(script.contains("fs-jane-doe-work-example-com() {"))
    }

    @Test func eachFunctionOpensTheSwitchURLWithThatAccountsIdentifier() {
        let script = LauncherScriptGenerator.shellFunction(accounts: [
            account(email: "a@b.com", nickname: "Work", provider: .openai)
        ])

        #expect(script.contains("open \"fuelswitch://switch?id=openai:a@b.com\""))
    }

    @Test func duplicateNicknamesGetDistinctFunctionNames() {
        let script = LauncherScriptGenerator.shellFunction(accounts: [
            account(email: "a@b.com", nickname: "Work"),
            account(email: "c@d.com", nickname: "Work")
        ])

        #expect(script.contains("fs-work() {"))
        #expect(script.contains("fs-work-2() {"))
    }

    @Test func theOutputIsSyntacticallyBalanced() {
        let script = LauncherScriptGenerator.shellFunction(accounts: [
            account(email: "a@b.com", nickname: "Work"),
            account(email: "c@d.com")
        ])

        #expect(script.filter { $0 == "{" }.count == script.filter { $0 == "}" }.count)
        #expect(script.filter { $0 == "{" }.count == 2)
    }
}
