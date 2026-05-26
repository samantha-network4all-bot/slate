import AppKit
import Foundation

enum DocumentEncoding: String {
    case utf8 = "UTF-8"
    case utf8WithBOM = "UTF-8 with BOM"
    case utf16LE = "UTF-16 LE"
    case utf16BE = "UTF-16 BE"
}

enum LineEnding: String, CaseIterable {
    case crlf = "Windows (CRLF)"
    case lf = "Unix (LF)"
    case cr = "Macintosh (CR)"
    
    var displayString: String {
        switch self {
        case .crlf: return "Windows (CRLF)"
        case .lf: return "Unix (LF)"
        case .cr: return "Macintosh (CR)"
        }
    }
    
    var eolString: String {
        switch self {
        case .crlf: return "\r\n"
        case .lf: return "\n"
        case .cr: return "\r"
        }
    }
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
