import AppKit
import Testing
@testable import FuelSwitch

@MainActor
struct WidgetDragTests {
    @Test func dragSurfaceAcceptsFirstMouseInNonactivatingWidgetPanel() {
        let surface = WidgetDragSurface(frame: CGRect(x: 0, y: 0, width: 300, height: 80))

        #expect(surface.acceptsFirstMouse(for: nil))
    }
}
