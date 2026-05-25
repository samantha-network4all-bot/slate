import AppKit

class MenuBuilder {
    static func build() -> NSMenu {
        let menu = NSMenu()

        // App menu
        let appMenu = NSMenu(title: "Notepad")
        let aboutItem = NSMenuItem(title: "About Notepad", action: #selector(AppDelegate.showAbout), keyEquivalent: "")
        appMenu.addItem(aboutItem)
        appMenu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit Notepad", action: #selector(AppDelegate.quitApp), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        appMenu.addItem(quitItem)
        menu.setSubmenu(appMenu, for: NSMenuItem(title: "Notepad", action: nil, keyEquivalent: ""))

        return menu
    }
}
