import AppKit

class InWindowMenuItemView: NSView {
    private let titleLabel: NSTextField
    let title: String
    let accelerator: String
    private var isHovered: Bool = false
    private var showsAccelerator: Bool = false {
        didSet {
            needsDisplay = true
        }
    }

    init(frame: NSRect, title: String, accelerator: String) {
        self.title = title
        self.accelerator = accelerator
        titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = Fonts.chrome
        titleLabel.textColor = Colors.chromeText
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.focusRingType = .none
        super.init(frame: frame)
        wantsLayer = true
        addSubview(titleLabel)
        addTrackingRect(bounds, owner: self, userData: nil, assumeInside: false)
        
        // Listen for Alt key changes
        AltKeyMonitor.onAltChange = { [weak self] isAltDown in
            self?.showsAccelerator = isAltDown
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        let size = titleLabel.cell?.cellSize ?? NSSize(width: 40, height: Metrics.menuBarHeight)
        return NSSize(width: size.width + 2 * Metrics.menuItemPaddingH, height: Metrics.menuBarHeight)
    }

    override func layout() {
        super.layout()
        titleLabel.frame = NSRect(
            x: Metrics.menuItemPaddingH,
            y: (Metrics.menuBarHeight - titleLabel.bounds.height) / 2,
            width: bounds.width - 2 * Metrics.menuItemPaddingH,
            height: titleLabel.bounds.height
        )
    }

    override func updateTrackingAreas() {
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        addTrackingRect(bounds, owner: self, userData: nil, assumeInside: false)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        if let parent = superview as? InWindowMenuBarView {
            let point = NSPoint(x: frame.minX, y: frame.minY)
            parent.popUpMenu(for: self, at: point)
        }
    }
    
    func setHovered(_ hovered: Bool) {
        if isHovered != hovered {
            isHovered = hovered
            needsDisplay = true
        }
    }
    
    func setActive(_ active: Bool) {
        if isHovered != active {
            isHovered = active
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Hover background
        if isHovered {
            Colors.menuHoverBg.setFill()
            dirtyRect.fill()
        }
        
        // Extract display text by removing & prefix if present
        let displayText = title.replacingOccurrences(of: "&", with: "")
        
        // Draw title with optional underline under the accelerator letter
        var attributedString = NSAttributedString(
            string: displayText,
            attributes: [
                .font: Fonts.chrome,
                .foregroundColor: Colors.chromeText
            ]
        )
        
        if showsAccelerator {
            // Find the accelerator letter position and underline it
            let range = (displayText as NSString).range(of: accelerator)
            if range.location != NSNotFound {
                attributedString = NSMutableAttributedString(attributedString: attributedString)
                (attributedString as! NSMutableAttributedString).addAttribute(
                    .underlineStyle,
                    value: NSUnderlineStyle.single.rawValue,
                    range: range
                )
            }
        }
        
        titleLabel.attributedStringValue = attributedString
    }
}
