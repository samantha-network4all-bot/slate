import AppKit

class NotepadWindowController: NSWindowController, NSWindowDelegate {
    private var titleBarView: TitleBarView!

    override init(window: NSWindow?) {
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    init() {
        let frame = Self.defaultFrameStatic()
        let window = NotepadWindow(
            contentRect: frame,
            styleMask: [.borderless, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Untitled - Notepad"
        window.titleVisibility = .hidden
        window.isOpaque = true
        window.backgroundColor = Colors.chromeBackground
        window.level = .normal
        super.init(window: window)
        window.delegate = self

        setupTitleBar()
    }

    private static func defaultFrameStatic() -> NSRect {
        let screen = NSScreen.main!
        let size = Metrics.defaultWindowSize
        let x = screen.visibleFrame.maxX - size.width
        let y = screen.visibleFrame.maxY - size.height
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    private func setupTitleBar() {
        guard let window = window else { return }
        let height = Metrics.titleBarHeight
        let titleBar = TitleBarView(frame: NSRect(x: 0, y: window.frame.height - height, width: window.frame.width, height: height))
        titleBar.parentWindow = window
        window.contentView?.addSubview(titleBar)
        titleBarView = titleBar

        window.setFrameOrigin(NSMakePoint(
            window.frame.origin.x,
            window.frame.origin.y
        ))
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        // Keep title bar at the top during resize
        return frameSize
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = window, let titleBar = titleBarView else { return }
        titleBar.frame = NSRect(
            x: 0,
            y: window.frame.height - Metrics.titleBarHeight,
            width: window.frame.width,
            height: Metrics.titleBarHeight
        )
    }
}
