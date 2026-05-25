import Foundation

class LineColumnTracker {
    static func position(text: String, caretOffset: Int) -> (line: Int, column: Int) {
        if text.isEmpty {
            return (line: 1, column: 1)
        }

        let characters = Array(text)
        var line = 1
        var col = 1

        for i in 0..<min(caretOffset, characters.count) {
            if characters[i] == "\n" {
                line += 1
                col = 1
            } else {
                col += 1
            }
        }

        return (line: line, column: col)
    }
}
