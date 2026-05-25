import Foundation

enum Metrics {
    // Title bar
    static let titleBarHeight: CGFloat = 32
    static let titleBarButtonWidth: CGFloat = 46
    static let titleBarButtonHeight: CGFloat = 32
    static let titleBarIconSize: CGFloat = 10            // for the X / _ / □ glyphs
    static let titleBarPaddingLeft: CGFloat = 12

    // Menu bar (in-window)
    static let menuBarHeight: CGFloat = 22
    static let menuItemPaddingH: CGFloat = 8

    // Status bar
    static let statusBarHeight: CGFloat = 22
    static let statusSegmentPaddingH: CGFloat = 8

    // Default window
    static let defaultWindowSize = NSSize(width: 900, height: 700)
    static let topRightInset: CGFloat = 0                 // flush to top-right; just below macOS menu bar

    // Scrollbar
    static let scrollbarThickness: CGFloat = 17           // includes track
    static let scrollbarArrowButtonHeight: CGFloat = 17   // the up/down arrow squares
    static let scrollbarMinThumbLength: CGFloat = 17
}
