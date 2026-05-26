import AppKit

// MARK: - Custom Win-style alert for replacement count

class ReplacementAlert: NSWindowController {
    init(message: String) {
        let window = DialogWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 80),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.title = "Notepad"
        window.isMovable = false
        window.backgroundColor = Colors.chromeBackground
        window.level = .floating

        // Message label
        let label = NSTextField(labelWithString: message)
        label.font = Fonts.dialogLabel
        label.frame = NSRect(x: 0, y: 36, width: 280, height: 20)
        label.alignment = .center
        label.isBordered = false
        label.isEditable = false
        label.isBezeled = false
        label.focusRingType = .none
        window.contentView?.addSubview(label)

        // OK button
        let okButton = NSButton(frame: NSRect(x: 103, y: 8, width: 75, height: 23))
        okButton.title = "OK"
        okButton.font = Fonts.dialogLabel
        okButton.bezelStyle = .regularSquare
        okButton.isBordered = false
        okButton.wantsLayer = true
        okButton.layer?.borderWidth = 2
        okButton.layer?.borderColor = Colors.selectionBg.cgColor
        okButton.target = self
        okButton.action = #selector(okClicked)
        window.contentView?.addSubview(okButton)

        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func okClicked(_ sender: Any?) {
        window?.close()
    }

    func show() {
        window?.orderFront(nil)
    }
}


// MARK: - Replace Dialog

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
    private var noMatchLabel: NSTextField!

    // State persistence — shared with Find dialog
    private var searchTerm: String = ""
    private var replaceTerm: String = ""
    private var matchCase: Bool = false
    private var wrapAround: Bool = false
    private var direction: FindEngine.Direction = .forward

    // Reference to the active editor
    private weak var activeEditor: EditorView?

    // MARK: - Singleton pattern (modeless)

    static var instance: ReplaceDialog?

    static func show(editor: EditorView?) {
        if let existing = instance {
            existing.window?.makeKeyAndOrderFront(nil)
            existing.findTextField.becomeFirstResponder()
            return
        }
        let dialog = ReplaceDialog(editor: editor)
        instance = dialog
        dialog.show()
    }

    static func close() {
        instance?.window?.close()
    }

    // MARK: - Init

    private init(editor: EditorView?) {
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

    deinit {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
        if ReplaceDialog.instance === self {
            ReplaceDialog.instance = nil
        }
    }

    // MARK: - Window setup

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

    // MARK: - UI setup

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
        if let closeButton = titleBar.subviews.compactMap({ $0 as? TitleBarButton }).first(where: { $0.buttonType == .close }) {
            closeButton.onAction = { [weak window] in
                window?.close()
            }
        }
        contentView.addSubview(titleBar)

        // Content area: 360 × 148
        let contentHeight: CGFloat = 148

        // "Find what:" label
        let findLabel = NSTextField(labelWithString: "Find what:")
        findLabel.frame = NSRect(x: 12, y: contentHeight - 28, width: 65, height: 18)
        findLabel.font = Fonts.dialogLabel
        findLabel.textColor = Colors.chromeText
        findLabel.isEditable = false
        findLabel.isBordered = false
        findLabel.alignment = .right
        contentView.addSubview(findLabel)

        // "Find what:" text field
        findTextField = NSTextField(frame: NSRect(x: 80, y: contentHeight - 28, width: 180, height: 24))
        findTextField.font = Fonts.dialogLabel
        findTextField.textColor = Colors.chromeText
        findTextField.backgroundColor = Colors.chromeBackground
        findTextField.isBordered = false
        findTextField.focusRingType = .none
        findTextField.delegate = self
        contentView.addSubview(findTextField)

        // "Find Next" button (right of Find what field)
        findNextButton = NSButton(frame: NSRect(x: 264, y: contentHeight - 28, width: 75, height: 24))
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

        // "Replace with:" label
        let replaceLabel = NSTextField(labelWithString: "Replace with:")
        replaceLabel.frame = NSRect(x: 12, y: contentHeight - 58, width: 65, height: 18)
        replaceLabel.font = Fonts.dialogLabel
        replaceLabel.textColor = Colors.chromeText
        replaceLabel.isEditable = false
        replaceLabel.isBordered = false
        replaceLabel.alignment = .right
        contentView.addSubview(replaceLabel)

        // "Replace with:" text field
        replaceTextField = NSTextField(frame: NSRect(x: 80, y: contentHeight - 58, width: 180, height: 24))
        replaceTextField.font = Fonts.dialogLabel
        replaceTextField.textColor = Colors.chromeText
        replaceTextField.backgroundColor = Colors.chromeBackground
        replaceTextField.isBordered = false
        replaceTextField.focusRingType = .none
        replaceTextField.delegate = self
        contentView.addSubview(replaceTextField)

        // "Replace" button (right of Replace with field)
        replaceButton = NSButton(frame: NSRect(x: 264, y: contentHeight - 58, width: 75, height: 24))
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

        // "Match case" checkbox
        matchCaseCheckbox = NSButton(frame: NSRect(x: 12, y: contentHeight - 88, width: 100, height: 18))
        matchCaseCheckbox.title = "Match case"
        matchCaseCheckbox.font = Fonts.dialogLabel
        matchCaseCheckbox.setButtonType(.switch)
        matchCaseCheckbox.target = self
        matchCaseCheckbox.action = #selector(matchCaseToggled)
        contentView.addSubview(matchCaseCheckbox)

        // "Wrap around" checkbox
        wrapAroundCheckbox = NSButton(frame: NSRect(x: 12, y: contentHeight - 112, width: 100, height: 18))
        wrapAroundCheckbox.title = "Wrap around"
        wrapAroundCheckbox.font = Fonts.dialogLabel
        wrapAroundCheckbox.setButtonType(.switch)
        wrapAroundCheckbox.target = self
        wrapAroundCheckbox.action = #selector(wrapAroundToggled)
        contentView.addSubview(wrapAroundCheckbox)

        // Direction label
        let directionLabel = NSTextField(labelWithString: "Direction:")
        directionLabel.frame = NSRect(x: 200, y: contentHeight - 88, width: 55, height: 18)
        directionLabel.font = Fonts.dialogLabel
        directionLabel.textColor = Colors.chromeText
        directionLabel.alignment = .right
        contentView.addSubview(directionLabel)

        // Direction Up radio
        directionUpButton = NSButton(frame: NSRect(x: 260, y: contentHeight - 88, width: 80, height: 18))
        directionUpButton.title = "Up"
        directionUpButton.setButtonType(.radio)
        directionUpButton.target = self
        directionUpButton.action = #selector(directionUpSelected)
        directionUpButton.state = .off
        contentView.addSubview(directionUpButton)

        // Direction Down radio
        directionDownButton = NSButton(frame: NSRect(x: 260, y: contentHeight - 112, width: 80, height: 18))
        directionDownButton.title = "Down"
        directionDownButton.setButtonType(.radio)
        directionDownButton.target = self
        directionDownButton.action = #selector(directionDownSelected)
        directionDownButton.state = .on
        contentView.addSubview(directionDownButton)

        // No-match inline label (hidden by default)
        noMatchLabel = NSTextField(labelWithString: "")
        noMatchLabel.frame = NSRect(x: 12, y: contentHeight - 136, width: 324, height: 18)
        noMatchLabel.font = Fonts.dialogLabel
        noMatchLabel.textColor = NSColor.red
        noMatchLabel.alignment = .center
        noMatchLabel.isEditable = false
        noMatchLabel.isBordered = false
        noMatchLabel.isHidden = true
        contentView.addSubview(noMatchLabel)

        // Bottom buttons area
        // Replace All
        replaceAllButton = NSButton(frame: NSRect(x: 12, y: 8, width: 85, height: 23))
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

        // Cancel
        cancelButton = NSButton(frame: NSRect(x: 210, y: 8, width: 75, height: 23))
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

    // MARK: - Keyboard shortcuts

    private func setupKeyboardShortcuts() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event -> NSEvent? in
            guard let self = self, let window = self.window, window.isKeyWindow else { return event }

            let key = event.characters?.lowercased()
            if key == "\r" || key == "\n" {
                self.findNextClicked(nil)
                return nil
            } else if key == "\u{1b}" {
                self.cancelClicked(nil)
                return nil
            }
            return event
        }
    }

    // MARK: - State persistence

    private func restorePersistedState() {
        let state = FindStateManager.shared
        findTextField.stringValue = state.searchTerm
        replaceTextField.stringValue = replaceTerm
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

        // Update the shared state (also visible to Find dialog)
        FindStateManager.shared.updateState(
            searchTerm: searchTerm,
            matchCase: matchCase,
            wrapAround: wrapAround,
            direction: direction
        )

        let options = FindEngine.Options(
            matchCase: matchCase,
            wrapAround: wrapAround,
            direction: direction
        )

        let cursorPosition = editor.selectedRange().location

        if let foundRange = FindEngine.find(
            text: editor.string,
            needle: searchTerm,
            options: options,
            cursorPosition: cursorPosition
        ) {
            editor.setSelectedRange(foundRange)
            editor.scrollRangeToVisible(foundRange)
            hideNoMatchMessage()
        } else {
            NSSound.beep()
            showNoMatchMessage()
        }
    }

    @objc private func replaceClicked(_ sender: Any?) {
        guard let editor = activeEditor else { return }

        searchTerm = findTextField.stringValue
        replaceTerm = replaceTextField.stringValue

        // Update the shared state
        FindStateManager.shared.updateState(
            searchTerm: searchTerm,
            matchCase: matchCase,
            wrapAround: wrapAround,
            direction: direction
        )

        let options = FindEngine.Options(
            matchCase: matchCase,
            wrapAround: wrapAround,
            direction: direction
        )

        let selectedRange = editor.selectedRange()

        // If current selection matches the search term, replace it
        if selectedRange.length > 0 {
            let selectedText = (editor.string as NSString).substring(with: selectedRange)
            let matches = searchTerm == selectedText
                || (!matchCase && selectedText.lowercased() == searchTerm.lowercased())
            if matches {
                editor.insertText(replaceTerm)
                let newCursorPosition = selectedRange.location + replaceTerm.count
                editor.setSelectedRange(NSRange(location: newCursorPosition, length: 0))
            }
        }

        // Then find next occurrence
        if let foundRange = FindEngine.find(
            text: editor.string,
            needle: searchTerm,
            options: options,
            cursorPosition: editor.selectedRange().location
        ) {
            editor.setSelectedRange(foundRange)
            editor.scrollRangeToVisible(foundRange)
            hideNoMatchMessage()
        } else {
            NSSound.beep()
            showNoMatchMessage()
        }
    }

    @objc private func replaceAllClicked(_ sender: Any?) {
        guard let editor = activeEditor else { return }

        searchTerm = findTextField.stringValue
        replaceTerm = replaceTextField.stringValue

        // Update the shared state
        FindStateManager.shared.updateState(
            searchTerm: searchTerm,
            matchCase: matchCase,
            wrapAround: wrapAround,
            direction: direction
        )

        let options = FindEngine.Options(
            matchCase: matchCase,
            wrapAround: wrapAround,
            direction: direction
        )

        var modifiedText = editor.string
        var replacementCount = 0
        var searchStart = 0

        // Find and replace all occurrences from start of document
        while let foundRange = FindEngine.find(
            text: modifiedText,
            needle: searchTerm,
            options: options,
            cursorPosition: searchStart
        ) {
            replacementCount += 1

            let beforeText = (modifiedText as NSString).substring(with: NSRange(location: 0, length: foundRange.location))
            let afterText = (modifiedText as NSString).substring(with: NSRange(location: foundRange.location + foundRange.length, length: modifiedText.count - foundRange.location - foundRange.length))

            modifiedText = beforeText + replaceTerm + afterText

            // Continue searching from after the replacement
            searchStart = foundRange.location + replaceTerm.count
        }

        if replacementCount > 0 {
            editor.string = modifiedText
            // Show replacement count alert
            let alert = ReplacementAlert(message: "Replaced \(replacementCount) occurrence\(replacementCount == 1 ? "" : "s").")
            alert.show()
        } else {
            NSSound.beep()
            showNoMatchMessage()
        }
    }

    @objc private func cancelClicked(_ sender: Any?) {
        window?.close()
    }

    // MARK: - No-match message

    private func showNoMatchMessage() {
        noMatchLabel.stringValue = "Cannot find \"\(searchTerm)\""
        noMatchLabel.isHidden = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.hideNoMatchMessage()
        }
    }

    private func hideNoMatchMessage() {
        noMatchLabel.isHidden = true
    }

    // MARK: - Public Methods

    func show() {
        window?.makeKeyAndOrderFront(nil)
        findTextField.becomeFirstResponder()
    }

    override func close() {
        super.close()
    }
}
