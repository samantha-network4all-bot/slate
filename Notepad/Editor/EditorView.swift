import AppKit

class EditorView: NSTextView {
    override init(frame: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frame, textContainer: container)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        isRichText = false
        allowsUndo = true
        isEditable = true
        font = Fonts.editorDefault
        textColor = Colors.editorText
        backgroundColor = Colors.editorBg
        insertionPointColor = .black
        selectedTextAttributes = [
            .backgroundColor: Colors.selectionBg,
            .foregroundColor: Colors.selectionText
        ]
    }
}
