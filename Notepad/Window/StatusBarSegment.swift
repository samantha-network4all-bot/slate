import AppKit

class StatusBarSegment: NSView {
    private let label: NSTextField
    private var textValue: String

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
        addSubview(label)
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
}
