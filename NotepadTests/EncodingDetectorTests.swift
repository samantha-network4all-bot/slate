import XCTest
@testable import Notepad

final class EncodingDetectorTests: XCTestCase {
    // MARK: - UTF-8 detection

    func test_detectUTF8() throws {
        let data = "Hello, world!".data(using: .utf8)!
        let encoding = EncodingDetector.detect(from: data)
        XCTAssertEqual(encoding, .utf8)
    }

    func test_detectUTF8WithBOM() throws {
        let bom = Data([0xEF, 0xBB, 0xBF])
        let text = "Hello, world!".data(using: .utf8)!
        let data = bom + text
        let encoding = EncodingDetector.detect(from: data)
        XCTAssertEqual(encoding, .utf8WithBOM)
    }

    func test_detectUTF16LE() throws {
        let bom = Data([0xFF, 0xFE])
        let text = "Hello".data(using: .utf16LittleEndian)!
        let data = bom + text
        let encoding = EncodingDetector.detect(from: data)
        XCTAssertEqual(encoding, .utf16LE)
    }

    func test_detectUTF16BE() throws {
        let bom = Data([0xFE, 0xFF])
        let text = "Hello".data(using: .utf16BigEndian)!
        let data = bom + text
        let encoding = EncodingDetector.detect(from: data)
        XCTAssertEqual(encoding, .utf16BE)
    }

    // MARK: - Edge cases

    func test_detectEmptyData() throws {
        let data = Data()
        let encoding = EncodingDetector.detect(from: data)
        XCTAssertEqual(encoding, .utf8)
    }

    func test_detectShortData() throws {
        let data = Data([0x48, 0x65]) // "He" in UTF-8
        let encoding = EncodingDetector.detect(from: data)
        XCTAssertEqual(encoding, .utf8)
    }

    func test_detectBOMNotFalsePositiveOnSimilarBytes() throws {
        // Data that starts with bytes similar but not matching any BOM
        let data = Data([0xEF, 0xBB, 0x00]) // not BOM
        let encoding = EncodingDetector.detect(from: data)
        XCTAssertEqual(encoding, .utf8)
    }

    func test_detectBOMNotFalsePositiveOnUTF16LE() throws {
        // Data that starts with 0xFF but is not 0xFF, 0xFE
        let data = Data([0xFF, 0x41]) // 0xFF but next is 'A'
        let encoding = EncodingDetector.detect(from: data)
        XCTAssertEqual(encoding, .utf8)
    }

    func test_detectBOMNotFalsePositiveOnUTF16BE() throws {
        // Data that starts with 0xFE but is not 0xFE, 0xFF
        let data = Data([0xFE, 0x41]) // 0xFE but next is 'A'
        let encoding = EncodingDetector.detect(from: data)
        XCTAssertEqual(encoding, .utf8)
    }

    // MARK: - UTF-8 BOM variants

    func test_detectUTF8WithBOMOnFirstThreeBytes() throws {
        let data = Data([0xEF, 0xBB, 0xBF, 0x48, 0x65, 0x6C, 0x6C, 0x6F])
        let encoding = EncodingDetector.detect(from: data)
        XCTAssertEqual(encoding, .utf8WithBOM)
    }

    func test_detectUTF8WithoutBOM() throws {
        // Same bytes without BOM
        let data = Data([0x48, 0x65, 0x6C, 0x6C, 0x6F])
        let encoding = EncodingDetector.detect(from: data)
        XCTAssertEqual(encoding, .utf8)
    }
}
