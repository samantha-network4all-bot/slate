import AppKit

// Inline FindEngine and FindStateManager to avoid dependency issues
struct InlineFindEngine {
    enum Direction {
        case forward
        case backward
    }
    
    struct Options {
        let matchCase: Bool
        let wrapAround: Bool
        let direction: Direction
    }
    
    static func find(
        text: String,
        needle: String,
        options: Options,
        cursorPosition: Int
    ) -> NSRange? {
        guard !needle.isEmpty else { return nil }
        
        let searchRange: NSRange
        let searchStart: Int
        
        switch options.direction {
        case .forward:
            searchStart = cursorPosition
            if searchStart >= text.count {
                if options.wrapAround {
                    searchRange = NSRange(location: 0, length: text.count)
                } else {
                    return nil
                }
            } else {
                searchRange = NSRange(location: searchStart, length: text.count - searchStart)
            }
        case .backward:
            searchStart = max(0, cursorPosition - needle.count)
            if searchStart < 0 {
                if options.wrapAround {
                    searchRange = NSRange(location: text.count - needle.count, length: needle.count)
                } else {
                    return nil
                }
            } else {
                searchRange = NSRange(location: 0, length: searchStart)
            }
        }
        
        let searchText = text as NSString
        let foundRange: NSRange
        
        if options.matchCase {
            foundRange = searchText.range(of: needle, options: [], range: searchRange)
        } else {
            foundRange = searchText.range(
                of: needle,
                options: .caseInsensitive,
                range: searchRange
            )
        }
        
        if foundRange.location != NSNotFound {
            return foundRange
        }
        
        // If not found and wrapAround is enabled, try the other part of the text
        if options.wrapAround {
            switch options.direction {
            case .forward:
                let remainingRange = NSRange(location: 0, length: cursorPosition)
                if options.matchCase {
                    return searchText.range(of: needle, options: [], range: remainingRange)
                } else {
                    return searchText.range(
                        of: needle,
                        options: .caseInsensitive,
                        range: remainingRange
                    )
                }
            case .backward:
                let remainingRange = NSRange(location: cursorPosition + needle.count, length: text.count - (cursorPosition + needle.count))
                if options.matchCase {
                    return searchText.range(of: needle, options: [], range: remainingRange)
                } else {
                    return searchText.range(
                        of: needle,
                        options: .caseInsensitive,
                        range: remainingRange
                    )
                }
            }
        }
        
        return nil
    }
}

// Inline FindStateManager to avoid dependency issues
class InlineFindStateManager {
    static let shared = InlineFindStateManager()
    
    private init() {}
    
    var searchTerm: String = ""
    var matchCase: Bool = false
    var wrapAround: Bool = true
    var direction: InlineFindEngine.Direction = .forward
    
    func updateState(searchTerm: String, matchCase: Bool, wrapAround: Bool, direction: InlineFindEngine.Direction) {
        self.searchTerm = searchTerm
        self.matchCase = matchCase
        self.wrapAround = wrapAround
        self.direction = direction
    }
}

class FindDialog: NSWindowController, NSTextFieldDelegate {
    private var monitor: Any?
    private var findTextField: NSTextField!
    private var matchCaseCheckbox: NSButton!
    private var wrapAroundCheckbox: NSButton!
    private var directionUpButton: NSButton!
    private var directionDownButton: NSButton!
    private var findNextButton: NSButton!
    private var cancelButton: NSButton!
    
    // State persistence
    private var searchTerm: String = ""
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
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 140),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.title = "Find"
        self.window = window
    }
    
    private func setupUI() {
        guard let window = window else { return }
        
        // Content view
        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        window.contentView = contentView
        
        // Custom title bar
        let titleBar = TitleBarView(frame: NSRect(
            x: 0, y: 140 - Metrics.titleBarHeight,
            width: 360, height: Metrics.titleBarHeight
        ))
        titleBar.parentWindow = window
        titleBar.setTitle("Find")
        // Override close button
        if let closeButton = titleBar.subviews.compactMap({ $0 as? TitleBarButton }).first(where: { $0.buttonType == .close }) {
            closeButton.onAction = { [weak window] in
                window?.close()
            }
        }
        contentView.addSubview(titleBar)
        
        // Content area (below title bar): 360 x 108
        let contentHeight: CGFloat = 108
        
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
        
        // "Match case" checkbox
        matchCaseCheckbox = NSButton(frame: NSRect(x: 12, y: contentHeight - 58, width: 120, height: 18))
        matchCaseCheckbox.title = "Match case"
        matchCaseCheckbox.font = Fonts.dialogLabel
        matchCaseCheckbox.setButtonType(.switch)
        matchCaseCheckbox.target = self
        matchCaseCheckbox.action = #selector(matchCaseToggled)
        contentView.addSubview(matchCaseCheckbox)
        
        // "Wrap around" checkbox
        wrapAroundCheckbox = NSButton(frame: NSRect(x: 12, y: contentHeight - 82, width: 120, height: 18))
        wrapAroundCheckbox.title = "Wrap around"
        wrapAroundCheckbox.font = Fonts.dialogLabel
        wrapAroundCheckbox.setButtonType(.switch)
        wrapAroundCheckbox.target = self
        wrapAroundCheckbox.action = #selector(wrapAroundToggled)
        contentView.addSubview(wrapAroundCheckbox)
        
        // Direction radio group
        let directionLabel = NSTextField(labelWithString: "Direction:")
        directionLabel.frame = NSRect(x: 200, y: contentHeight - 58, width: 70, height: 18)
        directionLabel.font = Fonts.dialogLabel
        directionLabel.textColor = Colors.chromeText
        directionLabel.alignment = .right
        contentView.addSubview(directionLabel)
        
        directionUpButton = NSButton(frame: NSRect(x: 272, y: contentHeight - 58, width: 60, height: 18))
        directionUpButton.title = "Up"
        directionUpButton.setButtonType(.radio)
        directionUpButton.target = self
        directionUpButton.action = #selector(directionUpSelected)
        directionUpButton.state = .off
        contentView.addSubview(directionUpButton)
        
        directionDownButton = NSButton(frame: NSRect(x: 272, y: contentHeight - 82, width: 60, height: 18))
        directionDownButton.title = "Down"
        directionDownButton.setButtonType(.radio)
        directionDownButton.target = self
        directionDownButton.action = #selector(directionDownSelected)
        directionDownButton.state = .on
        contentView.addSubview(directionDownButton)
        
        // Buttons
        findNextButton = NSButton(frame: NSRect(x: 12, y: 8, width: 100, height: 23))
        findNextButton.title = "Find Next"
        findNextButton.font = Fonts.dialogLabel
        findNextButton.bezelStyle = .regularSquare
        findNextButton.alignment = .center
        findNextButton.target = self
        findNextButton.action = #selector(findNextClicked)
        findNextButton.isBordered = false
        findNextButton.wantsLayer = true
        findNextButton.layer?.borderWidth = 2
        findNextButton.layer?.borderColor = Colors.selectionBg.cgColor
        findNextButton.keyEquivalent = "\r"
        contentView.addSubview(findNextButton)
        
        cancelButton = NSButton(frame: NSRect(x: 124, y: 8, width: 75, height: 23))
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
                self.findNextClicked(nil)
                return nil
            } else if key == "\u{1b}" {
                self.cancelClicked(nil)
                return nil
            }
            
            return event
        }
    }
    
    private func restorePersistedState() {
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
    
    // MARK: - Public Methods
    
    func show() {
        window?.makeKeyAndOrderFront(nil)
        findTextField.becomeFirstResponder()
    }
}