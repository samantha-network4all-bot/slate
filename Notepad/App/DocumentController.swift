import AppKit

class DocumentController {
    static let shared = DocumentController()
    private init() {}

    private(set) var windows: [NotepadWindowController] = []

    func newWindow(sourceController: NotepadWindowController? = nil) -> NotepadWindowController {
        let sourceFrame = sourceController?.window?.frame
        let controller = NotepadWindowController(cascadeFrom: sourceFrame)
        windows.append(controller)
        return controller
    }

    func closeWindow(_ controller: NotepadWindowController) {
        if let index = windows.firstIndex(where: { $0 === controller }) {
            windows.remove(at: index)
        }
    }
}
