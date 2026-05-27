import AppKit

class FileBrowserSidebar: NSView {
    private var items: [SidebarItem] = []
    private var selectedItemView: SidebarItemView?
    var onDirectorySelected: ((URL) -> Void)?
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = Colors.chromeBackground.cgColor
        
        // Create sidebar items
        createSidebarItems()
        layoutItems()
    }
    
    private func createSidebarItems() {
        // imageLiteralResourceName traps on missing assets; use the failable
        // NSImage(named:) with a folder-icon fallback so absent system images
        // can't crash the file dialog.
        let folder = NSImage(named: NSImage.folderName) ?? NSImage(size: NSSize(width: 16, height: 16))
        func img(_ name: String) -> NSImage { NSImage(named: name) ?? folder }
        let fm = FileManager.default

        let desktop = fm.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop")
        let downloads = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
        let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")

        items.append(SidebarItem(title: "Desktop", icon: img("NSTouchBarFolderIcon"), path: desktop))
        items.append(SidebarItem(title: "Downloads", icon: img("NSTouchBarDownloadIcon"), path: downloads))
        items.append(SidebarItem(title: "Documents", icon: img("NSTouchBarFolderIcon"), path: documents))

        items.append(SidebarItem(title: "This Mac", icon: img("NSTouchBarShareIcon"), path: URL(fileURLWithPath: "/")))
        items.append(SidebarItem(title: "home", icon: img("NSTouchBarUserIcon"), path: URL(fileURLWithPath: NSHomeDirectory())))
    }
    
    private func layoutItems() {
        var y = frame.height - 10
        
        for item in items {
            let itemView = SidebarItemView(frame: NSRect(x: 10, y: y, width: frame.width - 20, height: 30))
            itemView.setup(with: item)
            itemView.onSelected = { [weak self] item in
                self?.selectItem(item)
            }
            addSubview(itemView)
            
            y -= 35
            
            if item.title == "This Mac" {
                // Add separator after This Mac
                let separator = NSView(frame: NSRect(x: 10, y: y - 5, width: frame.width - 20, height: 1))
                separator.wantsLayer = true
                separator.layer?.backgroundColor = Colors.menuSeparator.cgColor
                addSubview(separator)
                y -= 10
            }
        }
    }
    
    private func selectItem(_ item: SidebarItem) {
        selectedItemView?.isSelected = false
        selectedItemView = nil
        
        if let itemView = subviews.first(where: { $0 is SidebarItemView && ($0 as! SidebarItemView).item?.title == item.title }) as? SidebarItemView {
            itemView.isSelected = true
            selectedItemView = itemView
            onDirectorySelected?(item.path)
        }
    }
    
    func selectDirectory(at url: URL) {
        // Only update the visual selection; do NOT fire onDirectorySelected,
        // otherwise FileBrowserDialog.navigate → loadDirectory → selectDirectory
        // recurses forever.
        guard let item = items.first(where: { $0.path == url }) else { return }
        selectedItemView?.isSelected = false
        selectedItemView = nil
        if let itemView = subviews.first(where: { ($0 as? SidebarItemView)?.item?.title == item.title }) as? SidebarItemView {
            itemView.isSelected = true
            selectedItemView = itemView
        }
    }
}

private struct SidebarItem {
    let title: String
    let icon: NSImage
    let path: URL
}

private class SidebarItemView: NSView {
    var item: SidebarItem?
    private var titleLabel: NSTextField!
    private var iconView: NSImageView!
    var onSelected: ((SidebarItem) -> Void)?
    
    var isSelected: Bool = false {
        didSet {
            updateAppearance()
        }
    }
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        wantsLayer = true
        
        // Icon
        iconView = NSImageView(frame: NSRect(x: 5, y: 5, width: 20, height: 20))
        addSubview(iconView)
        
        // Title
        titleLabel = NSTextField(frame: NSRect(x: 30, y: 5, width: frame.width - 35, height: 20))
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.backgroundColor = .clear
        titleLabel.font = Fonts.chrome
        titleLabel.cell?.isScrollable = true
        titleLabel.cell?.lineBreakMode = .byTruncatingTail
        addSubview(titleLabel)
        
        // Mouse interaction
        let trackingArea = NSTrackingArea(rect: bounds, options: [.activeInActiveApp, .mouseEnteredAndExited, .mouseMoved], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
        
        updateAppearance()
    }
    
    func setup(with item: SidebarItem) {
        self.item = item
        iconView.image = item.icon
        titleLabel.stringValue = item.title
    }
    
    private func updateAppearance() {
        if isSelected {
            layer?.backgroundColor = Colors.menuActiveBg.cgColor
            titleLabel.textColor = Colors.chromeText
        } else {
            layer?.backgroundColor = Colors.chromeBackground.cgColor
            titleLabel.textColor = Colors.chromeText
            
            // Hover effect
            if let window = window {
                let mouseLocation = window.mouseLocationOutsideOfEventStream
                let localPoint = convert(mouseLocation, from: nil)
                
                if NSMouseInRect(localPoint, bounds, false) {
                    layer?.backgroundColor = Colors.menuHoverBg.cgColor
                }
            }
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        onSelected?(item!)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        // Remove old tracking areas
        trackingAreas.forEach { removeTrackingArea($0) }
        
        // Add new tracking area
        let trackingArea = NSTrackingArea(rect: bounds, options: [.activeInActiveApp, .mouseEnteredAndExited, .mouseMoved], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
        
        updateAppearance()
    }
    
    override func mouseEntered(with event: NSEvent) {
        updateAppearance()
    }
    
    override func mouseExited(with event: NSEvent) {
        updateAppearance()
    }
}