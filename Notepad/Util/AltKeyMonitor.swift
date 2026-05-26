import AppKit

class AltKeyMonitor {
    static var isAltDown: Bool = false {
        didSet {
            onAltChange?(isAltDown)
        }
    }
    static var onAltChange: ((Bool) -> Void)?
    private static var eventMonitor: Any?

    static func start() {
        // Monitor for Option key press/release
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            let oldAltState = isAltDown
            let newAltState = event.modifierFlags.contains(.option)
            
            if oldAltState != newAltState {
                isAltDown = newAltState
            }
            
            return event
        }
    }
    
    static func stop() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
