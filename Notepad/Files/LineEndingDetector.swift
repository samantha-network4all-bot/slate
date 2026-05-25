import Foundation

enum LineEndingDetector {
    static func detect(in text: String) -> LineEnding {
        var crlf = 0
        var lf = 0
        var cr = 0

        var i = 0
        while i < text.utf16.count {
            let scalar = Array(text.utf16)[i]
            if scalar == 0x0D && i + 1 < text.utf16.count && Array(text.utf16)[i + 1] == 0x0A {
                crlf += 1
                i += 2
            } else if scalar == 0x0A {
                lf += 1
                i += 1
            } else if scalar == 0x0D {
                cr += 1
                i += 1
            } else {
                i += 1
            }
        }

        // Strict majority wins
        if crlf > lf && crlf > cr { return .crlf }
        if lf > crlf && lf > cr { return .lf }
        if cr > crlf && cr > lf { return .cr }

        // Tie-break priority: CRLF > LF > CR
        let maxCount = max(crlf, lf, cr)
        if crlf == maxCount { return .crlf }
        if lf == maxCount { return .lf }
        if cr == maxCount { return .cr }

        // No line endings found
        return .crlf
    }
}
