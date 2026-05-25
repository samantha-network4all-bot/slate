import Foundation

enum EncodingDetector {
    static func detect(from data: Data) -> DocumentEncoding {
        if data.count >= 3 && data[0] == 0xEF && data[1] == 0xBB && data[2] == 0xBF {
            return .utf8WithBOM
        }
        if data.count >= 2 && data[0] == 0xFF && data[1] == 0xFE {
            return .utf16LE
        }
        if data.count >= 2 && data[0] == 0xFE && data[1] == 0xFF {
            return .utf16BE
        }
        return .utf8
    }
}
