import AppKit

class DialogContentView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        Colors.chromeBackground.setFill()
        dirtyRect.fill()

        let path = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5))
        path.lineWidth = 1
        Colors.chromeBorderHeavy.setStroke()
        path.stroke()
    }
}

class AboutDialog: NSWindowController {
    private var monitor: Any?

    init() {
        let window = DialogWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isOpaque = true
        window.backgroundColor = Colors.chromeBackground
        window.hasShadow = true
        window.collectionBehavior = [.fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        super.init(window: window)

        // Content view (fills window, draws border)
        let contentView = DialogContentView(frame: window.contentRect(forFrameRect: window.frame))
        window.contentView = contentView

        // Custom title bar with close button only
        let titleBar = TitleBarView(frame: NSRect(
            x: 0, y: 200 - Metrics.titleBarHeight,
            width: 360, height: Metrics.titleBarHeight
        ))
        titleBar.parentWindow = window
        titleBar.setTitle("About Notepad")
        // Override close button to close the dialog
        if let closeButton = titleBar.subviews.compactMap({ $0 as? TitleBarButton }).first(where: { $0.buttonType == .close }) {
            closeButton.onAction = { [weak window] in
                window?.close()
            }
        }
        contentView.addSubview(titleBar)

        // Content area (below title bar): 360 x 168
        let contentHeight: CGFloat = 168

        // Four centered text labels
        let labels: [(text: String, font: NSFont)] = [
            ("Notepad", Fonts.dialogTitle),
            ("Version 1.0", Fonts.dialogLabel),
            ("A faithful Windows 10 Notepad recreation for macOS.", Fonts.dialogLabel),
            ("© 2026 Bimboware", Fonts.dialogLabel)
        ]

        let labelHeights = labels.map { ceil($0.font.ascender - $0.font.descender) }
        let totalLabelHeight = labelHeights.reduce(0, +)
        let gap: CGFloat = 4
        let totalGap = gap * CGFloat(max(0, labels.count - 1))
        let totalHeight = totalLabelHeight + totalGap
        let startY = (contentHeight - totalHeight) / 2

        var y = startY
        for (i, labelData) in labels.enumerated() {
            let label = NSTextField(labelWithString: labelData.text)
            label.font = labelData.font
            label.textColor = Colors.chromeText
            label.alignment = .center
            label.isEditable = false
            label.isBordered = false
            label.focusRingType = .none
            let h = labelHeights[i]
            label.frame = NSRect(
                x: 0,
                y: y,
                width: 360,
                height: h
            )
            contentView.addSubview(label)
            y += h + gap
        }

        // OK button (75x23, bottom right with 8pt padding, default-focused)
        let okButton = NSButton(frame: NSRect(
            x: 360 - 8 - 75,
            y: 8,
            width: 75,
            height: 23
        ))
        okButton.title = "OK"
        okButton.font = Fonts.dialogLabel
        okButton.bezelStyle = .regularSquare
        okButton.alignment = .center
        okButton.target = self
        okButton.action = #selector(okClicked)
        okButton.isBordered = false
        okButton.wantsLayer = true
        okButton.layer?.borderWidth = 2
        okButton.layer?.borderColor = Colors.selectionBg.cgColor
        okButton.layer?.cornerRadius = 0
        contentView.addSubview(okButton)

        // Key monitor: Return/Escape closes the dialog
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak window] event -> NSEvent? in
            guard let window = window, window.isKeyWindow else { return event }
            let key = event.characters?.lowercased()
            if key == "\r" || key == "\n" || key == "\u{1b}" {
                window.close()
                return nil
            }
            return event
        }

        // Center on screen
        window.center()
    }

    @objc private func okClicked(_ sender: Any) {
        window?.close()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
