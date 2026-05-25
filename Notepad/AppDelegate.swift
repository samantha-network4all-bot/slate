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
        NSApplication.shared.orderFrontStandardAboutPanel(nil)
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
