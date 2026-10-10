import AppKit
import Testing
import FuelSwitchCore
@testable import FuelSwitch

@MainActor
@Suite struct MenuBarIconRendererTests {
    @Test func rendersGaugesAndBatteriesDirectly() {
        let image = NSImage(size: NSSize(width: 50, height: 50))
        image.lockFocus()

        let rect = NSRect(x: 5, y: 5, width: 40, height: 40)
        // High fuel
        MenuBarIconRenderer.drawGauge(fill: 85, in: rect, monochrome: false)
        MenuBarIconRenderer.drawBattery(fill: 85, in: rect)

        // Low fuel / reserve
        MenuBarIconRenderer.drawGauge(fill: 10, in: rect, monochrome: false)
        MenuBarIconRenderer.drawBattery(fill: 10, in: rect)

        // Monochrome
        MenuBarIconRenderer.drawGauge(fill: 50, in: rect, monochrome: true)

        // Zero / nil fill
        MenuBarIconRenderer.drawGauge(fill: 0, in: rect, monochrome: false)
        MenuBarIconRenderer.drawGauge(fill: nil, in: rect, monochrome: false)
        MenuBarIconRenderer.drawBattery(fill: 0, in: rect)
        MenuBarIconRenderer.drawBattery(fill: nil, in: rect)

        image.unlockFocus()
        #expect(image.size.width == 50)
    }

    @Test func rendersMenuBarIconImagesForAllStyles() {
        let reading = MenuBarReading(provider: .anthropic, fill: 75, text: "75%")

        for style in MenuBarIconStyle.allCases {
            let imgWithPercent = MenuBarIcon.image(readings: [reading], showsPercent: true, iconStyle: style)
            #expect(imgWithPercent.size.width > 0)
            #expect(imgWithPercent.size.height > 0)

            let imgWithoutPercent = MenuBarIcon.image(readings: [reading], showsPercent: false, iconStyle: style)
            #expect(imgWithoutPercent.size.width > 0)
            #expect(imgWithoutPercent.size.height > 0)
        }
    }

    @Test func rendersMenuBarIconWithEmptyReadings() {
        let img = MenuBarIcon.image(readings: [], showsPercent: false, iconStyle: .gauge)
        #expect(img.size.width > 0)
        #expect(img.size.height > 0)
    }
}
