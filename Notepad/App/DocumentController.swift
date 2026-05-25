import AppKit

class DocumentController {
    static let shared = DocumentController()
    private init() {}

    private(set) var windows: [NotepadWindowController] = []

    func newWindow() -> NotepadWindowController {
        let controller = NotepadWindowController()
        windows.append(controller)
        return controller
    }

    func closeWindow(_ controller: NotepadWindowController) {
        if let index = windows.firstIndex(where: { $0 === controller }) {
            windows.remove(at: index)
        }
    }
}
