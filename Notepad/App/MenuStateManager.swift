import AppKit

class MenuStateManager {
    static var isMenuOpen: Bool = false
    
    static func menuOpened() {
        isMenuOpen = true
    }
    
    static func menuClosed() {
        isMenuOpen = false
    }
}