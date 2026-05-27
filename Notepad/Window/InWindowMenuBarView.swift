import AppKit

class InWindowMenuBarView: NSView {
    let menuItems: [InWindowMenuItemView]
    private let menuBuilders: [String: () -> NSMenu]
    private var activeMenuItem: InWindowMenuItemView?

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
        setupTrackingAreas()
    }
    
    override convenience init(frame frameRect: NSRect) {
        self.init(frame: frameRect, menuBuilders: [
            "File": { MenuBuilder.buildFileMenu() },
            "Edit": { MenuBuilder.buildEditMenu() },
            "Format": { MenuBuilder.buildFormatMenu() },
            "View": { MenuBuilder.buildViewMenu() },
            "Help": { MenuBuilder.buildHelpMenu() }
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupTrackingAreas() {
        for item in menuItems {
            let trackingArea = NSTrackingArea(rect: item.frame, options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect], owner: self, userInfo: ["menuItem": item])
            addTrackingArea(trackingArea)
        }
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
        setupTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        if let userInfo = event.userData as? [String: Any], 
           let menuItem = userInfo["menuItem"] as? InWindowMenuItemView {
            menuItem.setHovered(true)
        }
    }

    override func mouseExited(with event: NSEvent) {
        if let userInfo = event.userData as? [String: Any], 
           let menuItem = userInfo["menuItem"] as? InWindowMenuItemView {
            menuItem.setHovered(false)
        }
    }

    func popUpMenu(for menuItem: InWindowMenuItemView, at point: NSPoint) {
        // Set active item for visual feedback
        activeMenuItem = menuItem
        menuItem.setActive(true)
        
        if let builder = menuBuilders[menuItem.title] {
            let menu = builder()
            
            // Track that a menu is open
            MenuStateManager.menuOpened()
            
            // Set up a notification to track when menu closes
            NotificationCenter.default.addObserver(forName: NSApplication.didHideNotification, object: menu, queue: .main) { [weak self] _ in
                MenuStateManager.menuClosed()
                self?.activeMenuItem?.setActive(false)
                self?.activeMenuItem = nil
            }
            
            menu.popUp(positioning: nil, at: point, in: menuItem)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw active menu item background if any
        if let activeItem = activeMenuItem {
            let activePath = NSBezierPath(rect: activeItem.frame)
            Colors.menuActiveBg.setFill()
            activePath.fill()
        }
        
        // 1pt bottom border
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 0, y: frame.height - 0.5))
        path.line(to: NSPoint(x: frame.width, y: frame.height - 0.5))
        path.lineWidth = 1
        Colors.chromeBorder.setStroke()
        path.stroke()
    }
}
