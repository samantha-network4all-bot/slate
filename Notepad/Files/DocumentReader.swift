import Foundation

class DocumentReader {
    static func read(from url: URL) throws -> (text: String, encoding: DocumentEncoding, eol: LineEnding) {
        let data = try Data(contentsOf: url)
        let encoding = EncodingDetector.detect(from: data)

        let text: String
        switch encoding {
        case .utf8, .utf8WithBOM:
            text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1252) ?? ""
        case .utf16LE:
            text = String(data: data, encoding: .utf16LittleEndian) ?? ""
        case .utf16BE:
            text = String(data: data, encoding: .utf16BigEndian) ?? ""
        }

        let eol = LineEndingDetector.detect(in: text)
        return (text, encoding, eol)
    }
}
