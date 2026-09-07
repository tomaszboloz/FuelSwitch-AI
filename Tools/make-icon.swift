// Draws the app icon and writes an .icns next to the Info.plist.
//
// The icon is a fuel gauge at ~18% fill (low-fuel warning zone) with an
// amber/orange outline on a dark navy canvas. That nearly-empty gauge is the
// whole point of the app: helping you never run dry.
//
//     swift Tools/make-icon.swift Resources/AppIcon.icns
import AppKit

let side: CGFloat = 1024
let bodyInset: CGFloat = 100
let bodyRadius: CGFloat = 185

// FuelSwitch AI brand amber/orange: #F59E0B
let amberColor = NSColor(srgbRed: 0.96, green: 0.62, blue: 0.07, alpha: 1.0)

func drawIcon(into size: CGFloat) -> NSImage {
    let scale = size / side
    let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
        guard let context = NSGraphicsContext.current?.cgContext else { return false }
        context.scaleBy(x: scale, y: scale)

        let body = NSRect(x: bodyInset, y: bodyInset,
                          width: side - 2 * bodyInset, height: side - 2 * bodyInset)
        let bodyPath = NSBezierPath(roundedRect: body, xRadius: bodyRadius, yRadius: bodyRadius)

        // Deep dark navy background
        NSGraphicsContext.saveGraphicsState()
        bodyPath.setClip()
        let background = NSGradient(
            starting: NSColor(srgbRed: 0.06, green: 0.07, blue: 0.10, alpha: 1),
            ending:   NSColor(srgbRed: 0.03, green: 0.04, blue: 0.07, alpha: 1)
        )!
        background.draw(in: body, angle: -90)

        // Subtle amber radial glow at centre-bottom (fuel hotspot)
        let glowCenter = CGPoint(x: side / 2, y: bodyInset + (side - 2 * bodyInset) * 0.22)
        let glowRadius: CGFloat = 300
        let radialGrad = NSGradient(
            colors: [
                amberColor.withAlphaComponent(0.20),
                NSColor.clear
            ],
            atLocations: [0, 1],
            colorSpace: .sRGB
        )!
        radialGrad.draw(fromCenter: glowCenter, radius: 0,
                        toCenter: glowCenter, radius: glowRadius, options: [])
        NSGraphicsContext.restoreGraphicsState()

        // Gauge outline (keeps the menu bar glyph 13:16 proportion)
        let gauge  = NSRect(x: 317, y: 212, width: 390, height: 540)
        let gaugeR : CGFloat = 120
        let stroke : CGFloat = 40

        let outline = NSBezierPath(roundedRect: gauge, xRadius: gaugeR, yRadius: gaugeR)
        outline.lineWidth = stroke
        amberColor.withAlphaComponent(0.90).setStroke()
        outline.stroke()

        // Inner fill — ~18% level (amber warning zone)
        let inner  = gauge.insetBy(dx: stroke, dy: stroke)
        let innerR = gaugeR - stroke
        let level: CGFloat = 0.18

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: inner, xRadius: innerR, yRadius: innerR).setClip()

        let fillRect = NSRect(x: inner.minX, y: inner.minY,
                              width: inner.width, height: inner.height * level)
        let fillGrad = NSGradient(
            starting: NSColor(srgbRed: 0.96, green: 0.62, blue: 0.07, alpha: 1.0),
            ending:   NSColor(srgbRed: 0.80, green: 0.45, blue: 0.02, alpha: 1.0)
        )!
        fillGrad.draw(in: fillRect, angle: 90)

        let emptyRect = NSRect(x: inner.minX,
                               y: inner.minY + inner.height * level,
                               width: inner.width,
                               height: inner.height * (1 - level))
        amberColor.withAlphaComponent(0.05).setFill()
        NSBezierPath(rect: emptyRect).fill()
        NSGraphicsContext.restoreGraphicsState()

        // Nozzle cap at top of gauge
        let nozzleW: CGFloat = 110
        let nozzleH: CGFloat = 28
        let nozzlePath = NSBezierPath(
            roundedRect: NSRect(x: gauge.midX - nozzleW / 2,
                                y: gauge.maxY - stroke / 2,
                                width: nozzleW, height: nozzleH),
            xRadius: 14, yRadius: 14
        )
        amberColor.setFill()
        nozzlePath.fill()

        return true
    }
    return image
}

func png(_ image: NSImage, _ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    drawIcon(into: CGFloat(pixels)).draw(
        in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let output = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Resources/AppIcon.icns"
let iconset = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("FuelSwitch-\(UUID().uuidString).iconset")
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for (point, scale) in [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)] {
    let name = scale == 1
        ? "icon_\(point)x\(point).png"
        : "icon_\(point)x\(point)@2x.png"
    try! png(NSImage(), point * scale)
        .write(to: iconset.appendingPathComponent(name))
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", output]
try! task.run()
task.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
print(task.terminationStatus == 0 ? "wrote \(output)" : "iconutil failed")
