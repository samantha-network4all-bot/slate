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
                    // CRLF: \r is part of current line, \n causes line break
                    col += 1  // Count the \r as part of current line
                    i += 1    // Skip the \r
                    // Now process the \n
                } else {
                    // Standalone CR: causes line break
                    col += 1  // Count the \r as part of current line
                    line += 1 // Line break
                    col = 1   // Reset column for new line
                }
            } else if characters[i] == "\n" {
                // Standalone LF: causes line break
                col += 1  // Count the \n as part of current line
                line += 1 // Line break
                col = 1   // Reset column for new line
            } else {
                col += 1 // Regular character
            }
            i += 1
        }

        return (line: line, column: col)
    }
}
