import AppKit

// Isolated design prototype. No network, OAuth, Keychain or production settings.
// Run with --export to render native controls; otherwise opens an interactive window.
@MainActor
final class Preview: NSObject, NSApplicationDelegate, NSToolbarDelegate, NSTableViewDataSource, NSTableViewDelegate {
    var window: NSWindow!
    var split: NSSplitView!
    var table: NSTableView!
    var status: NSTextField!
    let rows: [(String, String, String, String)] = [
        ("Codex", "Nazwa konta ukryta", "100%", "43%"),
        ("Claude", "Nazwa konta ukryta", "72%", "18%"),
        ("Gemini", "Nazwa konta ukryta", "100%", "43%")
    ]
    func label(_ text: String, size: CGFloat = 13, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.lineBreakMode = .byTruncatingTail
        return label
    }
    func button(_ title: String, _ action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        return b
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let menu = NSMenu()
        let appItem = NSMenuItem(); menu.addItem(appItem)
        let appMenu = NSMenu(title: "FuelSwitch AI"); appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Zakończ podgląd", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let viewItem = NSMenuItem(); menu.addItem(viewItem)
        let viewMenu = NSMenu(title: "Widok"); viewItem.submenu = viewMenu
        let refresh = viewMenu.addItem(withTitle: "Odśwież podgląd", action: #selector(refreshData), keyEquivalent: "r"); refresh.target = self
        NSApp.mainMenu = menu
        build()
        if CommandLine.arguments.contains("--export") {
            export()
            NSApp.terminate(nil)
        } else {
            window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        }
    }
    func build() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "FuelSwitch AI"
        window.subtitle = "Konta i limity"
        window.contentMinSize = NSSize(width: 800, height: 600)
        window.collectionBehavior = [.fullScreenPrimary]
        let toolbar = NSToolbar(identifier: "NativePreview")
        toolbar.delegate = self; toolbar.displayMode = .iconOnly
        window.toolbar = toolbar; window.toolbarStyle = .unified
        let container = NSView(); window.contentView = container
        split = NSSplitView(); split.isVertical = true; split.dividerStyle = .thin
        split.translatesAutoresizingMaskIntoConstraints = false; container.addSubview(split)
        NSLayoutConstraint.activate([
            split.leadingAnchor.constraint(equalTo: container.leadingAnchor), split.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            split.topAnchor.constraint(equalTo: container.topAnchor), split.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        let sidebar = NSVisualEffectView(); sidebar.material = .sidebar; sidebar.blendingMode = .behindWindow
        sidebar.state = .active
        let nav = NSStackView(); nav.orientation = .vertical; nav.alignment = .leading; nav.spacing = 8
        nav.translatesAutoresizingMaskIntoConstraints = false; sidebar.addSubview(nav)
        nav.addArrangedSubview(label("BIBLIOTEKA", size: 11, weight: .semibold, color: .secondaryLabelColor))
        for (title, symbol) in [("Wszystkie konta", "square.stack"), ("Codex", "terminal"), ("Claude", "text.bubble"), ("Gemini", "sparkles")] {
            let b = button(title, #selector(selectSection(_:)))
            b.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
            b.imagePosition = .imageLeading
            b.alignment = .left
            b.isBordered = false
            b.setAccessibilityLabel(title)
            nav.addArrangedSubview(b)
            b.widthAnchor.constraint(equalTo: nav.widthAnchor).isActive = true
        }
        nav.addArrangedSubview(NSView())
        nav.addArrangedSubview(label("NARZĘDZIA", size: 11, weight: .semibold, color: .secondaryLabelColor))
        nav.addArrangedSubview(button("Historia użycia", #selector(demoAction)))
        nav.addArrangedSubview(button("Automatyzacja", #selector(demoAction)))
        NSLayoutConstraint.activate([nav.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 16),
                                     nav.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -16),
                                     nav.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 24)])
        split.addArrangedSubview(sidebar)
        let content = NSView(); split.addArrangedSubview(content)
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24), stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20)])
        stack.addArrangedSubview(label("Konta i limity", size: 26, weight: .semibold))
        stack.addArrangedSubview(label("Sprawdź pozostały limit. Przełącz konto, kiedy go potrzebujesz.", color: .secondaryLabelColor))
        let summary = NSStackView(); summary.orientation = .horizontal; summary.spacing = 32
        for (value, caption) in [("3", "Aktywne konta"), ("1", "Niski limit tygodniowy"), ("Wyłączona", "Automatyczna zmiana konta")] {
            let group = NSStackView(); group.orientation = .vertical; group.alignment = .leading; group.spacing = 4
            group.addArrangedSubview(label(value, size: 22, weight: .semibold))
            group.addArrangedSubview(label(caption, size: 11, color: .secondaryLabelColor))
            summary.addArrangedSubview(group)
        }
        stack.addArrangedSubview(summary)
        let explanation = NSStackView(); explanation.orientation = .horizontal; explanation.spacing = 8
        let fuel = NSImageView(image: NSImage(systemSymbolName: "fuelpump.fill", accessibilityDescription: "Niski limit")!)
        fuel.contentTintColor = .systemOrange
        explanation.addArrangedSubview(fuel)
        explanation.addArrangedSubview(label("Claude: pozostało 18% limitu tygodniowego.", color: .secondaryLabelColor))
        stack.addArrangedSubview(explanation)
        let filter = NSSegmentedControl(labels: ["Wszystkie", "Aktywne"], trackingMode: .selectOne, target: self, action: #selector(demoAction))
        filter.segmentStyle = .smallSquare
        filter.selectedSegment = 0
        stack.addArrangedSubview(filter)
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        table = NSTableView(); table.usesAlternatingRowBackgroundColors = true; table.rowHeight = 64
        table.style = .fullWidth; table.dataSource = self; table.delegate = self
        for (id, title, width) in [("provider", "Dostawca / konto", 300.0), ("session", "Pozostało · 5 h", 180.0), ("week", "Pozostało · tydzień", 180.0), ("state", "Stan", 100.0)] {
            let col = NSTableColumn(identifier: .init(id)); col.title = title; col.width = width; col.minWidth = id == "provider" ? 160 : 100
            table.addTableColumn(col)
        }
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        let context = NSMenu(); let details = context.addItem(withTitle: "Pokaż szczegóły", action: #selector(demoAction), keyEquivalent: ""); details.target = self
        let switchItem = context.addItem(withTitle: "Przełącz konto…", action: #selector(demoAction), keyEquivalent: ""); switchItem.target = self
        table.menu = context
        scroll.documentView = table
        stack.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 210).isActive = true
        let detail = NSStackView(); detail.orientation = .horizontal; detail.spacing = 12
        detail.addArrangedSubview(label("Codex", weight: .semibold))
        detail.addArrangedSubview(label("Nazwa konta ukryta", color: .secondaryLabelColor))
        detail.addArrangedSubview(button("Przełącz konto…", #selector(demoAction)))
        stack.addArrangedSubview(detail)
        let help = NSTextField(wrappingLabelWithString: "Synchronizacja z aplikacją Codex jest wyłączona. Możesz ją włączyć w Ustawieniach. Zmiana konta może wtedy wymagać ponownego uruchomienia Codex.")
        help.font = .systemFont(ofSize: 11); help.textColor = .secondaryLabelColor
        stack.addArrangedSubview(help)
        help.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        let separator = NSBox(); separator.boxType = .separator; stack.addArrangedSubview(separator)
        separator.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        status = label("Dane demonstracyjne  •  Paski pokazują pozostały limit  •  1.1.1", size: 11, color: .secondaryLabelColor)
        stack.addArrangedSubview(status)
        window.contentView?.layoutSubtreeIfNeeded(); split.setPosition(240, ofDividerAt: 0)
    }
    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let record = rows[row]
        let group = NSStackView(); group.orientation = .vertical; group.alignment = .leading; group.spacing = 5
        group.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 16)
        switch tableColumn?.identifier.rawValue {
        case "provider":
            group.addArrangedSubview(label(record.0, weight: .semibold))
            group.addArrangedSubview(label(record.1, size: 11, color: .secondaryLabelColor))
        case "session", "week":
            let value = tableColumn?.identifier.rawValue == "session" ? record.2 : record.3
            let text = label(value, weight: .medium); text.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
            group.addArrangedSubview(text)
            let progress = NSProgressIndicator(); progress.isIndeterminate = false; progress.style = .bar
            progress.minValue = 0; progress.maxValue = 100; progress.doubleValue = Double(value.dropLast())!
            progress.setAccessibilityLabel("\(record.0): pozostało \(value)")
            group.addArrangedSubview(progress); progress.widthAnchor.constraint(equalToConstant: 110).isActive = true
        default: group.addArrangedSubview(label("Aktywne", size: 11, color: .secondaryLabelColor))
        }
        return group
    }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { toolbarDefaultItemIdentifiers(toolbar) }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.init("sidebar"), .flexibleSpace, .init("search"), .init("refresh"), .init("add")]
    }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier, willBeInsertedIntoToolbar: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: id)
        if #available(macOS 26.0, *) { item.isBordered = false }
        switch id.rawValue {
        case "search": let search = NSSearchField(); search.placeholderString = "Szukaj konta"; search.frame.size = NSSize(width: 190, height: 24); item.view = search; item.label = "Szukaj"
        default:
            let data = id.rawValue == "sidebar" ? ("sidebar.left", "Pasek boczny", #selector(toggleSidebar)) : id.rawValue == "refresh" ? ("arrow.clockwise", "Odśwież", #selector(refreshData)) : ("plus", "Dodaj konto", #selector(demoAction))
            item.image = NSImage(systemSymbolName: data.0, accessibilityDescription: data.1)
            item.label = data.1; item.toolTip = data.1; item.target = self; item.action = data.2
        }
        return item
    }
    @objc func toggleSidebar() { split.arrangedSubviews[0].isHidden.toggle(); split.adjustSubviews() }
    @objc func refreshData() { status.stringValue = "Podgląd odświeżony  •  Dane demonstracyjne — bez połączenia z kontami" }
    @objc func selectSection(_ sender: NSButton) { status.stringValue = "Wybrano: \(sender.title)  •  Prototyp bez operacji na kontach" }
    @objc func demoAction() { status.stringValue = "Podgląd projektu — ta akcja nie zmienia kont ani ustawień" }
    func export() {
        let directory = URL(fileURLWithPath: CommandLine.arguments.last!)
        for (name, appearance, width, height) in [("main-light", NSAppearance.Name.aqua, 1200, 800), ("main-dark", .darkAqua, 1200, 800), ("compact-light", .aqua, 800, 600)] {
            NSApp.appearance = NSAppearance(named: appearance)
            build()
            window.appearance = NSAppearance(named: appearance)
            window.setContentSize(NSSize(width: width, height: height))
            split.arrangedSubviews[0].isHidden = width < 900
            split.adjustSubviews()
            if width >= 900 { split.setPosition(240, ofDividerAt: 0) }
            let widths: [CGFloat] = width < 900 ? [250, 165, 185, 110] : [300, 190, 210, 120]
            for (column, value) in zip(table.tableColumns, widths) { column.width = value }
            table.reloadData()
            let view = window.contentView!.superview!
            view.layoutSubtreeIfNeeded(); view.display()
            window.appearance!.performAsCurrentDrawingAppearance {
                let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
                view.cacheDisplay(in: view.bounds, to: bitmap)
                try! bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name + ".png"))
            }
        }
    }
}
let app = NSApplication.shared
let delegate = Preview(); app.delegate = delegate
app.run()
