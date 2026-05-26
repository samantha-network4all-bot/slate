import AppKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = DocumentController.shared
        let controller = DocumentController.shared.newWindow()
        controller.showWindow(self)
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
