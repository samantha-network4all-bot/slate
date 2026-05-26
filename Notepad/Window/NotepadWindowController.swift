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

    init(cascadeFrom: NSRect? = nil) {
        // Set the main menu bar on first window
        if NSApp.mainMenu == nil {
            NSApp.mainMenu = MenuBuilder.build()
        }

        let frame = Self.computeLaunchFrame(cascadeFrom: cascadeFrom)
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
        
        // Apply initial zoom level
        applyZoomLevel()
    }

    private static func defaultFrameStatic() -> NSRect {
        let screen = NSScreen.main!
        let size = Metrics.defaultWindowSize
        let x = screen.visibleFrame.maxX - size.width
        let y = screen.visibleFrame.maxY - size.height
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    /// Restore a previously saved window frame from UserDefaults.
    private static func restoreSavedFrame() -> NSRect? {
        let defaults = UserDefaults.standard
        guard let x = defaults.object(forKey: "lastFrame.0.x") as? Double,
              let y = defaults.object(forKey: "lastFrame.0.y") as? Double,
              let w = defaults.object(forKey: "lastFrame.0.width") as? Double,
              let h = defaults.object(forKey: "lastFrame.0.height") as? Double else {
            return nil
        }
        return NSRect(x: x, y: y, width: w, height: h)
    }

    /// Save the window frame to UserDefaults.
    static func saveFrame(_ frame: NSRect) {
        let defaults = UserDefaults.standard
        defaults.set(frame.origin.x, forKey: "lastFrame.0.x")
        defaults.set(frame.origin.y, forKey: "lastFrame.0.y")
        defaults.set(frame.size.width, forKey: "lastFrame.0.width")
        defaults.set(frame.size.height, forKey: "lastFrame.0.height")
        defaults.synchronize()
    }

    /// Compute the initial frame: cascade from source, or restore saved frame, or default.
    private static func computeLaunchFrame(cascadeFrom: NSRect?) -> NSRect {
        if let source = cascadeFrom {
            // Cascade: +22pt right, -22pt down from the source window.
            var frame = source
            frame.origin.x += 22
            frame.origin.y -= 22
            // Clamp within the screen.
            let screen = NSScreen.main!
            if frame.origin.x + frame.width > screen.visibleFrame.maxX {
                frame.origin.x = screen.visibleFrame.maxX - frame.width
            }
            if frame.origin.y < screen.visibleFrame.minY {
                frame.origin.y = screen.visibleFrame.minY
            }
            return frame
        }

        // Check saved frame from last session.
        if let saved = Self.restoreSavedFrame() {
            return saved
        }

        // First launch: top-right default.
        return defaultFrameStatic()
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
        DocumentController.shared.newWindow(sourceController: self).showWindow(self)
    }

    @objc func fileOpen() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.utf8PlainText, .utf16PlainText]
        panel.allowsMultipleSelection = false

        let result = panel.runModal()
        if result == .OK, let url = panel.url {
            openFile(at: url)
        }
    }

    func openFile(at url: URL) {
        do {
            let (text, encoding, eol) = try DocumentReader.read(from: url)

            documentState.url = url
            documentState.text = text
            documentState.encoding = encoding
            documentState.lineEnding = eol
            documentState.isDirty = false

            // Update editor content
            editorScrollView.editor?.string = text

            // Update title bar
            updateWindowTitle()

            // Update status bar segments
            statusBarView.updateEncoding(encodingStatusLabel(for: encoding))
            statusBarView.updateEOL(eolStatusLabel(for: eol))

            // Show the window
            showWindow(self)
            window?.makeKeyAndOrderFront(nil)
        } catch {
            // Silent failure per PRD §21
        }
    }

    private func encodingStatusLabel(for encoding: DocumentEncoding) -> String {
        switch encoding {
        case .utf8: return "UTF-8"
        case .utf8WithBOM: return "UTF-8 with BOM"
        case .utf16LE: return "UTF-16 LE"
        case .utf16BE: return "UTF-16 BE"
        }
    }

    private func eolStatusLabel(for eol: LineEnding) -> String {
        switch eol {
        case .crlf: return "Windows (CRLF)"
        case .lf: return "Unix (LF)"
        case .cr: return "Macintosh (CR)"
        }
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
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm M/d/yyyy"
        
        let timestamp = formatter.string(from: Date())
        
        // Begin undo group for atomic insertion
        editorScrollView.editor?.undoManager?.beginUndoGrouping()
        
        // Insert the timestamp at the current cursor position
        editorScrollView.editor?.insertText(timestamp)
        
        // End undo group
        editorScrollView.editor?.undoManager?.endUndoGrouping()
    }

    @objc func showFind() {
        let dialog = FindDialog(editor: editorScrollView.editor)
        window?.makeKeyAndOrderFront(nil)
        NSApp.runModal(for: dialog.window!)
        dialog.close()
    }

    @objc func findNext() {
        guard let editor = editorScrollView.editor else { return }
        
        let state = InlineFindStateManager.shared
        let options = InlineFindEngine.Options(
            matchCase: state.matchCase,
            wrapAround: state.wrapAround,
            direction: .forward
        )
        
        let cursorPosition = editor.selectedRange().location
        
        if let foundRange = InlineFindEngine.find(
            text: editor.string,
            needle: state.searchTerm,
            options: options,
            cursorPosition: cursorPosition
        ) {
            editor.setSelectedRange(foundRange)
            editor.scrollRangeToVisible(foundRange)
        } else {
            NSSound.beep()
        }
    }

    @objc func findPrevious() {
        guard let editor = editorScrollView.editor else { return }
        
        let state = InlineFindStateManager.shared
        let options = InlineFindEngine.Options(
            matchCase: state.matchCase,
            wrapAround: state.wrapAround,
            direction: .backward
        )
        
        let cursorPosition = editor.selectedRange().location
        
        if let foundRange = InlineFindEngine.find(
            text: editor.string,
            needle: state.searchTerm,
            options: options,
            cursorPosition: cursorPosition
        ) {
            editor.setSelectedRange(foundRange)
            editor.scrollRangeToVisible(foundRange)
        } else {
            NSSound.beep()
        }
    }

    @objc func showReplace() {
        // Placeholder for Replace dialog (future issue)
    }

    @objc func showGoToLine() {
        let dialog = GoToLineDialog(editor: editorScrollView?.editor)
        dialog.show()
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
        let newZoom = ZoomController.zoomIn(from: documentState.zoomLevel)
        if newZoom != documentState.zoomLevel {
            documentState.zoomLevel = newZoom
            applyZoomLevel()
        }
    }

    @objc func zoomOut() {
        let newZoom = ZoomController.zoomOut(from: documentState.zoomLevel)
        if newZoom != documentState.zoomLevel {
            documentState.zoomLevel = newZoom
            applyZoomLevel()
        }
    }

    @objc func resetZoom() {
        let newZoom = ZoomController.restoreDefault()
        if newZoom != documentState.zoomLevel {
            documentState.zoomLevel = newZoom
            applyZoomLevel()
        }
    }

    @objc func toggleStatusBar() {
        guard let viewMenuItem = NSApp.mainMenu?.item(withTitle: "View")?.submenu?.item(withTitle: "Status Bar") else {
            return
        }
        
        let isHidden = statusBarView.isHidden
        statusBarView.isHidden = !isHidden
        
        // Update checkmark in menu
        if isHidden {
            viewMenuItem.state = .on
        } else {
            viewMenuItem.state = .off
        }
        
        // Relayout to adjust editor size
        layoutAllSubviews()
    }
    
    private func applyZoomLevel() {
        // Get the base font size (Menlo 11pt)
        let baseFontSize: CGFloat = 11
        let zoomFactor = Double(documentState.zoomLevel) / 100.0
        let newFontSize = baseFontSize * CGFloat(zoomFactor)
        
        // Apply to editor
        let newFont = NSFont(name: "Menlo", size: newFontSize) ?? Fonts.editorDefault
        editorScrollView.editor?.font = newFont
        
        // Update status bar
        statusBarView.updateZoom(documentState.zoomLevel)
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
            let cmdOnly = event.modifierFlags.contains(.command) &&
                          !event.modifierFlags.contains(.shift) &&
                          !event.modifierFlags.contains(.control)
            let shiftOnly = event.modifierFlags.contains(.shift) &&
                           !event.modifierFlags.contains(.command) &&
                           !event.modifierFlags.contains(.control)
            let char = event.characters?.lowercased()
            
            if cmdOnly && char == "n" {
                self.fileNew()
                return nil // consume event
            }
            if cmdOnly && char == "s" {
                self.save(nil)
                return nil // consume event
            }
            if cmdOnly && char == "o" {
                self.fileOpen()
                return nil // consume event
            }
            
                    if cmdOnly && char == "o" {
                self.fileOpen()
                return nil // consume event
            }
            
            // Zoom shortcuts (both Cmd and Ctrl)
            let cmdOrCtrl = (event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control)) &&
                           !event.modifierFlags.contains(.shift)
            
            if cmdOrCtrl && char == "=" {
                self.zoomIn()
                return nil // consume event
            }
            
            if cmdOrCtrl && char == "-" {
                self.zoomOut()
                return nil // consume event
            }
            
            if cmdOrCtrl && char == "0" {
                self.resetZoom()
                return nil // consume event
            }
            
            // F5 for Time/Date insertion
            if event.keyCode == 0x3E { // F5 key
                self.insertTimeDate()
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

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if documentState.isDirty {
            // Show save changes prompt
            let prompt = SaveChangesPrompt()
            prompt.onSave = { [weak self] in
                self?.save(nil)
                sender.close()
            }
            prompt.onDontSave = { [weak self] in
                self?.documentState.isDirty = false
                sender.close()
            }
            prompt.onCancel = {
                // Do nothing, keep window open
            }
            
            window?.makeKeyAndOrderFront(nil)
            NSApplication.shared.runModal(for: prompt.window!)
            prompt.close()
            return false // Don't close the window yet
        }
        return true // Can close immediately
    }
    
    func windowWillClose(_ notification: Notification) {
        // Save window frame for restoration on next launch.
        if let frame = window?.frame {
            Self.saveFrame(frame)
        }
        DocumentController.shared.closeWindow(self)
    }
}
