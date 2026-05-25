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

        if crlf > lf && crlf > cr { return .crlf }
        if lf > cr { return .lf }
        if cr > 0 && (crlf == 0 && lf == 0) { return .cr }
        // Tie-break: CRLF > LF > CR
        if crlf >= lf && crlf >= cr { return .crlf }
        if lf >= cr { return .lf }
        return .cr
    }
}
