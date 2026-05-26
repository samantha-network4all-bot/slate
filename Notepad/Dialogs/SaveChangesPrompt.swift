import AppKit

class SaveChangesPrompt: NSWindowController {
    private var monitor: Any?
    var onSave: (() -> Void)?
    var onCancel: (() -> Void)?
    var onDontSave: (() -> Void)?
    private let displayName: String
    
    init(displayName: String) {
        self.displayName = displayName
        let window = DialogWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 130),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isOpaque = true
        window.backgroundColor = Colors.chromeBackground
        window.hasShadow = true
        window.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
        window.isMovableByWindowBackground = true
        super.init(window: window)
        
        // Content view (fills window, draws border)
        let contentView = DialogContentView(frame: window.contentRect(forFrameRect: window.frame))
        window.contentView = contentView
        
        // Custom title bar with close button only
        let titleBar = TitleBarView(frame: NSRect(
            x: 0, y: 130 - Metrics.titleBarHeight,
            width: 420, height: Metrics.titleBarHeight
        ))
        titleBar.parentWindow = window
        titleBar.setTitle("Save Changes")
        // Override close button to cancel the prompt
        if let closeButton = titleBar.subviews.compactMap({ $0 as? TitleBarButton }).first(where: { $0.buttonType == .close }) {
            closeButton.onAction = { [weak window] in
                window?.close()
                self.onCancel?()
            }
        }
        contentView.addSubview(titleBar)
        
        // Content area (below title bar): 420 x 98
        let contentHeight: CGFloat = 98
        
        // Message label
        let message = NSTextField(labelWithString: "Do you want to save changes to \(displayName)?")
        message.font = Fonts.dialogLabel
        message.textColor = Colors.chromeText
        message.alignment = .center
        message.isEditable = false
        message.isBordered = false
        message.focusRingType = .none
        message.frame = NSRect(
            x: 0,
            y: contentHeight - 30,
            width: 420,
            height: 30
        )
        contentView.addSubview(message)
        
        // Button container (right-aligned, 8pt padding, 8pt gap between buttons)
        let buttonContainer = NSView(frame: NSRect(
            x: 0,
            y: 8,
            width: 420,
            height: 23
        ))
        contentView.addSubview(buttonContainer)
        
        // Save button (75x23, leftmost, default-focused)
        let saveButton = NSButton(frame: NSRect(
            x: 8,
            y: 0,
            width: 75,
            height: 23
        ))
        saveButton.title = "Save"
        saveButton.font = Fonts.dialogLabel
        saveButton.bezelStyle = .regularSquare
        saveButton.alignment = .center
        saveButton.target = self
        saveButton.action = #selector(saveClicked)
        saveButton.isBordered = false
        saveButton.wantsLayer = true
        saveButton.layer?.borderWidth = 2
        saveButton.layer?.borderColor = Colors.selectionBg.cgColor
        saveButton.layer?.cornerRadius = 0
        buttonContainer.addSubview(saveButton)
        
        // Don't Save button (75x23, middle)
        let dontSaveButton = NSButton(frame: NSRect(
            x: 8 + 75 + 8,
            y: 0,
            width: 75,
            height: 23
        ))
        dontSaveButton.title = "Don't Save"
        dontSaveButton.font = Fonts.dialogLabel
        dontSaveButton.bezelStyle = .regularSquare
        dontSaveButton.alignment = .center
        dontSaveButton.target = self
        dontSaveButton.action = #selector(dontSaveClicked)
        dontSaveButton.isBordered = false
        dontSaveButton.wantsLayer = true
        dontSaveButton.layer?.borderWidth = 1
        dontSaveButton.layer?.borderColor = Colors.chromeBorderHeavy.cgColor
        dontSaveButton.layer?.cornerRadius = 0
        buttonContainer.addSubview(dontSaveButton)
        
        // Cancel button (75x23, rightmost)
        let cancelButton = NSButton(frame: NSRect(
            x: 8 + 75 + 8 + 75 + 8,
            y: 0,
            width: 75,
            height: 23
        ))
        cancelButton.title = "Cancel"
        cancelButton.font = Fonts.dialogLabel
        cancelButton.bezelStyle = .regularSquare
        cancelButton.alignment = .center
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)
        cancelButton.isBordered = false
        cancelButton.wantsLayer = true
        cancelButton.layer?.borderWidth = 1
        cancelButton.layer?.borderColor = Colors.chromeBorderHeavy.cgColor
        cancelButton.layer?.cornerRadius = 0
        buttonContainer.addSubview(cancelButton)
        
        // Key monitor: Return/Escape handles the buttons
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak window] event -> NSEvent? in
            guard let window = window, window.isKeyWindow else { return event }
            let key = event.characters?.lowercased()
            if key == "\r" || key == "\n" {
                // Return = Save
                self.saveClicked(saveButton)
                return nil
            } else if key == "\u{1b}" {
                // Escape = Cancel
                self.cancelClicked(cancelButton)
                return nil
            }
            return event
        }
        
                // Center on screen
        window.center()
    }
    
    // Convenience method to show as a sheet attached to a parent window
    func showAsSheet(on parentWindow: NSWindow, completionHandler: @escaping (NSApplication.ModalResponse) -> Void) {
        guard let promptWindow = window else {
            completionHandler(.cancel)
            return
        }
        parentWindow.beginSheet(promptWindow, completionHandler: completionHandler)
    }
    
    @objc private func saveClicked(_ sender: Any) {
        onSave?()
        window?.close()
    }
    
    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    @objc private func dontSaveClicked(_ sender: Any) {
        onDontSave?()
        window?.close()
    }
    
    @objc private func cancelClicked(_ sender: Any) {
        onCancel?()
        window?.close()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
