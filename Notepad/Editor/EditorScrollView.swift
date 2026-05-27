import AppKit

class EditorScrollView: NSScrollView {
    private(set) var editor: EditorView!

    override init(frame: NSRect) {
        super.init(frame: frame)

        // Create a text container for the editor view
        let textContainer = NSTextContainer()
        textContainer.containerSize = NSSize(width: frame.width, height: frame.height)
        textContainer.widthTracksTextView = false
        textContainer.heightTracksTextView = true
        
        let editorView = EditorView(frame: frame, textContainer: textContainer)
        self.editor = editorView
        documentView = editorView

        // PRD §3: textContainerInset = (4, 4)
        editor.textContainerInset = NSSize(width: 4, height: 4)

        // Use custom WinScroller and always show scrollbars
        hasVerticalScroller = true
        hasHorizontalScroller = true
        autohidesScrollers = false  // Always visible
        verticalScroller = WinScroller(frame: NSRect(x: 0, y: 0, width: Metrics.scrollbarThickness, height: frame.height))
        horizontalScroller = WinScroller(frame: NSRect(x: 0, y: 0, width: frame.width, height: Metrics.scrollbarThickness))
        
        borderType = .noBorder
        backgroundColor = Colors.editorBg
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: - Drag and Drop
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls {
                if isAcceptableFile(url: url) {
                    return .copy
                }
            }
        }
        return []
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return draggingEntered(sender)
    }
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            // Handle multiple files
            if let windowController = window?.windowController as? NotepadWindowController {
                windowController.openDraggedFiles(urls)
            }
            return true
        }
        return false
    }
    
    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        // Clean up after drag operation
    }
    
    private func isAcceptableFile(url: URL) -> Bool {
        let pathExtension = url.pathExtension.lowercased()
        let acceptableExtensions = ["txt", "log", "md", "csv", ""] // "" for no extension
        return acceptableExtensions.contains(pathExtension)
    }
}
