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
        NSApplication.shared.terminate(nil)
    }
}
