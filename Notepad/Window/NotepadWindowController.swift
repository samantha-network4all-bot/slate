import AppKit

class NotepadWindowController: NSWindowController, NSWindowDelegate {
    private var titleBarView: TitleBarView!
    private var menuBarView: InWindowMenuBarView!
    private var editorScrollView: EditorScrollView!
    private var statusBarView: StatusBarView!
    private var shortcutMonitor: Any?

    let documentState = DocumentState()

    override init(window: NSWindow?) {
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    init(frame: NSRect? = nil) {
        // Set the main menu bar on first window
        if NSApp.mainMenu == nil {
            NSApp.mainMenu = MenuBuilder.build()
        }

        let frame = frame ?? Self.restoreFrame() ?? Self.defaultFrameStatic()
        let window = NotepadWindow(
            contentRect: frame,
            styleMask: [.borderless, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = documentState.title
        window.titleVisibility = .hidden
        window.isOpaque = true
        window.backgroundColor = Colors.chromeBackground
        window.level = .normal
        super.init(window: window)
        window.delegate = self

        setupTitleBar()
        setupMenuBar()
        setupEditor()
        setupStatusBar()
        setupDirtyTracking()
        setupKeyboardShortcuts()
        layoutAllSubviews()
    }

    private static func defaultFrameStatic() -> NSRect {
        let screen = NSScreen.main!
        let size = Metrics.defaultWindowSize
        let x = screen.visibleFrame.maxX - size.width
        let y = screen.visibleFrame.maxY - size.height
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    // MARK: - Frame persistence

    /// Restore the last-saved window frame from UserDefaults.
    /// Returns nil if no frame was saved.
    static func restoreFrame() -> NSRect? {
        guard let rect = UserDefaults.standard.value(forKey: "lastFrame.0") as? NSValue else {
            return nil
        }
        return rect.rectValue
    }

    /// Save the current window frame to UserDefaults.
    static func saveFrame(_ frame: NSRect) {
        UserDefaults.standard.set(NSValue(rect: frame), forKey: "lastFrame.0")
    }

    /// Compute a cascading frame offset +22pt right and -22pt down from a source frame.
    static func cascadedFrame(from sourceFrame: NSRect) -> NSRect {
        var newFrame = sourceFrame
        newFrame.origin.x += 22
        newFrame.origin.y -= 22
        return newFrame
    }

    // MARK: - UI Setup

    private func setupTitleBar() {
        guard let window = window else { return }
        let height = Metrics.titleBarHeight
        let titleBar = TitleBarView(frame: NSRect(
            x: 0, y: window.frame.height - height,
            width: window.frame.width, height: height
        ))
        titleBar.parentWindow = window
        titleBar.setTitle(documentState.title)
        window.contentView?.addSubview(titleBar)
        titleBarView = titleBar
    }

    private func setupMenuBar() {
        guard let window = window else { return }
        let h = Metrics.menuBarHeight
        let builders: [String: () -> NSMenu] = [
            "File": MenuBuilder.buildFileMenu,
            "Edit": MenuBuilder.buildEditMenu,
            "Format": MenuBuilder.buildFormatMenu,
            "View": MenuBuilder.buildViewMenu,
            "Help": MenuBuilder.buildHelpMenu
        ]
        let menuBar = InWindowMenuBarView(
            frame: NSRect(
                x: 0, y: window.frame.height - Metrics.titleBarHeight - h,
                width: window.frame.width, height: h
            ),
            menuBuilders: builders
        )
        window.contentView?.addSubview(menuBar)
        menuBarView = menuBar
    }

    private func setupEditor() {
        guard let window = window else { return }
        let editorSV = EditorScrollView(frame: .zero)
        window.contentView?.addSubview(editorSV)
        editorScrollView = editorSV
    }

    private func setupStatusBar() {
        guard let window = window else { return }
        let h = Metrics.statusBarHeight
        let statusBar = StatusBarView(frame: NSRect(
            x: 0, y: 0,
            width: window.frame.width, height: h
        ))
        window.contentView?.addSubview(statusBar)
        statusBarView = statusBar
    }

    private func setupDirtyTracking() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(textDidChange(_:)),
            name: NSText.didChangeNotification,
            object: editorScrollView.editor?.textStorage
        )
    }

    private func layoutAllSubviews() {
        guard let window = window else { return }
        let w = window.frame.width
        let h = window.frame.height

        titleBarView.frame = NSRect(x: 0, y: h - Metrics.titleBarHeight, width: w, height: Metrics.titleBarHeight)
        menuBarView.frame = NSRect(
            x: 0,
            y: h - Metrics.titleBarHeight - Metrics.menuBarHeight,
            width: w,
            height: Metrics.menuBarHeight
        )
        statusBarView.frame = NSRect(x: 0, y: 0, width: w, height: Metrics.statusBarHeight)

        let editorTop = h - Metrics.titleBarHeight - Metrics.menuBarHeight
        let editorBottom = Metrics.statusBarHeight
        editorScrollView.frame = NSRect(
            x: 0,
            y: editorBottom,
            width: w,
            height: editorTop - editorBottom
        )
    }

    // MARK: - Dirty State

    @objc private func textDidChange(_ notification: Notification) {
        documentState.text = editorScrollView.editor?.string ?? ""
        documentState.isDirty = true
        updateWindowTitle()
    }

    private func updateWindowTitle() {
        window?.title = documentState.title
        titleBarView.setTitle(documentState.title)
    }

    // MARK: - About Dialog

    @objc func showAbout() {
        let dialog = AboutDialog()
        window?.makeKeyAndOrderFront(nil)
        NSApp.runModal(for: dialog.window!)
        dialog.close()
    }

    // MARK: - Standard Edit Actions (delegated to first responder)

    @objc func undo(_ sender: Any?) {
        editorScrollView.editor.undoManager?.undo()
    }

    @objc func redo(_ sender: Any?) {
        editorScrollView.editor.undoManager?.redo()
    }

    @objc func cut(_ sender: Any?) {
        editorScrollView.editor.cut(nil)
    }

    @objc func copy(_ sender: Any?) {
        editorScrollView.editor.copy(nil)
    }

    @objc func paste(_ sender: Any?) {
        editorScrollView.editor.paste(nil)
    }

    @objc func delete(_ sender: Any?) {
        editorScrollView.editor.delete(nil)
    }

    @objc func editorSelectAll() {
        editorScrollView.editor.selectAll(nil)
    }

    // MARK: - File Menu

    @objc func fileNew() {
        let controller = DocumentController.shared.newWindow(sourceController: self)
        controller.showWindow(self)
    }

    @objc func fileOpen() {
        // Placeholder for FileBrowserDialog (future issue)
    }

    @objc func fileSave() {
        save(nil)
    }

    @objc func fileSaveAs() {
        presentSavePanel()
    }

    @objc func pageSetup() {
        let dialog = PageSetupDialog()
        window?.makeKeyAndOrderFront(nil)
        NSApp.runModal(for: dialog.window!)
        dialog.close()
    }

    @objc func filePrint() {
        // Placeholder for print functionality (future issue)
    }

    // MARK: - Edit Menu

    @objc func insertTimeDate() {
        // Placeholder for time/date insertion (future issue)
    }

    @objc func showFind() {
        // Placeholder for Find dialog (future issue)
    }

    @objc func findNext() {
        // Placeholder (future issue)
    }

    @objc func findPrevious() {
        // Placeholder (future issue)
    }

    @objc func showReplace() {
        // Placeholder for Replace dialog (future issue)
    }

    @objc func showGoToLine() {
        // Placeholder for Go To Line dialog (future issue)
    }

    // MARK: - Format Menu

    @objc func toggleWordWrap() {
        // Placeholder for word wrap toggle (future issue)
    }

    @objc func showFontDialog() {
        // Placeholder for Font dialog (future issue)
    }

    // MARK: - View Menu

    @objc func zoomIn() {
        // Placeholder for zoom in (future issue)
    }

    @objc func zoomOut() {
        // Placeholder for zoom out (future issue)
    }

    @objc func resetZoom() {
        // Placeholder for reset zoom (future issue)
    }

    @objc func toggleStatusBar() {
        // Placeholder for status bar toggle (future issue)
    }

    // MARK: - Save

    @objc private func save(_ sender: Any?) {
        if let url = documentState.url {
            saveTo(url)
        } else {
            presentSavePanel()
        }
    }

    private func presentSavePanel() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Untitled"
        panel.allowedContentTypes = [.item]
        panel.isExtensionHidden = false
        panel.allowsOtherFileTypes = true

        let result = panel.runModal()
        if result == .OK, let url = panel.url {
            documentState.url = url
            saveTo(url)
        }
    }

    private func saveTo(_ url: URL) {
        do {
            let text = editorScrollView.editor?.string ?? ""
            try DocumentWriter.write(text, to: url, encoding: documentState.encoding, lineEnding: documentState.lineEnding)
            documentState.isDirty = false
            updateWindowTitle()
        } catch {
            // Silent failure per PRD §21
        }
    }

    // MARK: - Keyboard Shortcuts

    private func setupKeyboardShortcuts() {
        shortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event -> NSEvent? in
            guard let self = self else { return event }
            if event.modifierFlags.contains(.command) &&
               !event.modifierFlags.contains(.shift) &&
               !event.modifierFlags.contains(.control) &&
               event.characters?.lowercased() == "s" {
                self.save(nil)
                return nil // consume event
            }
            return event
        }
    }

    // MARK: - NSWindowDelegate

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        return frameSize
    }

    func windowDidResize(_ notification: Notification) {
        layoutAllSubviews()
    }

    func windowWillClose(_ notification: Notification) {
        // Save frame before closing
        Self.saveFrame(window?.frame ?? .zero)
        DocumentController.shared.closeWindow(self)
    }
}
