import AppKit

// Anonymous design renders. Never reads real account names, tokens or settings.
@MainActor
func text(_ value: String, _ size: CGFloat = 13, _ bold: Bool = false) -> NSTextField {
    let view = NSTextField(labelWithString: value)
    view.font = .monospacedDigitSystemFont(ofSize: size, weight: bold ? .semibold : .regular)
    view.textColor = .labelColor
    return view
}

@MainActor
func symbol(_ name: String, warning: Bool = false) -> NSImageView {
    let view = NSImageView(image: NSImage(systemSymbolName: name, accessibilityDescription: name)!)
    view.contentTintColor = warning ? .systemOrange : .secondaryLabelColor
    view.frame.size = NSSize(width: 16, height: 16)
    return view
}

@MainActor
func stack(_ horizontal: Bool, _ spacing: CGFloat = 8) -> NSStackView {
    let view = NSStackView()
    view.orientation = horizontal ? .horizontal : .vertical
    view.alignment = horizontal ? .centerY : .leading
    view.spacing = spacing
    return view
}

@MainActor
func limit(_ title: String, _ value: Double, width: CGFloat) -> NSStackView {
    let group = stack(false, 4)
    let line = stack(true, 6)
    line.addArrangedSubview(text(title, 11))
    line.addArrangedSubview(text("\(Int(value))%", 13, true))
    if value < 20 { line.addArrangedSubview(symbol("fuelpump.fill", warning: true)) }
    group.addArrangedSubview(line)
    let progress = NSProgressIndicator()
    progress.isIndeterminate = false; progress.style = .bar
    progress.minValue = 0; progress.maxValue = 100; progress.doubleValue = value
    progress.widthAnchor.constraint(equalToConstant: width).isActive = true
    group.addArrangedSubview(progress)
    return group
}

@MainActor
func render(compact: Bool, dark: Bool, directory: URL) throws {
    let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
    NSApp.appearance = appearance
    let width: CGFloat = compact ? 900 : 360
    let height: CGFloat = compact ? 56 : 362
    let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.appearance = appearance
    let root = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
    root.wantsLayer = true
    panel.contentView = root
    appearance.performAsCurrentDrawingAppearance {
        root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        root.layer?.cornerRadius = 10
        root.layer?.borderWidth = 1
        root.layer?.borderColor = NSColor.separatorColor.cgColor
    }
    let content = stack(compact, compact ? 14 : 16)
    content.translatesAutoresizingMaskIntoConstraints = false
    root.addSubview(content)
    NSLayoutConstraint.activate([
        content.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
        content.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
        content.topAnchor.constraint(equalTo: root.topAnchor, constant: compact ? 8 : 14)
    ])
    if compact {
        content.addArrangedSubview(symbol("fuelpump.fill", warning: true))
    } else {
        let header = stack(true)
        header.addArrangedSubview(symbol("fuelpump.fill", warning: true))
        header.addArrangedSubview(text("FuelSwitch", 15, true))
        header.addArrangedSubview(text("Pozostały limit", 11))
        content.addArrangedSubview(header)
    }
    for (provider, session, weekly) in [("Claude", 72.0, 18.0), ("Codex", 100.0, 43.0), ("Gemini", 100.0, 43.0)] {
        let group = stack(false, 8)
        if compact {
            let row = stack(true, 8)
            let menu = NSPopUpButton(frame: .zero, pullsDown: false)
            menu.addItems(withTitles: [provider]); menu.bezelStyle = .rounded
            menu.setAccessibilityLabel("\(provider): wybierz konto")
            row.addArrangedSubview(menu)
            row.addArrangedSubview(limit("5 h", session, width: 56))
            row.addArrangedSubview(limit("Tydz.", weekly, width: 64))
            content.addArrangedSubview(row)
        } else {
            let heading = stack(true)
            heading.addArrangedSubview(text(provider, 13, true))
            heading.addArrangedSubview(text("Nazwa konta ukryta", 11))
            group.addArrangedSubview(heading)
            let meters = stack(true, 16)
            meters.addArrangedSubview(limit("5 h", session, width: 148))
            meters.addArrangedSubview(limit("Tydzień", weekly, width: 148))
            group.addArrangedSubview(meters)
            content.addArrangedSubview(group)
        }
    }
    let actions = stack(true, 8)
    for name in [compact ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left", "gearshape", "xmark"] {
        let button = NSButton(image: NSImage(systemSymbolName: name, accessibilityDescription: name)!, target: nil, action: nil)
        button.isBordered = false
        actions.addArrangedSubview(button)
    }
    if !compact { actions.addArrangedSubview(text("Dane demonstracyjne", 11)) }
    content.addArrangedSubview(actions)
    root.layoutSubtreeIfNeeded()
    let name = "widget-\(compact ? "compact-bar" : "expanded")-\(dark ? "dark" : "light").png"
    var output: Data!
    appearance.performAsCurrentDrawingAppearance {
        let image = root.bitmapImageRepForCachingDisplay(in: root.bounds)!
        root.cacheDisplay(in: root.bounds, to: image)
        output = image.representation(using: .png, properties: [:])!
    }
    try output.write(to: directory.appendingPathComponent(name))
}

_ = NSApplication.shared
let destination = URL(fileURLWithPath: CommandLine.arguments[1])
for dark in [false, true] {
    try render(compact: false, dark: dark, directory: destination)
    try render(compact: true, dark: dark, directory: destination)
}
