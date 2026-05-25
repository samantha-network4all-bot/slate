import Foundation

class DocumentWriter {
    static func write(_ text: String, to url: URL, encoding: DocumentEncoding, lineEnding: LineEnding) throws {
        let eolString: String
        switch lineEnding {
        case .crlf: eolString = "\r\n"
        case .lf: eolString = "\n"
        case .cr: eolString = "\r"
        }

        let normalizedText = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n", with: eolString)

        let stringData = normalizedText.data(using: stringEncoding(encoding)) ?? Data()

        var finalData: Data
        switch encoding {
        case .utf8WithBOM:
            finalData = Data([0xEF, 0xBB, 0xBF]) + stringData
        case .utf16LE:
            finalData = Data([0xFF, 0xFE]) + stringData
        case .utf16BE:
            finalData = Data([0xFE, 0xFF]) + stringData
        case .utf8:
            finalData = stringData
        }

        try finalData.write(to: url)
    }

    private static func stringEncoding(_ encoding: DocumentEncoding) -> String.Encoding {
        switch encoding {
        case .utf8, .utf8WithBOM: return .utf8
        case .utf16LE: return .utf16LittleEndian
        case .utf16BE: return .utf16BigEndian
        }
    }
}
