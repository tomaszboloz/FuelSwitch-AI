import Testing
import Foundation
@testable import FuelSwitchCore

@Suite struct StatuslineScriptGeneratorTests {
    @Test func theScriptReferencesAllThreeProviderCacheFiles() {
        let directory = URL(fileURLWithPath: "/tmp/fuelswitch-statusline-test")
        let script = StatuslineScriptGenerator.script(cacheDirectory: directory)
        for provider in Provider.allCases {
            #expect(script.contains(StatuslineCache.defaultFileURL(for: provider, in: directory).path))
        }
    }

    @Test func theScriptStartsWithAShebang() {
        let script = StatuslineScriptGenerator.script(cacheDirectory: URL(fileURLWithPath: "/tmp"))
        #expect(script.hasPrefix("#!/bin/sh"))
    }

    @Test func theScriptHasBalancedIfFiBlocks() {
        let script = StatuslineScriptGenerator.script(cacheDirectory: URL(fileURLWithPath: "/tmp"))
        let ifCount = script.components(separatedBy: "if [").count - 1
        let fiCount = script.components(separatedBy: "\nfi").count - 1
        #expect(ifCount == fiCount)
    }
}
