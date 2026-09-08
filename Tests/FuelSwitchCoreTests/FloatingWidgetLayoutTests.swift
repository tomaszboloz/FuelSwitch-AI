import Foundation
import Testing
@testable import FuelSwitchCore

struct FloatingWidgetLayoutTests {
    @Test func compactBoundsAreNarrowAndShort() {
        let bounds = FloatingWidgetLayout.bounds(forCompact: true)
        #expect(bounds == FloatingWidgetLayout.compactBounds)
        #expect(bounds.minSize.height < bounds.maxSize.height)
    }

    @Test func expandedBoundsAreTallerAndAllowMuchMoreHeight() {
        let bounds = FloatingWidgetLayout.bounds(forCompact: false)
        #expect(bounds == FloatingWidgetLayout.expandedBounds)
        #expect(bounds.maxSize.height == 900)
    }

    @Test func aSavedCompactFrameWithinBoundsIsValid() {
        let rect = CGRect(x: 0, y: 0, width: 700, height: 50)
        #expect(FloatingWidgetLayout.isValidSavedFrame(rect, isCompact: true))
    }

    @Test func aSavedCompactFrameTooShortInWidthIsInvalid() {
        let rect = CGRect(x: 0, y: 0, width: 400, height: 50)
        #expect(!FloatingWidgetLayout.isValidSavedFrame(rect, isCompact: true))
    }

    @Test func aSavedCompactFrameTooTallExceedsTheCompactMaxAndIsInvalid() {
        let rect = CGRect(x: 0, y: 0, width: 700, height: 200)
        #expect(!FloatingWidgetLayout.isValidSavedFrame(rect, isCompact: true))
    }

    @Test func aSavedExpandedFrameHasNoUpperHeightLimit() {
        let rect = CGRect(x: 0, y: 0, width: 300, height: 850)
        #expect(FloatingWidgetLayout.isValidSavedFrame(rect, isCompact: false))
    }

    @Test func aSavedExpandedFrameTooSmallIsInvalid() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
        #expect(!FloatingWidgetLayout.isValidSavedFrame(rect, isCompact: false))
    }

    @Test func targetFrameFallsBackToDefaultsWithNoSavedFrame() {
        let current = CGRect(x: 10, y: 100, width: 340, height: 320)
        let target = FloatingWidgetLayout.targetFrame(currentFrame: current, switchingToCompact: true, savedFrame: nil)
        #expect(target.width == 660)
        #expect(target.height == 46)
        #expect(target.minX == current.minX)
        #expect(target.maxY == current.maxY)
    }

    @Test func targetFrameWidensToFitAWiderCurrentFrameWhenNoSavedFrame() {
        let current = CGRect(x: 10, y: 100, width: 800, height: 320)
        let target = FloatingWidgetLayout.targetFrame(currentFrame: current, switchingToCompact: true, savedFrame: nil)
        #expect(target.width == 800)
    }

    @Test func targetFrameRestoresAValidSavedFrameInsteadOfTheDefault() {
        let current = CGRect(x: 10, y: 100, width: 340, height: 320)
        let saved = CGRect(x: 0, y: 0, width: 720, height: 60)
        let target = FloatingWidgetLayout.targetFrame(currentFrame: current, switchingToCompact: true, savedFrame: saved)
        #expect(target.width == 720)
        #expect(target.height == 60)
        #expect(target.maxY == current.maxY)
    }

    @Test func targetFrameIgnoresAnInvalidSavedFrameAndUsesTheDefault() {
        let current = CGRect(x: 10, y: 100, width: 340, height: 320)
        let staleSaved = CGRect(x: 0, y: 0, width: 100, height: 20)
        let target = FloatingWidgetLayout.targetFrame(currentFrame: current, switchingToCompact: true, savedFrame: staleSaved)
        #expect(target.width == 660)
        #expect(target.height == 46)
    }

    @Test func initialFrameUsesTheCompactDefaultWithNoSavedFrame() {
        let frame = FloatingWidgetLayout.initialFrame(isCompact: true, savedFrame: nil)
        #expect(frame == CGRect(x: 120, y: 150, width: 660, height: 46))
    }

    @Test func initialFrameUsesTheExpandedDefaultWithNoSavedFrame() {
        let frame = FloatingWidgetLayout.initialFrame(isCompact: false, savedFrame: nil)
        #expect(frame == CGRect(x: 120, y: 150, width: 340, height: 340))
    }

    @Test func initialFrameRestoresAValidSavedFrame() {
        let saved = CGRect(x: 5, y: 5, width: 700, height: 60)
        let frame = FloatingWidgetLayout.initialFrame(isCompact: true, savedFrame: saved)
        #expect(frame == saved)
    }
}
