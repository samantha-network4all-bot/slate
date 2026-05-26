import AppKit

class GoToLineDialog: NSWindowController {
    private var monitor: Any?
    private var lineTextField: NSTextField!
    private var okButton: NSButton!
    private var cancelButton: NSButton!
    
    // Reference to the active editor
    private weak var activeEditor: EditorView?
    
    init(editor: EditorView?) {
        self.activeEditor = editor
        super.init(window: nil)
        setupWindow()
        setupUI()
        setupKeyboardShortcuts()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindow() {
        let window = DialogWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 110),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.title = "Go To Line"
        window.isMovableByWindowBackground = true
        self.window = window
    }
    
    private func setupUI() {
        guard let window = window else { return }
        
        // Content view
        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        window.contentView = contentView
        
        // Custom title bar
        let titleBar = TitleBarView(frame: NSRect(
            x: 0, y: 110 - Metrics.titleBarHeight,
            width: 280, height: Metrics.titleBarHeight
        ))
        titleBar.parentWindow = window
        titleBar.setTitle("Go To Line")
        // Override close button
        if let closeButton = titleBar.subviews.compactMap({ $0 as? TitleBarButton }).first(where: { $0.buttonType == .close }) {
            closeButton.onAction = { [weak window] in
                window?.close()
            }
        }
        contentView.addSubview(titleBar)
        
        // Content area (below title bar): 280 x 78
        let contentHeight: CGFloat = 78
        
        // "Line number:" label
        let lineLabel = NSTextField(labelWithString: "Line number:")
        lineLabel.frame = NSRect(x: 12, y: contentHeight - 30, width: 90, height: 18)
        lineLabel.font = Fonts.dialogLabel
        lineLabel.textColor = Colors.chromeText
        lineLabel.alignment = .right
        contentView.addSubview(lineLabel)
        
        // Text field for line number
        lineTextField = NSTextField(frame: NSRect(x: 108, y: contentHeight - 32, width: 160, height: 24))
        lineTextField.placeholderString = "1"
        lineTextField.font = Fonts.dialogLabel
        lineTextField.textColor = Colors.chromeText
        lineTextField.backgroundColor = Colors.chromeBackground
        lineTextField.isBordered = false
        lineTextField.focusRingType = .none
        lineTextField.alignment = .right
        contentView.addSubview(lineTextField)
        
        // Buttons
        okButton = NSButton(frame: NSRect(x: 107, y: 8, width: 75, height: 23))
        okButton.title = "OK"
        okButton.font = Fonts.dialogLabel
        okButton.bezelStyle = .regularSquare
        okButton.alignment = .center
        okButton.target = self
        okButton.action = #selector(okClicked)
        okButton.isBordered = false
        okButton.wantsLayer = true
        okButton.layer?.borderWidth = 2
        okButton.layer?.borderColor = Colors.selectionBg.cgColor
        okButton.keyEquivalent = "\r"
        contentView.addSubview(okButton)
        
        cancelButton = NSButton(frame: NSRect(x: 190, y: 8, width: 75, height: 23))
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
                self.okClicked(nil)
                return nil
            } else if key == "\u{1b}" {
                self.cancelClicked(nil)
                return nil
            }
            
            return event
        }
    }
    
    // MARK: - Actions
    
    @objc private func okClicked(_ sender: Any?) {
        guard let editor = activeEditor else { return }
        
        let lineNumberText = lineTextField.stringValue.trimmingCharacters(in: .whitespaces)
        guard let lineNumber = Int(lineNumberText), lineNumber > 0 else {
            // Invalid line number - reject
            NSSound.beep()
            lineTextField.becomeFirstResponder()
            return
        }
        
        // Calculate total number of lines
        let text = editor.string
        let lineCount = text.components(separatedBy: .newlines).count
        
        // Clamp to last line
        let targetLine = min(lineNumber, lineCount)
        
        // Find the start position of the target line
        var currentLine = 1
        var targetPosition = 0
        
        for (index, character) in text.enumerated() {
            if currentLine == targetLine {
                targetPosition = index
                break
            }
            if character == "\n" || character == "\r" {
                currentLine += 1
                if index < text.count - 1 && character == "\r" && text[text.index(text.index(after: text.startIndex), offsetBy: index)] == "\n" {
                    // Skip the \n in \r\n
                }
            }
        }
        
        // Set cursor to the start of the line and scroll into view
        let targetRange = NSRange(location: targetPosition, length: 0)
        editor.setSelectedRange(targetRange)
        editor.scrollRangeToVisible(targetRange)
        
        // Close dialog
        window?.close()
    }
    
    @objc private func cancelClicked(_ sender: Any?) {
        window?.close()
    }
    
    // MARK: - Public Methods
    
    func show() {
        window?.makeKeyAndOrderFront(nil)
        lineTextField.becomeFirstResponder()
    }
}
