import AppKit

class FileBrowserBreadcrumb: NSView {
    private var pathComponents: [PathComponent] = []
    var onPathSelected: ((URL) -> Void)?
    
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
    }
    
    func setPath(_ url: URL) {
        pathComponents = []
        
        var currentPath: URL = url
        var components: [String] = []
        
        // Extract path components
        while currentPath.pathComponents.count > 0 {
            let lastComponent = currentPath.pathComponents.last!
            if !lastComponent.isEmpty {
                components.insert(lastComponent, at: 0)
            }
            currentPath.deleteLastPathComponent()
        }
        
        // Create PathComponent objects
        var currentURL: URL = url.deletingLastPathComponent()
        for component in components {
            let componentURL = currentURL.appendingPathComponent(component)
            pathComponents.append(PathComponent(title: component, url: componentURL))
            currentURL = componentURL
        }
        
        layoutComponents()
    }
    
    private func layoutComponents() {
        subviews.forEach { $0.removeFromSuperview() }
        
        var x: CGFloat = 10
        let y: CGFloat = 5
        let separatorWidth: CGFloat = 10
        let componentHeight: CGFloat = 22
        
        for (index, component) in pathComponents.enumerated() {
            let componentView = PathComponentView(frame: NSRect(x: x, y: y, width: 200, height: componentHeight))
            componentView.setup(with: component)
            componentView.onSelected = { [weak self] url in
                self?.onPathSelected?(url)
            }
            addSubview(componentView)
            
            x += componentView.frame.width + separatorWidth
            
            // Add separator if not the last component
            if index < pathComponents.count - 1 {
                let separator = NSView(frame: NSRect(x: x - separatorWidth, y: y, width: separatorWidth, height: componentHeight))
                separator.wantsLayer = true
                separator.layer?.backgroundColor = Colors.menuSeparator.cgColor
                addSubview(separator)
            }
        }
    }
}

private struct PathComponent {
    let title: String
    let url: URL
}

private class PathComponentView: NSView {
    private var component: PathComponent?
    private var titleLabel: NSTextField!
    private var chevronView: NSImageView?
    var onSelected: ((URL) -> Void)?
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = .clear
        
        // Title label
        titleLabel = NSTextField(frame: bounds)
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.backgroundColor = .clear
        titleLabel.font = Fonts.chrome
        titleLabel.textColor = Colors.chromeText
        titleLabel.cell?.isScrollable = true
        titleLabel.cell?.lineBreakMode = .byTruncatingTail
        addSubview(titleLabel)
        
        // Hover tracking
        let trackingArea = NSTrackingArea(rect: bounds, options: [.activeInActiveApp, .mouseEnteredAndExited], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }
    
    func setup(with component: PathComponent) {
        self.component = component
        titleLabel.stringValue = component.title
        
        // Add chevron for non-last components
        if !component.url.pathComponents.isEmpty {
            chevronView = NSImageView(frame: NSRect(x: titleLabel.frame.maxX + 5, y: 8, width: 6, height: 6))
            chevronView?.image = createChevronImage()
            addSubview(chevronView!)
        }
    }
    
    private func createChevronImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 6, height: 6))
        image.lockFocus()
        
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 0, y: 0))
        path.line(to: NSPoint(x: 6, y: 0))
        path.line(to: NSPoint(x: 3, y: 6))
        path.close()
        path.fill()
        
        image.unlockFocus()
        return image
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        onSelected?(component!.url)
    }
    
    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = Colors.menuHoverBg.cgColor
        titleLabel.textColor = Colors.chromeText
    }
    
    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = .clear
        titleLabel.textColor = Colors.chromeText
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        let trackingArea = NSTrackingArea(rect: bounds, options: [.activeInActiveApp, .mouseEnteredAndExited], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }
}