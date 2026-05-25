import AppKit

enum TitleButtonType {
    case minimize
    case maximize
    case close
}

class TitleBarButton: NSView {
    let buttonType: TitleButtonType
    var onAction: (() -> Void)?

    private var isHovered: Bool = false {
        didSet { needsDisplay = true }
    }

    init(buttonType: TitleButtonType, frame: NSRect) {
        self.buttonType = buttonType
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        addTrackingRect(bounds, owner: self, userData: nil, assumeInside: true)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        addTrackingRect(bounds, owner: self, userData: nil, assumeInside: true)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    override func mouseDown(with event: NSEvent) {
        onAction?()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Background
        if isHovered {
            let bgColor: NSColor
            switch buttonType {
            case .close:
                bgColor = Colors.closeButtonHover
            case .minimize, .maximize:
                bgColor = Colors.titleBarButtonHover
            }
            bgColor.setFill()
            dirtyRect.fill()
        }

        // Glyph
        let glyphColor: NSColor
        if isHovered && buttonType == .close {
            glyphColor = .white
        } else {
            glyphColor = Colors.chromeText
        }
        glyphColor.setStroke()

        let path = NSBezierPath()
        path.lineWidth = 1.0

        let centerX = frame.width / 2
        let centerY = frame.height / 2
        let size: CGFloat = Metrics.titleBarIconSize
        let half = size / 2

        switch buttonType {
        case .minimize:
            // Horizontal line
            path.move(to: NSPoint(x: centerX - half, y: centerY))
            path.line(to: NSPoint(x: centerX + half, y: centerY))
            path.stroke()

        case .maximize:
            // Square outline
            let rect = NSRect(
                x: centerX - half,
                y: centerY - half,
                width: size,
                height: size
            )
            path.appendRect(rect)
            path.stroke()

        case .close:
            // X shape
            let inset: CGFloat = 1.0
            path.move(to: NSPoint(x: centerX - half + inset, y: centerY - half + inset))
            path.line(to: NSPoint(x: centerX + half - inset, y: centerY + half - inset))
            path.stroke()
            path.move(to: NSPoint(x: centerX + half - inset, y: centerY - half + inset))
            path.line(to: NSPoint(x: centerX - half + inset, y: centerY + half - inset))
            path.stroke()
        }
    }
}
