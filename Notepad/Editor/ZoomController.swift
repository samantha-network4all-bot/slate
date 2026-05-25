import Foundation

class ZoomController {
    private static let levels = [10, 15, 20, 25, 33, 50, 67, 75, 80, 90, 100, 110, 125, 150, 175, 200, 250, 300, 400, 500]

    static func zoomIn(from current: Int) -> Int {
        if let idx = levels.firstIndex(of: current), idx < levels.count - 1 {
            return levels[idx + 1]
        }
        return current
    }

    static func zoomOut(from current: Int) -> Int {
        if let idx = levels.firstIndex(of: current), idx > 0 {
            return levels[idx - 1]
        }
        return current
    }

    static func restoreDefault() -> Int {
        return 100
    }
}
