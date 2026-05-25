import AppKit

class InWindowMenuBarView: NSView {
    private let menuItems: [InWindowMenuItemView]
    private let menuBuilders: [String: () -> NSMenu]

    override init(frame frameRect: NSRect) {
        let menus: [(String, String)] = [
            ("File", "F"), ("Edit", "E"), ("Format", "o"), ("View", "V"), ("Help", "H")
        ]

        self.menuBuilders = [:]
        self.menuItems = menus.map { InWindowMenuItemView(frame: .zero, title: $0.0, accelerator: $0.1) }

        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = Colors.chromeBackground.cgColor

        for item in menuItems {
            addSubview(item)
        }
        layoutItems()
    }

    init(frame frameRect: NSRect, menuBuilders: [String: () -> NSMenu]) {
        let menus: [(String, String)] = [
            ("File", "F"), ("Edit", "E"), ("Format", "o"), ("View", "V"), ("Help", "H")
        ]

        self.menuBuilders = menuBuilders
        self.menuItems = menus.map { InWindowMenuItemView(frame: .zero, title: $0.0, accelerator: $0.1) }

        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = Colors.chromeBackground.cgColor

        for item in menuItems {
            addSubview(item)
        }
        layoutItems()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func layoutItems() {
        var x: CGFloat = 0
        for item in menuItems {
            let w = item.intrinsicContentSize.width + 2 * Metrics.menuItemPaddingH
            item.frame = NSRect(
                x: x,
                y: 0,
                width: w,
                height: Metrics.menuBarHeight
            )
            x += w
        }
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        layoutItems()
    }

    func popUpMenu(for menuItem: InWindowMenuItemView, at point: NSPoint) {
        if let builder = menuBuilders[menuItem.title] {
            let menu = builder()
            menu.popUp(positioning: nil, at: point, in: menuItem)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // 1pt bottom border
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 0, y: frame.height - 0.5))
        path.line(to: NSPoint(x: frame.width, y: frame.height - 0.5))
        path.lineWidth = 1
        Colors.chromeBorder.setStroke()
        path.stroke()
    }
}
