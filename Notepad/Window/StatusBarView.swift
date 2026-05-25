import AppKit

class StatusBarView: NSView {
    private let lnColLabel: NSTextField
    private let zoomSegment: StatusBarSegment
    private let eolSegment: StatusBarSegment
    private let encodingSegment: StatusBarSegment

    // Separators between right segments
    private let separator1: NSView
    private let separator2: NSView

    override init(frame: NSRect) {
        lnColLabel = NSTextField(labelWithString: "Ln 1, Col 1")
        lnColLabel.font = Fonts.statusBar
        lnColLabel.textColor = Colors.chromeText
        lnColLabel.isEditable = false
        lnColLabel.isBordered = false
        lnColLabel.focusRingType = .none

        zoomSegment = StatusBarSegment(frame: .zero, text: "100%")
        eolSegment = StatusBarSegment(frame: .zero, text: "Windows (CRLF)")
        encodingSegment = StatusBarSegment(frame: .zero, text: "UTF-8")

        separator1 = NSView(frame: .zero)
        separator1.wantsLayer = true
        separator1.layer?.backgroundColor = Colors.statusBarSeparator.cgColor

        separator2 = NSView(frame: .zero)
        separator2.wantsLayer = true
        separator2.layer?.backgroundColor = Colors.statusBarSeparator.cgColor

        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = Colors.statusBarBg.cgColor

        addSubview(lnColLabel)
        addSubview(separator1)
        addSubview(zoomSegment)
        addSubview(separator2)
        addSubview(eolSegment)
        addSubview(encodingSegment)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let padding: CGFloat = Metrics.statusSegmentPaddingH
        let separatorWidth: CGFloat = 1
        let h = bounds.height

        // Ln/Col label on the left
        let lnSize = lnColLabel.cell?.cellSize ?? NSSize(width: 80, height: h)
        lnColLabel.frame = NSRect(
            x: padding,
            y: (h - lnSize.height) / 2,
            width: lnSize.width,
            height: lnSize.height
        )

        // Right segments (right-to-left: encoding, eol, zoom)
        var rightX = bounds.width - padding

        // encoding
        let encSize = encodingSegment.intrinsicContentSize
        rightX -= encSize.width
        encodingSegment.frame = NSRect(x: rightX, y: 0, width: encSize.width, height: h)

        // separator before encoding
        rightX -= separatorWidth
        separator2.frame = NSRect(x: rightX, y: 0, width: separatorWidth, height: h)

        // eol
        let eolSize = eolSegment.intrinsicContentSize
        rightX -= eolSize.width
        eolSegment.frame = NSRect(x: rightX, y: 0, width: eolSize.width, height: h)

        // separator before eol
        rightX -= separatorWidth
        separator1.frame = NSRect(x: rightX, y: 0, width: separatorWidth, height: h)

        // zoom
        let zoomSize = zoomSegment.intrinsicContentSize
        rightX -= zoomSize.width
        zoomSegment.frame = NSRect(x: rightX, y: 0, width: zoomSize.width, height: h)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // 1pt top border
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 0, y: 0.5))
        path.line(to: NSPoint(x: bounds.width, y: 0.5))
        path.lineWidth = 1
        Colors.chromeBorder.setStroke()
        path.stroke()
    }

    func updateLnCol(line: Int, col: Int) {
        lnColLabel.stringValue = "Ln \(line), Col \(col)"
    }

    func updateZoom(_ percent: Int) {
        zoomSegment.setText("\(percent)%")
    }

    func updateEOL(_ label: String) {
        eolSegment.setText(label)
    }

    func updateEncoding(_ label: String) {
        encodingSegment.setText(label)
    }
}
