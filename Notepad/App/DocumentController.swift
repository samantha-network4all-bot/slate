import AppKit

class DocumentController {
    static let shared = DocumentController()
    private init() {}

    private(set) var windows: [NotepadWindowController] = []

    /// Create a new window. If `sourceController` is provided, cascade the frame +22/-22.
    func newWindow(sourceController: NotepadWindowController? = nil) -> NotepadWindowController {
        let controller: NotepadWindowController
        if let source = sourceController, let sourceWindow = source.window {
            let cascaded = NotepadWindowController.cascadedFrame(from: sourceWindow.frame)
            controller = NotepadWindowController(frame: cascaded)
        } else {
            controller = NotepadWindowController()
        }
        windows.append(controller)
        return controller
    }

    func closeWindow(_ controller: NotepadWindowController) {
        if let index = windows.firstIndex(where: { $0 === controller }) {
            windows.remove(at: index)
        }
    }
}
