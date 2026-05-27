import AppKit

class DialogWindow: NSWindow {
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    override init(contentRect: NSRect, styleMask: NSWindow.StyleMask, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: styleMask, backing: backing, defer: flag)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        isOpaque = true
        backgroundColor = Colors.chromeBackground
        hasShadow = true
        level = .floating
        collectionBehavior = [.fullScreenAuxiliary]
        isMovableByWindowBackground = true
        titleVisibility = .hidden
    }
    
    func setTitle(_ title: String) {
        // Title bar functionality will be added via custom title bar view in a future update
    }
}
