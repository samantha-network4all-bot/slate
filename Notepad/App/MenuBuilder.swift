import AppKit

class MenuBuilder {
    static func build() -> NSMenu {
        let menu = NSMenu()

        let appMenu = NSMenu(title: "Notepad")
        let aboutItem = NSMenuItem(title: "About Notepad", action: #selector(NotepadWindowController.showAbout), keyEquivalent: "")
        appMenu.addItem(aboutItem)
        appMenu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit Notepad", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        appMenu.addItem(quitItem)
        let appMenuItem = menu.addItem(withTitle: "Notepad", action: nil, keyEquivalent: "")
        menu.setSubmenu(appMenu, for: appMenuItem)

        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(NSMenuItem(title: "New", action: #selector(NotepadWindowController.fileNew), keyEquivalent: "n"))
        fileMenu.addItem(NSMenuItem(title: "Open...", action: #selector(NotepadWindowController.fileOpen), keyEquivalent: "o"))
        fileMenu.addItem(NSMenuItem(title: "Save", action: #selector(NotepadWindowController.fileSave), keyEquivalent: "s"))
        fileMenu.addItem(NSMenuItem(title: "Save As...", action: #selector(NotepadWindowController.fileSaveAs), keyEquivalent: ""))
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(NSMenuItem(title: "Page Setup...", action: #selector(NotepadWindowController.pageSetup), keyEquivalent: ""))
        fileMenu.addItem(NSMenuItem(title: "Print", action: #selector(NotepadWindowController.filePrint), keyEquivalent: "p"))
        fileMenu.addItem(NSMenuItem.separator())
        let exitItem = NSMenuItem(title: "Exit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        exitItem.keyEquivalentModifierMask = [.function]
        fileMenu.addItem(exitItem)
        let fileMenuItem = menu.addItem(withTitle: "File", action: nil, keyEquivalent: "")
        menu.setSubmenu(fileMenu, for: fileMenuItem)

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: #selector(NotepadWindowController.undo), keyEquivalent: "z"))
        let redoItem = NSMenuItem(title: "Redo", action: #selector(NotepadWindowController.redo), keyEquivalent: "y")
        editMenu.addItem(redoItem)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NotepadWindowController.cut), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NotepadWindowController.copy), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NotepadWindowController.paste), keyEquivalent: "v"))
        let deleteItem = NSMenuItem(title: "Delete", action: #selector(NotepadWindowController.delete), keyEquivalent: "\u{8}")
        deleteItem.keyEquivalentModifierMask = []
        editMenu.addItem(deleteItem)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Time/Date", action: #selector(NotepadWindowController.insertTimeDate), keyEquivalent: ""))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Find", action: #selector(NotepadWindowController.showFind), keyEquivalent: "f"))
        editMenu.addItem(NSMenuItem(title: "Find Next", action: #selector(NotepadWindowController.findNext), keyEquivalent: ""))
        editMenu.addItem(NSMenuItem(title: "Find Previous", action: #selector(NotepadWindowController.findPrevious), keyEquivalent: ""))
        editMenu.addItem(NSMenuItem(title: "Replace", action: #selector(NotepadWindowController.showReplace), keyEquivalent: "h"))
        editMenu.addItem(NSMenuItem(title: "Go To Line...", action: #selector(NotepadWindowController.showGoToLine), keyEquivalent: ""))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NotepadWindowController.editorSelectAll), keyEquivalent: "a"))
        let editMenuItem = menu.addItem(withTitle: "Edit", action: nil, keyEquivalent: "")
        menu.setSubmenu(editMenu, for: editMenuItem)

        let formatMenu = NSMenu(title: "Format")
        formatMenu.addItem(NSMenuItem(title: "Word Wrap", action: #selector(NotepadWindowController.toggleWordWrap), keyEquivalent: ""))
        formatMenu.addItem(NSMenuItem(title: "Font...", action: #selector(NotepadWindowController.showFontDialog), keyEquivalent: ""))
        let formatMenuItem = menu.addItem(withTitle: "Format", action: nil, keyEquivalent: "")
        menu.setSubmenu(formatMenu, for: formatMenuItem)

        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(NSMenuItem(title: "Zoom In", action: #selector(NotepadWindowController.zoomIn), keyEquivalent: "="))
        viewMenu.addItem(NSMenuItem(title: "Zoom Out", action: #selector(NotepadWindowController.zoomOut), keyEquivalent: "-"))
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(NSMenuItem(title: "Reset Zoom", action: #selector(NotepadWindowController.resetZoom), keyEquivalent: "0"))
        viewMenu.addItem(NSMenuItem.separator())
        let statusBarItem = NSMenuItem(title: "Status Bar", action: #selector(NotepadWindowController.toggleStatusBar), keyEquivalent: "")
        statusBarItem.state = .on
        viewMenu.addItem(statusBarItem)
        let viewMenuItem = menu.addItem(withTitle: "View", action: nil, keyEquivalent: "")
        menu.setSubmenu(viewMenu, for: viewMenuItem)

        let helpMenu = NSMenu(title: "Help")
        helpMenu.addItem(NSMenuItem(title: "View Help", action: #selector(NotepadWindowController.showAbout), keyEquivalent: ""))
        helpMenu.addItem(NSMenuItem(title: "Send Feedback", action: #selector(NotepadWindowController.showAbout), keyEquivalent: ""))
        helpMenu.addItem(NSMenuItem(title: "About Notepad", action: #selector(NotepadWindowController.showAbout), keyEquivalent: ""))
        let helpMenuItem = menu.addItem(withTitle: "Help", action: nil, keyEquivalent: "")
        menu.setSubmenu(helpMenu, for: helpMenuItem)

        return menu
    }

    static func buildFileMenu() -> NSMenu {
        let menu = NSMenu(title: "File")
        let newItem = NSMenuItem(title: "&New", action: #selector(NotepadWindowController.fileNew), keyEquivalent: "n")
        menu.addItem(newItem)
        menu.addItem(NSMenuItem(title: "&Open...", action: #selector(NotepadWindowController.fileOpen), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "&Save", action: #selector(NotepadWindowController.fileSave), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "Save As...", action: #selector(NotepadWindowController.fileSaveAs), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Page Setup...", action: #selector(NotepadWindowController.pageSetup), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Print", action: #selector(NotepadWindowController.filePrint), keyEquivalent: "p"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "&Exit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        return menu
    }

    static func buildEditMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        let undoItem = NSMenuItem(title: "&Undo", action: #selector(NotepadWindowController.undo), keyEquivalent: "z")
        menu.addItem(undoItem)
        let redoItem = NSMenuItem(title: "&Redo", action: #selector(NotepadWindowController.redo), keyEquivalent: "y")
        menu.addItem(redoItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "&Cut", action: #selector(NotepadWindowController.cut), keyEquivalent: "x"))
        menu.addItem(NSMenuItem(title: "&Copy", action: #selector(NotepadWindowController.copy), keyEquivalent: "c"))
        menu.addItem(NSMenuItem(title: "&Paste", action: #selector(NotepadWindowController.paste), keyEquivalent: "v"))
        let deleteItem = NSMenuItem(title: "Delete", action: #selector(NotepadWindowController.delete), keyEquivalent: "\u{8}")
        deleteItem.keyEquivalentModifierMask = []
        menu.addItem(deleteItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Time/&Date", action: #selector(NotepadWindowController.insertTimeDate), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "&Find", action: #selector(NotepadWindowController.showFind), keyEquivalent: "f"))
        menu.addItem(NSMenuItem(title: "Find Next", action: #selector(NotepadWindowController.findNext), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Find Previous", action: #selector(NotepadWindowController.findPrevious), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "&Replace", action: #selector(NotepadWindowController.showReplace), keyEquivalent: "h"))
        menu.addItem(NSMenuItem(title: "&Go To Line...", action: #selector(NotepadWindowController.showGoToLine), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "&Select All", action: #selector(NotepadWindowController.editorSelectAll), keyEquivalent: "a"))
        return menu
    }

    static func buildFormatMenu() -> NSMenu {
        let menu = NSMenu(title: "Format")
        menu.addItem(NSMenuItem(title: "&Word Wrap", action: #selector(NotepadWindowController.toggleWordWrap), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "&Font...", action: #selector(NotepadWindowController.showFontDialog), keyEquivalent: ""))
        return menu
    }

    static func buildViewMenu() -> NSMenu {
        let menu = NSMenu(title: "View")
        let zoomInItem = NSMenuItem(title: "&Zoom In", action: #selector(NotepadWindowController.zoomIn), keyEquivalent: "=")
        menu.addItem(zoomInItem)
        let zoomOutItem = NSMenuItem(title: "&Zoom Out", action: #selector(NotepadWindowController.zoomOut), keyEquivalent: "-")
        menu.addItem(zoomOutItem)
        menu.addItem(NSMenuItem.separator())
        let resetZoomItem = NSMenuItem(title: "Reset &Zoom", action: #selector(NotepadWindowController.resetZoom), keyEquivalent: "0")
        menu.addItem(resetZoomItem)
        menu.addItem(NSMenuItem.separator())
        let statusBarItem = NSMenuItem(title: "Status Bar", action: #selector(NotepadWindowController.toggleStatusBar), keyEquivalent: "")
        statusBarItem.state = .on
        menu.addItem(statusBarItem)
        return menu
    }

    static func buildHelpMenu() -> NSMenu {
        let menu = NSMenu(title: "Help")
        menu.addItem(NSMenuItem(title: "&View Help", action: #selector(NotepadWindowController.showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Send Feedback", action: #selector(NotepadWindowController.showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "&About Notepad", action: #selector(NotepadWindowController.showAbout), keyEquivalent: ""))
        return menu
    }
}
