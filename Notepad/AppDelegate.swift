import AppKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    // Keyboard shortcut actions
    var newWindowAction: (() -> Void)?
    var openAction: (() -> Void)?
    var saveAction: (() -> Void)?
    var saveAsAction: (() -> Void)?
    var printAction: (() -> Void)?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = DocumentController.shared
        let controller = DocumentController.shared.newWindow()
        controller.showWindow(self)
        
        // Install global keyboard shortcuts that accept both ⌘ and Ctrl
        KeyboardShortcuts.install()
        
        // Setup keyboard shortcut notifications
        setupKeyboardShortcuts()
    }
    
    private func setupKeyboardShortcuts() {
        // Observe keyboard shortcut notifications and forward to appropriate window controllers
        NotificationCenter.default.addObserver(forName: .newWindowShortcut, object: nil, queue: .main) { _ in
            self.createNewWindow()
        }
        
        NotificationCenter.default.addObserver(forName: .openShortcut, object: nil, queue: .main) { _ in
            self.showOpenPanel()
        }
        
        NotificationCenter.default.addObserver(forName: .saveShortcut, object: nil, queue: .main) { _ in
            self.saveActiveDocument()
        }
        
        NotificationCenter.default.addObserver(forName: .saveAsShortcut, object: nil, queue: .main) { _ in
            self.showSaveAsPanel()
        }
        
        NotificationCenter.default.addObserver(forName: .printShortcut, object: nil, queue: .main) { _ in
            self.printDocument()
        }
        
        NotificationCenter.default.addObserver(forName: .undoShortcut, object: nil, queue: .main) { _ in
            self.performUndo()
        }
        
        NotificationCenter.default.addObserver(forName: .redoShortcut, object: nil, queue: .main) { _ in
            self.performRedo()
        }
        
        NotificationCenter.default.addObserver(forName: .cutShortcut, object: nil, queue: .main) { _ in
            self.performCut()
        }
        
        NotificationCenter.default.addObserver(forName: .copyShortcut, object: nil, queue: .main) { _ in
            self.performCopy()
        }
        
        NotificationCenter.default.addObserver(forName: .pasteShortcut, object: nil, queue: .main) { _ in
            self.performPaste()
        }
        
        NotificationCenter.default.addObserver(forName: .deleteShortcut, object: nil, queue: .main) { _ in
            self.performDelete()
        }
        
        NotificationCenter.default.addObserver(forName: .selectAllShortcut, object: nil, queue: .main) { _ in
            self.performSelectAll()
        }
        
        NotificationCenter.default.addObserver(forName: .findShortcut, object: nil, queue: .main) { _ in
            self.showFindDialog()
        }
        
        NotificationCenter.default.addObserver(forName: .findNextShortcut, object: nil, queue: .main) { _ in
            self.performFindNext()
        }
        
        NotificationCenter.default.addObserver(forName: .findPreviousShortcut, object: nil, queue: .main) { _ in
            self.performFindPrevious()
        }
        
        NotificationCenter.default.addObserver(forName: .replaceShortcut, object: nil, queue: .main) { _ in
            self.showReplaceDialog()
        }
        
        NotificationCenter.default.addObserver(forName: .goToShortcut, object: nil, queue: .main) { _ in
            self.showGoToLineDialog()
        }
        
        NotificationCenter.default.addObserver(forName: .zoomInShortcut, object: nil, queue: .main) { _ in
            self.performZoomIn()
        }
        
        NotificationCenter.default.addObserver(forName: .zoomOutShortcut, object: nil, queue: .main) { _ in
            self.performZoomOut()
        }
        
        NotificationCenter.default.addObserver(forName: .resetZoomShortcut, object: nil, queue: .main) { _ in
            self.performResetZoom()
        }
        
        NotificationCenter.default.addObserver(forName: .timeDateShortcut, object: nil, queue: .main) { _ in
            self.insertTimeDate()
        }
    }
    
    // MARK: - Keyboard Shortcut Actions
    
    private func createNewWindow() {
        let controller = DocumentController.shared.newWindow()
        controller.showWindow(self)
    }
    
    private func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.utf8PlainText, .utf16PlainText]
        panel.allowsMultipleSelection = false
        
        let result = panel.runModal()
        if result == .OK, let url = panel.url {
            _ = DocumentController.shared.openFile(at: url)
        }
    }
    
    private func saveActiveDocument() {
        guard let activeController = DocumentController.shared.windows.last else { return }
        activeController.save(nil)
    }
    
    private func showSaveAsPanel() {
        guard let activeController = DocumentController.shared.windows.last else { return }
        activeController.fileSaveAs()
    }
    
    private func printDocument() {
        // Placeholder for print functionality
        let alert = NSAlert()
        alert.messageText = "Print functionality coming soon"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func performUndo() {
        guard let activeController = DocumentController.shared.windows.last else { return }
        activeController.undo(nil)
    }
    
    private func performRedo() {
        guard let activeController = DocumentController.shared.windows.last else { return }
        activeController.redo(nil)
    }
    
    private func performCut() {
        guard let activeController = DocumentController.shared.windows.last else { return }
        activeController.cut(nil)
    }
    
    private func performCopy() {
        guard let activeController = DocumentController.shared.windows.last else { return }
        activeController.copy(nil)
    }
    
    private func performPaste() {
        guard let activeController = DocumentController.shared.windows.last else { return }
        activeController.paste(nil)
    }
    
    private func performDelete() {
        guard let activeController = DocumentController.shared.windows.last else { return }
        activeController.delete(nil)
    }
    
    private func performSelectAll() {
        guard let activeController = DocumentController.shared.windows.last else { return }
        activeController.editorSelectAll()
    }
    
    private func showFindDialog() {
        guard let activeController = DocumentController.shared.windows.last else { return }
        activeController.showFind()
    }
    
    private func performFindNext() {
        guard let activeController = DocumentController.shared.windows.last else { return }
        activeController.findNext()
    }
    
    private func performFindPrevious() {
        guard let activeController = DocumentController.shared.windows.last else { return }
        activeController.findPrevious()
    }
    
    private func showReplaceDialog() {
        guard let activeController = DocumentController.shared.windows.last else { return }
        activeController.showReplace()
    }
    
    private func showGoToLineDialog() {
        guard let activeController = DocumentController.shared.windows.last else { return }
        activeController.showGoToLine()
    }
    
    private func performZoomIn() {
        guard let activeController = DocumentController.shared.windows.last else { return }
        activeController.zoomIn()
    }
    
    private func performZoomOut() {
        guard let activeController = DocumentController.shared.windows.last else { return }
        activeController.zoomOut()
    }
    
    private func performResetZoom() {
        guard let activeController = DocumentController.shared.windows.last else { return }
        activeController.resetZoom()
    }
    
    private func insertTimeDate() {
        guard let activeController = DocumentController.shared.windows.last else { return }
        activeController.insertTimeDate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    @objc func showAbout() {
        // Open About dialog on the frontmost window
        if let frontController = DocumentController.shared.windows.last,
           let window = frontController.window {
            let dialog = AboutDialog()
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.runModal(for: dialog.window!)
            dialog.close()
        }
    }

    @objc func quitApp() {
        // Check for dirty windows and prompt to save
        let dirtyWindows = DocumentController.shared.windows.filter { $0.documentState.isDirty }
        
        if dirtyWindows.isEmpty {
            // No dirty windows, quit immediately
            NSApplication.shared.terminate(nil)
        } else {
            // For now, just quit with a warning - the full dirty-close flow
            // will be implemented when SaveChangesPrompt is fully functional
            let alert = NSAlert()
            alert.messageText = "Some documents have unsaved changes."
            alert.informativeText = "Changes will be lost if you quit now."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Quit")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
