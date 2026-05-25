import AppKit

class EditorScrollView: NSScrollView {
    private(set) var editor: EditorView!

    override init(frame: NSRect) {
        super.init(frame: frame)

        let editorView = EditorView(frame: frame, textContainer: nil)
        self.editor = editorView
        documentView = editorView

        // PRD §3: textContainerInset = (4, 4)
        editor.textContainerInset = NSSize(width: 4, height: 4)

        hasVerticalScroller = true
        hasHorizontalScroller = true
        autohidesScrollers = true
        borderType = .noBorder
        backgroundColor = Colors.editorBg

    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
