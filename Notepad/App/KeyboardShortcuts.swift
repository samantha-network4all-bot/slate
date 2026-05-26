import AppKit

class KeyboardShortcuts {
    static func install() {
        // Install a global event monitor that accepts both ⌘ and Ctrl modifiers
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event -> NSEvent? in
            handleKeyEvent(event)
            return event
        }
    }
    
    private static func handleKeyEvent(_ event: NSEvent) {
        let char = event.characters?.lowercased()
        let hasCmd = event.modifierFlags.contains(.command)
        let hasCtrl = event.modifierFlags.contains(.control)
        let hasShift = event.modifierFlags.contains(.shift)
        let hasOption = event.modifierFlags.contains(.option)
        
        // Accept both ⌘ and Ctrl as modifier keys
        let hasCmdOrCtrl = hasCmd || hasCtrl
        
        // File menu shortcuts
        if hasCmdOrCtrl && !hasShift && char == "n" {
            handleNewWindow()
            return
        }
        if hasCmdOrCtrl && !hasShift && char == "o" {
            handleOpen()
            return
        }
        if hasCmdOrCtrl && !hasShift && char == "s" {
            handleSave()
            return
        }
        if hasCmdOrCtrl && hasShift && char == "s" {
            handleSaveAs()
            return
        }
        if hasCmdOrCtrl && !hasShift && char == "p" {
            handlePrint()
            return
        }
        if hasCmdOrCtrl && !hasShift && char == "q" {
            handleQuit()
            return
        }
        
        // Edit menu shortcuts
        if hasCmdOrCtrl && !hasShift && char == "z" {
            handleUndo()
            return
        }
        if hasCmdOrCtrl && !hasShift && char == "y" {
            handleRedo()
            return
        }
        if hasCmdOrCtrl && !hasShift && char == "x" {
            handleCut()
            return
        }
        if hasCmdOrCtrl && !hasShift && char == "c" {
            handleCopy()
            return
        }
        if hasCmdOrCtrl && !hasShift && char == "v" {
            handlePaste()
            return
        }
        if hasCmdOrCtrl && !hasShift && char == "a" {
            handleSelectAll()
            return
        }
        if hasCmdOrCtrl && !hasShift && char == "f" {
            handleFind()
            return
        }
        if hasCmdOrCtrl && !hasShift && char == "h" {
            handleReplace()
            return
        }
        if hasCmdOrCtrl && !hasShift && char == "g" {
            handleGoTo()
            return
        }
        
        // Zoom shortcuts (both Cmd and Ctrl)
        if hasCmdOrCtrl && !hasShift && char == "=" {
            handleZoomIn()
            return
        }
        if hasCmdOrCtrl && !hasShift && char == "-" {
            handleZoomOut()
            return
        }
        if hasCmdOrCtrl && !hasShift && char == "0" {
            handleResetZoom()
            return
        }
        
        // F5 for Time/Date insertion (no modifier)
        if event.keyCode == 0x3E { // F5 key
            handleInsertTimeDate()
            return
        }
        
        // Option+letter for menu accelerators
        if hasOption && !hasCmd && !hasCtrl {
            if let char = char {
                handleAltAccelerator(char)
                return
            }
        }
        
        // F3 and Shift+F3 for Find Next/Previous (no modifier)
        if event.keyCode == 0x31 { // F3 key
            if hasShift {
                handleFindPrevious()
            } else {
                handleFindNext()
            }
            return
        }
    }
    
    // MARK: - Action Handlers
    
    private static func handleNewWindow() {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.newWindowAction?()
        } else {
            // Fallback: use notification pattern
            NotificationCenter.default.post(name: .newWindowShortcut, object: nil)
        }
    }
    
    private static func handleOpen() {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.openAction?()
        } else {
            NotificationCenter.default.post(name: .openShortcut, object: nil)
        }
    }
    
    private static func handleSave() {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.saveAction?()
        } else {
            NotificationCenter.default.post(name: .saveShortcut, object: nil)
        }
    }
    
    private static func handleSaveAs() {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.saveAsAction?()
        } else {
            NotificationCenter.default.post(name: .saveAsShortcut, object: nil)
        }
    }
    
    private static func handlePrint() {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.printAction?()
        } else {
            NotificationCenter.default.post(name: .printShortcut, object: nil)
        }
    }
    
    private static func handleQuit() {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.quitApp()
        } else {
            NSApplication.shared.terminate(nil)
        }
    }
    
    private static func handleUndo() {
        NotificationCenter.default.post(name: .undoShortcut, object: nil)
    }
    
    private static func handleRedo() {
        NotificationCenter.default.post(name: .redoShortcut, object: nil)
    }
    
    private static func handleCut() {
        NotificationCenter.default.post(name: .cutShortcut, object: nil)
    }
    
    private static func handleCopy() {
        NotificationCenter.default.post(name: .copyShortcut, object: nil)
    }
    
    private static func handlePaste() {
        NotificationCenter.default.post(name: .pasteShortcut, object: nil)
    }
    
    private static func handleDelete() {
        NotificationCenter.default.post(name: .deleteShortcut, object: nil)
    }
    
    private static func handleSelectAll() {
        NotificationCenter.default.post(name: .selectAllShortcut, object: nil)
    }
    
    private static func handleFind() {
        NotificationCenter.default.post(name: .findShortcut, object: nil)
    }
    
    private static func handleFindNext() {
        NotificationCenter.default.post(name: .findNextShortcut, object: nil)
    }
    
    private static func handleFindPrevious() {
        NotificationCenter.default.post(name: .findPreviousShortcut, object: nil)
    }
    
    private static func handleReplace() {
        NotificationCenter.default.post(name: .replaceShortcut, object: nil)
    }
    
    private static func handleGoTo() {
        NotificationCenter.default.post(name: .goToShortcut, object: nil)
    }
    
    private static func handleZoomIn() {
        NotificationCenter.default.post(name: .zoomInShortcut, object: nil)
    }
    
    private static func handleZoomOut() {
        NotificationCenter.default.post(name: .zoomOutShortcut, object: nil)
    }
    
    private static func handleResetZoom() {
        NotificationCenter.default.post(name: .resetZoomShortcut, object: nil)
    }
    
    private static func handleInsertTimeDate() {
        NotificationCenter.default.post(name: .timeDateShortcut, object: nil)
    }
    
    private static func handleAltAccelerator(_ char: String) {
        // Map accelerator letters to menu titles (case insensitive)
        let menuMap: [String: String] = [
            "f": "File",
            "e": "Edit", 
            "o": "Format",
            "v": "View",
            "h": "Help"
        ]
        
        if let menuTitle = menuMap[char.lowercased()] {
            // If a menu is currently open, try to trigger the item directly
            if MenuStateManager.isOpen {
                triggerMenuItemInOpenMenu(char)
            } else {
                // Otherwise, open the corresponding menu
                openMenuByTitle(menuTitle)
            }
        }
    }
    
    private static func openMenuByTitle(_ title: String) {
        if let window = NSApplication.shared.keyWindow,
           let contentView = window.contentView,
           let menuBarView = findInWindowMenuBarView(in: contentView) {
            // Find the corresponding menu item
            for menuItem in menuBarView.menuItems {
                if menuItem.title == title {
                    let point = NSPoint(x: menuItem.frame.minX, y: menuItem.frame.minY)
                    menuBarView.popUpMenu(for: menuItem, at: point)
                    return
                }
            }
        }
    }
    
    private static func triggerMenuItemInOpenMenu(_ char: String) {
        // Find the currently open menu and trigger the matching item
        if let window = NSApplication.shared.keyWindow {
            // Look for any open menu in the window
            findAndTriggerMenuItem(char.lowercased(), in: window.contentView ?? NSView())
        }
    }
    
    private static func findAndTriggerMenuItem(_ char: String, in view: NSView) {
        // Check if this view is a menu and has items
        if let menu = view as? NSMenu {
            for menuItem in menu.items {
                let keyEquivalent = menuItem.keyEquivalent
                if !keyEquivalent.isEmpty,
                   keyEquivalent.lowercased() == char,
                   menuItem.isEnabled {
                    if let action = menuItem.action {
                        _ = menuItem.target?.perform(action, with: menuItem)
                        return
                    }
                }
            }
        }
        
        // Recursively search subviews (for nested menu views)
        for subview in view.subviews {
            findAndTriggerMenuItem(char, in: subview)
        }
    }
    
    private static func findInWindowMenuBarView(in view: NSView) -> InWindowMenuBarView? {
        if let menuBarView = view as? InWindowMenuBarView {
            return menuBarView
        }
        for subview in view.subviews {
            if let result = findInWindowMenuBarView(in: subview) {
                return result
            }
        }
        return nil
    }
}

// MARK: - Menu State Manager

class MenuStateManager {
    static var isOpen: Bool = false
    
    static func menuOpened() {
        isOpen = true
    }
    
    static func menuClosed() {
        isOpen = false
    }
}



// MARK: - Notification Names
extension Notification.Name {
    static let newWindowShortcut = Notification.Name("newWindowShortcut")
    static let openShortcut = Notification.Name("openShortcut")
    static let saveShortcut = Notification.Name("saveShortcut")
    static let saveAsShortcut = Notification.Name("saveAsShortcut")
    static let printShortcut = Notification.Name("printShortcut")
    static let undoShortcut = Notification.Name("undoShortcut")
    static let redoShortcut = Notification.Name("redoShortcut")
    static let cutShortcut = Notification.Name("cutShortcut")
    static let copyShortcut = Notification.Name("copyShortcut")
    static let pasteShortcut = Notification.Name("pasteShortcut")
    static let deleteShortcut = Notification.Name("deleteShortcut")
    static let selectAllShortcut = Notification.Name("selectAllShortcut")
    static let findShortcut = Notification.Name("findShortcut")
    static let findNextShortcut = Notification.Name("findNextShortcut")
    static let findPreviousShortcut = Notification.Name("findPreviousShortcut")
    static let replaceShortcut = Notification.Name("replaceShortcut")
    static let goToShortcut = Notification.Name("goToShortcut")
    static let zoomInShortcut = Notification.Name("zoomInShortcut")
    static let zoomOutShortcut = Notification.Name("zoomOutShortcut")
    static let resetZoomShortcut = Notification.Name("resetZoomShortcut")
    static let timeDateShortcut = Notification.Name("timeDateShortcut")
}
