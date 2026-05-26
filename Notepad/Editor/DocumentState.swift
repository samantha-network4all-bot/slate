import AppKit
import Foundation

enum DocumentEncoding {
    case utf8
    case utf8WithBOM
    case utf16LE
    case utf16BE
}

enum LineEnding {
    case crlf
    case lf
    case cr
}

class DocumentState {
    var text: String = ""
    var url: URL?
    var encoding: DocumentEncoding = .utf8
    var lineEnding: LineEnding = .crlf
    var isDirty: Bool = false
    var zoomLevel: Int = 100
    var isWordWrapEnabled: Bool = false  // Default: off per PRD §5.9

    var title: String {
        let displayName: String
        if let url = url {
            displayName = url.path
        } else {
            displayName = "Untitled"
        }
        if isDirty {
            return "\(displayName) — Modified - Notepad"
        }
        return "\(displayName) - Notepad"
    }
}
