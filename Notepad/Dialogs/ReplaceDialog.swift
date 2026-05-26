import AppKit

class ReplaceDialog: NSWindowController, NSTextFieldDelegate {
    private var monitor: Any?
    private var findTextField: NSTextField!
    private var replaceTextField: NSTextField!
    private var matchCaseCheckbox: NSButton!
    private var wrapAroundCheckbox: NSButton!
    private var directionUpButton: NSButton!
    private var directionDownButton: NSButton!
    private var findNextButton: NSButton!
    private var replaceButton: NSButton!
    private var replaceAllButton: NSButton!
    private var cancelButton: NSButton!
    
    // State persistence - shared with Find dialog
    private var searchTerm: String = ""
    private var replaceTerm: String = ""
    private var matchCase: Bool = false
    private var wrapAround: Bool = false
    private var direction: InlineFindEngine.Direction = .forward
    
    // Reference to the active editor
    private weak var activeEditor: EditorView?
    
    init(editor: EditorView?) {
        self.activeEditor = editor
        super.init(window: nil)
        setupWindow()
        setupUI()
        setupKeyboardShortcuts()
        restorePersistedState()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindow() {
        let window = DialogWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 180),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.title = "Replace"
        self.window = window
    }
    
    private func setupUI() {
        guard let window = window else { return }
        
        // Content view
        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        window.contentView = contentView
        
        // Custom title bar
        let titleBar = TitleBarView(frame: NSRect(
            x: 0, y: 180 - Metrics.titleBarHeight,
            width: 360, height: Metrics.titleBarHeight
        ))
        titleBar.parentWindow = window
        titleBar.setTitle("Replace")
        // Override close button
        if let closeButton = titleBar.subviews.compactMap({ $0 as? TitleBarButton }).first(where: { $0.buttonType == .close }) {
            closeButton.onAction = { [weak window] in
                window?.close()
            }
        }
        contentView.addSubview(titleBar)
        
        // Content area (below title bar): 360 x 148
        let contentHeight: CGFloat = 148
        
        // "Find what:" text field
        findTextField = NSTextField(frame: NSRect(x: 12, y: contentHeight - 30, width: 336, height: 24))
        findTextField.placeholderString = "Find what:"
        findTextField.font = Fonts.dialogLabel
        findTextField.textColor = Colors.chromeText
        findTextField.backgroundColor = Colors.chromeBackground
        findTextField.isBordered = false
        findTextField.focusRingType = .none
        findTextField.delegate = self
        contentView.addSubview(findTextField)
        
        // "Replace with:" text field
        replaceTextField = NSTextField(frame: NSRect(x: 12, y: contentHeight - 62, width: 336, height: 24))
        replaceTextField.placeholderString = "Replace with:"
        replaceTextField.font = Fonts.dialogLabel
        replaceTextField.textColor = Colors.chromeText
        replaceTextField.backgroundColor = Colors.chromeBackground
        replaceTextField.isBordered = false
        replaceTextField.focusRingType = .none
        replaceTextField.delegate = self
        contentView.addSubview(replaceTextField)
        
        // "Match case" checkbox
        matchCaseCheckbox = NSButton(frame: NSRect(x: 12, y: contentHeight - 90, width: 120, height: 18))
        matchCaseCheckbox.title = "Match case"
        matchCaseCheckbox.font = Fonts.dialogLabel
        matchCaseCheckbox.setButtonType(.switch)
        matchCaseCheckbox.target = self
        matchCaseCheckbox.action = #selector(matchCaseToggled)
        contentView.addSubview(matchCaseCheckbox)
        
        // "Wrap around" checkbox
        wrapAroundCheckbox = NSButton(frame: NSRect(x: 12, y: contentHeight - 114, width: 120, height: 18))
        wrapAroundCheckbox.title = "Wrap around"
        wrapAroundCheckbox.font = Fonts.dialogLabel
        wrapAroundCheckbox.setButtonType(.switch)
        wrapAroundCheckbox.target = self
        wrapAroundCheckbox.action = #selector(wrapAroundToggled)
        contentView.addSubview(wrapAroundCheckbox)
        
        // Direction radio group
        let directionLabel = NSTextField(labelWithString: "Direction:")
        directionLabel.frame = NSRect(x: 200, y: contentHeight - 90, width: 70, height: 18)
        directionLabel.font = Fonts.dialogLabel
        directionLabel.textColor = Colors.chromeText
        directionLabel.alignment = .right
        contentView.addSubview(directionLabel)
        
        directionUpButton = NSButton(frame: NSRect(x: 272, y: contentHeight - 90, width: 60, height: 18))
        directionUpButton.title = "Up"
        directionUpButton.setButtonType(.radio)
        directionUpButton.target = self
        directionUpButton.action = #selector(directionUpSelected)
        directionUpButton.state = .off
        contentView.addSubview(directionUpButton)
        
        directionDownButton = NSButton(frame: NSRect(x: 272, y: contentHeight - 114, width: 60, height: 18))
        directionDownButton.title = "Down"
        directionDownButton.setButtonType(.radio)
        directionDownButton.target = self
        directionDownButton.action = #selector(directionDownSelected)
        directionDownButton.state = .on
        contentView.addSubview(directionDownButton)
        
        // Buttons
        findNextButton = NSButton(frame: NSRect(x: 12, y: 8, width: 75, height: 23))
        findNextButton.title = "Find Next"
        findNextButton.font = Fonts.dialogLabel
        findNextButton.bezelStyle = .regularSquare
        findNextButton.alignment = .center
        findNextButton.target = self
        findNextButton.action = #selector(findNextClicked)
        findNextButton.isBordered = false
        findNextButton.wantsLayer = true
        findNextButton.layer?.borderWidth = 1
        findNextButton.layer?.borderColor = Colors.chromeBorderHeavy.cgColor
        contentView.addSubview(findNextButton)
        
        replaceButton = NSButton(frame: NSRect(x: 93, y: 8, width: 75, height: 23))
        replaceButton.title = "Replace"
        replaceButton.font = Fonts.dialogLabel
        replaceButton.bezelStyle = .regularSquare
        replaceButton.alignment = .center
        replaceButton.target = self
        replaceButton.action = #selector(replaceClicked)
        replaceButton.isBordered = false
        replaceButton.wantsLayer = true
        replaceButton.layer?.borderWidth = 1
        replaceButton.layer?.borderColor = Colors.chromeBorderHeavy.cgColor
        contentView.addSubview(replaceButton)
        
        replaceAllButton = NSButton(frame: NSRect(x: 174, y: 8, width: 85, height: 23))
        replaceAllButton.title = "Replace All"
        replaceAllButton.font = Fonts.dialogLabel
        replaceAllButton.bezelStyle = .regularSquare
        replaceAllButton.alignment = .center
        replaceAllButton.target = self
        replaceAllButton.action = #selector(replaceAllClicked)
        replaceAllButton.isBordered = false
        replaceAllButton.wantsLayer = true
        replaceAllButton.layer?.borderWidth = 1
        replaceAllButton.layer?.borderColor = Colors.chromeBorderHeavy.cgColor
        contentView.addSubview(replaceAllButton)
        
        cancelButton = NSButton(frame: NSRect(x: 265, y: 8, width: 75, height: 23))
        cancelButton.title = "Cancel"
        cancelButton.font = Fonts.dialogLabel
        cancelButton.bezelStyle = .regularSquare
        cancelButton.alignment = .center
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)
        cancelButton.isBordered = false
        cancelButton.keyEquivalent = "\u{1b}"
        contentView.addSubview(cancelButton)
        
        // Center on screen
        window.center()
    }
    
    private func setupKeyboardShortcuts() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event -> NSEvent? in
            guard let self = self, let window = self.window, window.isKeyWindow else { return event }
            
            let key = event.characters?.lowercased()
            if key == "\r" || key == "\n" {
                self.replaceClicked(nil)
                return nil
            } else if key == "\u{1b}" {
                self.cancelClicked(nil)
                return nil
            }
            
            return event
        }
    }
    
    private func restorePersistedState() {
        // Use Find dialog's state for search term and options
        let state = InlineFindStateManager.shared
        findTextField.stringValue = state.searchTerm
        matchCaseCheckbox.state = state.matchCase ? .on : .off
        wrapAroundCheckbox.state = state.wrapAround ? .on : .off
        
        switch state.direction {
        case .forward:
            directionDownSelected()
        case .backward:
            directionUpSelected()
        }
    }
    
    // MARK: - Actions
    
    @objc private func matchCaseToggled() {
        matchCase = matchCaseCheckbox.state == .on
    }
    
    @objc private func wrapAroundToggled() {
        wrapAround = wrapAroundCheckbox.state == .on
    }
    
    @objc private func directionUpSelected() {
        direction = .backward
    }
    
    @objc private func directionDownSelected() {
        direction = .forward
    }
    
    @objc private func findNextClicked(_ sender: Any?) {
        guard let editor = activeEditor else { return }
        
        searchTerm = findTextField.stringValue
        replaceTerm = replaceTextField.stringValue
        
        // Update the shared state (inline to avoid import issues)
        InlineFindStateManager.shared.updateState(
            searchTerm: searchTerm,
            matchCase: matchCase,
            wrapAround: wrapAround,
            direction: direction
        )
        
        let options = InlineFindEngine.Options(
            matchCase: matchCase,
            wrapAround: wrapAround,
            direction: direction
        )
        
        let cursorPosition = editor.selectedRange().location
        
        if let foundRange = InlineFindEngine.find(
            text: editor.string,
            needle: searchTerm,
            options: options,
            cursorPosition: cursorPosition
        ) {
            // Select the found text
            editor.setSelectedRange(foundRange)
            editor.scrollRangeToVisible(foundRange)
        } else {
            // No match found - beep and show message
            NSSound.beep()
            showNoMatchMessage()
        }
    }
    
    @objc private func replaceClicked(_ sender: Any?) {
        guard let editor = activeEditor else { return }
        
        searchTerm = findTextField.stringValue
        replaceTerm = replaceTextField.stringValue
        
        // Update the shared state
        InlineFindStateManager.shared.updateState(
            searchTerm: searchTerm,
            matchCase: matchCase,
            wrapAround: wrapAround,
            direction: direction
        )
        
        let options = InlineFindEngine.Options(
            matchCase: matchCase,
            wrapAround: wrapAround,
            direction: direction
        )
        
        let cursorPosition = editor.selectedRange().location
        let selectedRange = editor.selectedRange()
        
        // If current selection matches the search term, replace it
        if selectedRange.length > 0 {
            let selectedText = (editor.string as NSString).substring(with: selectedRange)
            if searchTerm == selectedText || (!matchCase && selectedText.lowercased() == searchTerm.lowercased()) {
                // Replace the selection
                editor.insertText(replaceTerm)
                // Move cursor to end of replacement
                let newCursorPosition = selectedRange.location + replaceTerm.count
                editor.setSelectedRange(NSRange(location: newCursorPosition, length: 0))
            }
        }
        
        // Then find next occurrence
        if let foundRange = InlineFindEngine.find(
            text: editor.string,
            needle: searchTerm,
            options: options,
            cursorPosition: editor.selectedRange().location
        ) {
            // Select the found text
            editor.setSelectedRange(foundRange)
            editor.scrollRangeToVisible(foundRange)
        } else {
            // No match found - beep and show message
            NSSound.beep()
            showNoMatchMessage()
        }
    }
    
    @objc private func replaceAllClicked(_ sender: Any?) {
        guard let editor = activeEditor else { return }
        
        searchTerm = findTextField.stringValue
        replaceTerm = replaceTextField.stringValue
        
        // Update the shared state
        InlineFindStateManager.shared.updateState(
            searchTerm: searchTerm,
            matchCase: matchCase,
            wrapAround: wrapAround,
            direction: direction
        )
        
        let options = InlineFindEngine.Options(
            matchCase: matchCase,
            wrapAround: wrapAround,
            direction: direction
        )
        
        let originalText = editor.string
        var modifiedText = originalText
        var replacementCount = 0
        var searchStart = 0
        
        // Find all occurrences from the start
        while let foundRange = InlineFindEngine.find(
            text: modifiedText,
            needle: searchTerm,
            options: options,
            cursorPosition: searchStart
        ) {
            replacementCount += 1
            
            // Replace this occurrence
            let beforeRange = NSRange(location: 0, length: foundRange.location)
            let afterRange = NSRange(location: foundRange.location + foundRange.length, length: modifiedText.count - foundRange.location - foundRange.length)
            
            let beforeText = (modifiedText as NSString).substring(with: beforeRange)
            let afterText = (modifiedText as NSString).substring(with: afterRange)
            
            modifiedText = beforeText + replaceTerm + afterText
            
            // Continue searching from after the replacement
            searchStart = foundRange.location + replaceTerm.count
        }
        
        if replacementCount > 0 {
            // Replace the entire text
            editor.string = modifiedText
            
            // Show replacement count alert
            showReplacementCountAlert(count: replacementCount)
        } else {
            // No matches found
            NSSound.beep()
            showNoMatchMessage()
        }
    }
    
    @objc private func cancelClicked(_ sender: Any?) {
        window?.close()
    }
    
    private func showNoMatchMessage() {
        let message = "Cannot find \"\(searchTerm)\""
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = "The specified text was not found."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        
        // Show for 2 seconds
        alert.beginSheetModal(for: window!) { _ in
            // Timer to automatically dismiss after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                alert.window.orderOut(nil)
            }
        }
    }
    
    private func showReplacementCountAlert(count: Int) {
        let message = "Replaced \(count) occurrence\(count == 1 ? "" : "s")."
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = "All occurrences have been replaced."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        
        alert.beginSheetModal(for: window!) { _ in
            alert.window.orderOut(nil)
        }
    }
    
    // MARK: - Public Methods
    
    func show() {
        window?.makeKeyAndOrderFront(nil)
        findTextField.becomeFirstResponder()
    }
}
