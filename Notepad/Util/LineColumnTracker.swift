import Foundation

class LineColumnTracker {
    static func position(text: String, caretOffset: Int) -> (line: Int, column: Int) {
        if text.isEmpty {
            return (line: 1, column: 1)
        }

        let characters = Array(text)
        var line = 1
        var col = 1
        var i = 0
        while i < min(caretOffset, characters.count) {
            if characters[i] == "\r" {
                // Check if this is part of a CRLF sequence
                if i + 1 < characters.count && characters[i + 1] == "\n" {
                    // CRLF counts as one line break
                    line += 1
                    col = 1
                    // Skip the \n in the next iteration
                    i += 1
                } else {
                    // Standalone CR
                    line += 1
                    col = 1
                }
            } else if characters[i] == "\n" {
                // Standalone LF
                line += 1
                col = 1
            } else {
                col += 1
            }
            i += 1
        }

        return (line: line, column: col)
    }
}
