import AppKit

class StatusBarSegment: NSView {
    private let label: NSTextField
    private var textValue: String
    private var onClick: (() -> Void)?
    private var isHovering = false

    init(frame: NSRect, text: String) {
        self.textValue = text
        label = NSTextField(labelWithString: text)
        label.font = Fonts.statusBar
        label.textColor = Colors.chromeText
        label.isEditable = false
        label.isBordered = false
        label.focusRingType = .none
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = Colors.chromeBackground.cgColor
        addSubview(label)
        
        // Add tracking area for hover and click
        let trackingArea = NSTrackingArea(rect: bounds, options: [.activeAlways, .mouseEnteredAndExited], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        let size = label.cell?.cellSize ?? NSSize(width: 40, height: Metrics.statusBarHeight)
        return NSSize(width: size.width + 2 * Metrics.statusSegmentPaddingH, height: Metrics.statusBarHeight)
    }

    override func layout() {
        super.layout()
        let padding: CGFloat = Metrics.statusSegmentPaddingH
        label.frame = NSRect(
            x: padding,
            y: (bounds.height - label.bounds.height) / 2,
            width: bounds.width - 2 * padding,
            height: label.bounds.height
        )
    }

    func setText(_ text: String) {
        textValue = text
        label.stringValue = text
    }
    
    func setOnClick(_ handler: @escaping () -> Void) {
        onClick = handler
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        needsDisplay = true
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovering = false
        needsDisplay = true
    }
    
    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw hover background
        if isHovering {
            let path = NSBezierPath(rect: dirtyRect)
            Colors.menuHoverBg.setFill()
            path.fill()
        }
    }
    
    func setHovered(_ hovered: Bool) {
        if isHovering != hovered {
            isHovering = hovered
            needsDisplay = true
        }
    }
}
