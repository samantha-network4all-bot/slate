import AppKit

class TitleBarView: NSView {
    private let titleLabel: NSTextField
    private let closeButton: TitleBarButton
    var parentWindow: NSWindow?
    private var lastMouseDown: NSEvent?

    override init(frame: NSRect) {
        titleLabel = NSTextField(labelWithString: "Untitled - Notepad")
        titleLabel.font = Fonts.chrome
        titleLabel.textColor = Colors.chromeText
        titleLabel.alignment = .left
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.focusRingType = .none

        closeButton = TitleBarButton(buttonType: .close, frame: NSRect(
            x: 0, y: 0,
            width: Metrics.titleBarButtonWidth,
            height: Metrics.titleBarButtonHeight
        ))

        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = Colors.chromeBackground.cgColor
        closeButton.onAction = { [weak self] in
            self?.parentWindow?.performClose(nil)
        }
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        addSubview(titleLabel)
        addSubview(closeButton)
        positionSubviews()
        addTrackingRects()
    }

    private func addTrackingRects() {
        addTrackingRect(bounds, owner: self, userData: nil, assumeInside: false)
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        addTrackingRects()
    }

    func positionSubviews() {
        let btnArea = Metrics.titleBarButtonWidth
        let h = Metrics.titleBarHeight
        let closeX = frame.width - btnArea
        closeButton.frame = NSRect(x: closeX, y: 0, width: btnArea, height: h)

        titleLabel.frame = NSRect(
            x: Metrics.titleBarPaddingLeft,
            y: 0,
            width: closeX - Metrics.titleBarPaddingLeft - Metrics.titleBarPaddingLeft,
            height: h
        )
        titleLabel.alignment = .left
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // White background
        Colors.chromeBackground.setFill()
        dirtyRect.fill()
        // 1pt bottom border
        let borderPath = NSBezierPath()
        borderPath.move(to: NSPoint(x: 0, y: frame.height - 0.5))
        borderPath.line(to: NSPoint(x: frame.width, y: frame.height - 0.5))
        borderPath.lineWidth = 1
        Colors.chromeBorder.setStroke()
        borderPath.stroke()
    }

    override func updateTrackingAreas() {
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        addTrackingRect(bounds, owner: self, userData: nil, assumeInside: false)
    }

    override func mouseDown(with event: NSEvent) {
        lastMouseDown = event
        if let parentWindow = parentWindow {
            parentWindow.performDrag(with: event)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        if let parentWindow = parentWindow {
            parentWindow.performDrag(with: event)
        }
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        positionSubviews()
    }
}

extension TitleBarView {
    func setTitle(_ title: String) {
        titleLabel.stringValue = title
    }
}
