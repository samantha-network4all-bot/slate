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
        
        // Apply initial word wrap state
        applyWordWrap()
        updateWordWrapMenuState()
    }

    private static func defaultFrameStatic() -> NSRect {
        let screen = NSScreen.main
        let size = Metrics.defaultWindowSize
        if let screen = screen {
            let x = screen.visibleFrame.maxX - size.width
            let y = screen.visibleFrame.maxY - size.height
            return NSRect(x: x, y: y, width: size.width, height: size.height)
        }
        return NSRect(x: 0, y: 0, width: size.width, height: size.height)
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
            if let screen = NSScreen.main {
                if frame.origin.x + frame.width > screen.visibleFrame.maxX {
                    frame.origin.x = screen.visibleFrame.maxX - frame.width
                }
                if frame.origin.y < screen.visibleFrame.minY {
                    frame.origin.y = screen.visibleFrame.minY
                }
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
        
        // Set up drag and drop on the editor scroll view
        setupDragAndDrop(on: editorSV)
    }
    
    private func setupDragAndDrop(on scrollView: EditorScrollView) {
        // Register for dragged file types
        scrollView.registerForDraggedTypes([.fileURL])
    }

    private func setupStatusBar() {
        guard let window = window else { return }
        let h = Metrics.statusBarHeight
        let statusBar = StatusBarView(frame: NSRect(
            x: 0, y: 0,
            width: window.frame.width, height: h
        ))
        
        // Set up click handlers for status bar segments
        statusBar.onZoomClick = { [weak self] in
            self?.showZoomPopup()
        }
        
        statusBar.onEOLClick = { [weak self] in
            self?.showEOLPopup()
        }
        
        statusBar.onEncodingClick = { [weak self] in
            self?.showEncodingPopup()
        }
        
        window.contentView?.addSubview(statusBar)
        statusBarView = statusBar
        
        // Set initial line/column display
        updateLineColumnDisplay()
    }

    private func setupDirtyTracking() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(textDidChange(_:)),
            name: NSText.didChangeNotification,
            object: editorScrollView.editor?.textStorage
        )
        
        // Also observe selection changes for line/column updates
        center.addObserver(
            self,
            selector: #selector(selectionDidChange(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: editorScrollView.editor
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
        
        // Update line/column display when text changes
        updateLineColumnDisplay()
    }
    
    @objc private func selectionDidChange(_ notification: Notification) {
        updateLineColumnDisplay()
    }
    
    private func updateLineColumnDisplay() {
        guard let editor = editorScrollView.editor else { return }
        
        let text = editor.string
        let caretOffset = editor.selectedRange().location
        let (line, column) = LineColumnTracker.position(text: text, caretOffset: caretOffset)
        
        statusBarView.updateLnCol(line: line, col: column)
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
        let fileBrowser = FileBrowserDialog(saveAsMode: false) { [weak self] url in
            self?.openFile(at: url)
        }
        fileBrowser.show()
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
        let printInfo = NSPrintInfo.shared
        
        // Load Page Setup values
        let defaults = UserDefaults.standard
        let paperSize = defaults.string(forKey: "pageSetup.paperSize") ?? "Letter"
        let orientation = defaults.string(forKey: "pageSetup.orientation") ?? "Portrait"
        let leftMargin = defaults.double(forKey: "pageSetup.leftMargin")
        let rightMargin = defaults.double(forKey: "pageSetup.rightMargin")
        let topMargin = defaults.double(forKey: "pageSetup.topMargin")
        let bottomMargin = defaults.double(forKey: "pageSetup.bottomMargin")
        
        // Apply paper size
        switch paperSize {
        case "Letter":
            printInfo.horizontalPagination = .fit
            printInfo.verticalPagination = .automatic
        case "A4":
            printInfo.horizontalPagination = .fit
            printInfo.verticalPagination = .automatic
        case "Legal":
            printInfo.horizontalPagination = .fit
            printInfo.verticalPagination = .automatic
        default:
            printInfo.horizontalPagination = .fit
            printInfo.verticalPagination = .automatic
        }
        
        // Apply orientation
        if orientation == "Landscape" {
            printInfo.orientation = .landscape
        } else {
            printInfo.orientation = .portrait
        }
        
        // Apply margins (convert from millimeters to points)
        let marginPoints: Double = 72.0 / 25.4 // mm to points conversion
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        
        // Create print operation
        let printOperation = NSPrintOperation(view: editorScrollView, printInfo: printInfo)
        printOperation.showsPrintPanel = true
        printOperation.showsProgressPanel = true
        
        // Run the print operation
        printOperation.run()
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
        let insertRange = editorScrollView.editor?.selectedRange() ?? NSRange(location: 0, length: 0)
        editorScrollView.editor?.insertText(timestamp, replacementRange: insertRange)
        
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
        ReplaceDialog.show(editor: editorScrollView.editor)
    }

    @objc func showGoToLine() {
        let dialog = GoToLineDialog(editor: editorScrollView?.editor)
        dialog.show()
    }

    // MARK: - Format Menu

    @objc func toggleWordWrap() {
        // Toggle word wrap state
        documentState.isWordWrapEnabled = !documentState.isWordWrapEnabled
        
        // Apply word wrap setting to editor
        applyWordWrap()
        
        // Update menu item checkmark
        updateWordWrapMenuState()
        
        // Mark document as dirty (word wrap setting is part of document state)
        documentState.isDirty = true
        updateWindowTitle()
    }
    
    private func applyWordWrap() {
        guard let textContainer = editorScrollView.editor?.textContainer else { return }
        
        if documentState.isWordWrapEnabled {
            // Word wrap ON: track text view width, hide horizontal scrollbar
            textContainer.widthTracksTextView = true
            textContainer.maximumNumberOfLines = 0  // No limit on lines
            editorScrollView.hasHorizontalScroller = false
        } else {
            // Word wrap OFF: don't track text view width, show horizontal scrollbar
            textContainer.widthTracksTextView = false
            textContainer.maximumNumberOfLines = 0  // No limit on lines
            editorScrollView.hasHorizontalScroller = true
        }
        
        // Force the editor to update its layout
        editorScrollView.editor?.needsDisplay = true
    }
    
    private func updateWordWrapMenuState() {
        // Update macOS top menu bar (both menus are synchronized via MenuBuilder)
        if let topMenu = NSApp.mainMenu {
            if let formatMenuItem = topMenu.item(withTitle: "Format")?.submenu {
                if let wordWrapItem = formatMenuItem.item(withTitle: "Word Wrap") {
                    wordWrapItem.state = documentState.isWordWrapEnabled ? .on : .off
                }
            }
        }
    }

    @objc func showFontDialog() {
        // Collect all editor views from all open windows
        var allEditors: [EditorView] = []
        for wc in DocumentController.shared.windows {
            if let editor = wc.editorScrollView.editor {
                allEditors.append(editor)
            }
        }
        let dialog = FontDialog(editors: allEditors)
        dialog.show()
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

    @objc func save(_ sender: Any?) {
        if let url = documentState.url {
            saveTo(url)
        } else {
            presentSavePanel()
        }
    }

    private func presentSavePanel() {
        let fileBrowser = FileBrowserDialog(saveAsMode: true, initialPath: documentState.url ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!) {
            [weak self] url, encoding, lineEnding in
            self?.documentState.url = url
            self?.documentState.encoding = encoding?.toDocumentEncoding() ?? self?.documentState.encoding ?? .utf8
            self?.documentState.lineEnding = lineEnding?.toLineEnding() ?? self?.documentState.lineEnding ?? .crlf
            self?.saveTo(url)
        }
        
        // Set default values from document state
        // Find and set encoding dropdown
        if let encodingDropdown = fileBrowser.window?.contentView?.subviews.first(where: { $0 is NSView && $0.subviews.contains(where: { $0 is NSPopUpButton }) }) as? NSView {
            if let dropdown = encodingDropdown.subviews.first(where: { $0 is NSPopUpButton }) as? NSPopUpButton {
                let encodingString = documentState.encoding.rawValue
                if let index = dropdown.itemTitles.firstIndex(of: encodingString) {
                    dropdown.selectItem(at: index)
                }
            }
        }
        
        // Find and set line ending dropdown
        if let lineEndingDropdown = fileBrowser.window?.contentView?.subviews.first(where: { $0 is NSView && $0.subviews.contains(where: { $0 is NSPopUpButton }) }) as? NSView {
            if let dropdown = lineEndingDropdown.subviews.first(where: { $0 is NSPopUpButton }) as? NSPopUpButton {
                let lineEndingString = documentState.lineEnding.rawValue
                if let index = dropdown.itemTitles.firstIndex(of: lineEndingString) {
                    dropdown.selectItem(at: index)
                }
            }
        }
        
        // Set filename if available
        if let fileName = documentState.url?.lastPathComponent {
            if let fileNameField = fileBrowser.window?.contentView?.subviews.first(where: { $0 is NSTextField && ($0 as? NSTextField)?.placeholderString == "File name" }) as? NSTextField {
                fileNameField.stringValue = fileName
            }
        }
        
        fileBrowser.show()
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
        // Keyboard shortcuts are now handled globally by KeyboardShortcuts class
        // Just observe notifications and respond accordingly
        NotificationCenter.default.addObserver(forName: .newWindowShortcut, object: nil, queue: .main) { _ in
            self.fileNew()
        }
        
        NotificationCenter.default.addObserver(forName: .openShortcut, object: nil, queue: .main) { _ in
            self.fileOpen()
        }
        
        NotificationCenter.default.addObserver(forName: .saveShortcut, object: nil, queue: .main) { _ in
            self.save(nil)
        }
        
        NotificationCenter.default.addObserver(forName: .saveAsShortcut, object: nil, queue: .main) { _ in
            self.fileSaveAs()
        }
        
        NotificationCenter.default.addObserver(forName: .printShortcut, object: nil, queue: .main) { _ in
            self.filePrint()
        }
        
        NotificationCenter.default.addObserver(forName: .undoShortcut, object: nil, queue: .main) { _ in
            self.undo(nil)
        }
        
        NotificationCenter.default.addObserver(forName: .redoShortcut, object: nil, queue: .main) { _ in
            self.redo(nil)
        }
        
        NotificationCenter.default.addObserver(forName: .cutShortcut, object: nil, queue: .main) { _ in
            self.cut(nil)
        }
        
        NotificationCenter.default.addObserver(forName: .copyShortcut, object: nil, queue: .main) { _ in
            self.copy(nil)
        }
        
        NotificationCenter.default.addObserver(forName: .pasteShortcut, object: nil, queue: .main) { _ in
            self.paste(nil)
        }
        
        NotificationCenter.default.addObserver(forName: .deleteShortcut, object: nil, queue: .main) { _ in
            self.delete(nil)
        }
        
        NotificationCenter.default.addObserver(forName: .selectAllShortcut, object: nil, queue: .main) { _ in
            self.editorSelectAll()
        }
        
        NotificationCenter.default.addObserver(forName: .findShortcut, object: nil, queue: .main) { _ in
            self.showFind()
        }
        
        NotificationCenter.default.addObserver(forName: .findNextShortcut, object: nil, queue: .main) { _ in
            self.findNext()
        }
        
        NotificationCenter.default.addObserver(forName: .findPreviousShortcut, object: nil, queue: .main) { _ in
            self.findPrevious()
        }
        
        NotificationCenter.default.addObserver(forName: .replaceShortcut, object: nil, queue: .main) { _ in
            self.showReplace()
        }
        
        NotificationCenter.default.addObserver(forName: .goToShortcut, object: nil, queue: .main) { _ in
            self.showGoToLine()
        }
        
        NotificationCenter.default.addObserver(forName: .zoomInShortcut, object: nil, queue: .main) { _ in
            self.zoomIn()
        }
        
        NotificationCenter.default.addObserver(forName: .zoomOutShortcut, object: nil, queue: .main) { _ in
            self.zoomOut()
        }
        
        NotificationCenter.default.addObserver(forName: .resetZoomShortcut, object: nil, queue: .main) { _ in
            self.resetZoom()
        }
        
        NotificationCenter.default.addObserver(forName: .timeDateShortcut, object: nil, queue: .main) { _ in
            self.insertTimeDate()
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
            // Show save changes prompt as a sheet
            let prompt = SaveChangesPrompt(displayName: displayNameFromDocumentState())
            prompt.onSave = { [weak self] in
                self?.handleSaveThenClose(sender)
            }
            prompt.onDontSave = { [weak self] in
                self?.documentState.isDirty = false
                sender.close()
            }
            prompt.onCancel = { [weak self] in
                // Do nothing, keep window open
            }
            
            // Show as a sheet attached to this window
            prompt.showAsSheet(on: sender) { response in
                // The sheet has ended, cleanup is handled by the prompt callbacks
            }
            return false // Don't close the window yet
        }
        return true // Can close immediately
    }
    
    func displayNameFromDocumentState() -> String {
        if documentState.url == nil {
            return "Untitled"
        } else {
            // Extract just the filename from the full path for the prompt
            let lastPathComponent = documentState.url!.lastPathComponent
            return lastPathComponent
        }
    }
    
    func handleSaveThenClose(_ window: NSWindow) {
        if documentState.url == nil {
            // Untitled document - show Save As
            presentSaveAsForUntitled(window: window)
        } else {
            // Saved document - just save and close
            save(nil)
            window.close()
        }
    }
    
    func presentSaveAsForUntitled(window: NSWindow) {
        let fileBrowser = FileBrowserDialog(saveAsMode: true, initialPath: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!) {
            [weak self] url, encoding, lineEnding in
            self?.documentState.url = url
            self?.documentState.encoding = encoding?.toDocumentEncoding() ?? self?.documentState.encoding ?? .utf8
            self?.documentState.lineEnding = lineEnding?.toLineEnding() ?? self?.documentState.lineEnding ?? .crlf
            self?.save(nil)
            // Save successful, window will be closed by the save completion
        }
        
        // Set default filename to Untitled
        if let fileNameField = fileBrowser.window?.contentView?.subviews.first(where: { $0 is NSTextField && ($0 as? NSTextField)?.placeholderString == "File name" }) as? NSTextField {
            fileNameField.stringValue = "Untitled"
        }
        
        fileBrowser.show()
    }
    
    func windowWillClose(_ notification: Notification) {
        // Save window frame for restoration on next launch.
        if let frame = window?.frame {
            Self.saveFrame(frame)
        }
        DocumentController.shared.closeWindow(self)
    }
    
    // MARK: - Status Bar Popup Menus
    
    private func showZoomPopup() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Zoom In (⌘+)", action: #selector(zoomIn), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Zoom Out (⌮-)", action: #selector(zoomOut), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Restore Default Zoom (⌮0)", action: #selector(resetZoom), keyEquivalent: ""))
        
        if let window = window {
            let segmentFrame = statusBarView.convert(statusBarView.getZoomSegmentFrame(), to: nil)
            menu.popUp(positioning: nil, at: NSPoint(x: segmentFrame.midX, y: segmentFrame.maxY), in: nil)
        }
    }
    
    private func showEOLPopup() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Windows (CRLF)", action: #selector(selectCRLF), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Unix (LF)", action: #selector(selectLF), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Macintosh (CR)", action: #selector(selectCR), keyEquivalent: ""))
        
        if let window = window {
            let segmentFrame = statusBarView.convert(statusBarView.getEOLEgmentFrame(), to: nil)
            menu.popUp(positioning: nil, at: NSPoint(x: segmentFrame.midX, y: segmentFrame.maxY), in: nil)
        }
    }
    
    private func showEncodingPopup() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "UTF-8", action: #selector(selectUTF8), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "UTF-8 with BOM", action: #selector(selectUTF8WithBOM), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "UTF-16 LE", action: #selector(selectUTF16LE), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "UTF-16 BE", action: #selector(selectUTF16BE), keyEquivalent: ""))
        
        if let window = window {
            let segmentFrame = statusBarView.convert(statusBarView.getEncodingSegmentFrame(), to: nil)
            menu.popUp(positioning: nil, at: NSPoint(x: segmentFrame.midX, y: segmentFrame.maxY), in: nil)
        }
    }
    
    @objc private func selectCRLF() {
        documentState.lineEnding = .crlf
        statusBarView.updateEOL("Windows (CRLF)")
        documentState.isDirty = true
        updateWindowTitle()
    }
    
    @objc private func selectLF() {
        documentState.lineEnding = .lf
        statusBarView.updateEOL("Unix (LF)")
        documentState.isDirty = true
        updateWindowTitle()
    }
    
    @objc private func selectCR() {
        documentState.lineEnding = .cr
        statusBarView.updateEOL("Macintosh (CR)")
        documentState.isDirty = true
        updateWindowTitle()
    }
    
    @objc private func selectUTF8() {
        documentState.encoding = .utf8
        statusBarView.updateEncoding("UTF-8")
        documentState.isDirty = true
        updateWindowTitle()
    }
    
    @objc private func selectUTF8WithBOM() {
        documentState.encoding = .utf8WithBOM
        statusBarView.updateEncoding("UTF-8 with BOM")
        documentState.isDirty = true
        updateWindowTitle()
    }
    
    @objc private func selectUTF16LE() {
        documentState.encoding = .utf16LE
        statusBarView.updateEncoding("UTF-16 LE")
        documentState.isDirty = true
        updateWindowTitle()
    }
    
    @objc private func selectUTF16BE() {
        documentState.encoding = .utf16BE
        statusBarView.updateEncoding("UTF-16 BE")
        documentState.isDirty = true
        updateWindowTitle()
    }
    
    // MARK: - Drag and Drop
    
    func openDraggedFile(_ url: URL) {
        // Check if current window is empty and untitled
        if isCurrentWindowEmptyAndUntitled() {
            // Open the file in the current window
            openFile(at: url)
        } else {
            // Open the file in a new window
            let newController = DocumentController.shared.newWindow(sourceController: self)
            newController.openDraggedFile(url)
        }
    }
    
    private func isCurrentWindowEmptyAndUntitled() -> Bool {
        guard let editor = editorScrollView.editor else { return false }
        let isEmpty = editor.string.isEmpty
        let isUntitled = documentState.url == nil
        return isEmpty && isUntitled
    }
    
    // Handle multiple dragged files
    func openDraggedFiles(_ urls: [URL]) {
        for url in urls {
            if isAcceptableFile(url: url) {
                if isCurrentWindowEmptyAndUntitled() {
                    // Only use the first file in the current window if it's empty and untitled
                    openFile(at: url)
                    // For remaining files, create new windows
                    for remainingUrl in urls.dropFirst() {
                        if isAcceptableFile(url: remainingUrl) {
                            let newController = DocumentController.shared.newWindow(sourceController: self)
                            newController.openDraggedFile(remainingUrl)
                        }
                    }
                    break
                } else {
                    // Each file gets its own window
                    let newController = DocumentController.shared.newWindow(sourceController: self)
                    newController.openDraggedFile(url)
                }
            } else {
                // Non-text files: beep and reject
                NSSound.beep()
            }
        }
    }
    
    private func isAcceptableFile(url: URL) -> Bool {
        let pathExtension = url.pathExtension.lowercased()
        let acceptableExtensions = ["txt", "log", "md", "csv", ""] // "" for no extension
        return acceptableExtensions.contains(pathExtension)
    }
}

// MARK: - Extension methods for enum conversion
extension FileBrowserDialog.FileEncoding {
    func toDocumentEncoding() -> DocumentEncoding {
        switch self {
        case .utf8: return .utf8
        case .utf8WithBOM: return .utf8WithBOM
        case .utf16LE: return .utf16LE
        case .utf16BE: return .utf16BE
        }
    }
}

extension FileBrowserDialog.LineEnding {
    func toLineEnding() -> LineEnding {
        switch self {
        case .crlf: return .crlf
        case .lf: return .lf
        case .cr: return .cr
        }
    }
}

extension LineEnding {
    func toFileBrowserLineEnding() -> FileBrowserDialog.LineEnding {
        switch self {
        case .crlf: return .crlf
        case .lf: return .lf
        case .cr: return .cr
        }
    }
}
