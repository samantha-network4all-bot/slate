import XCTest
@testable import Notepad

final class DocumentWriterTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString, isDirectory: true
        )
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func dataHasPrefix(_ data: Data, _ prefix: [UInt8]) -> Bool {
        guard data.count >= prefix.count else { return false }
        for (i, byte) in prefix.enumerated() {
            if data[i] != byte { return false }
        }
        return true
    }

    // MARK: - UTF-8 without BOM

    func test_writeUTF8NoBOM() throws {
        let url = tempDir.appendingPathComponent("test.txt")
        let text = "Hello\r\nWorld"
        try DocumentWriter.write(text, to: url, encoding: .utf8, lineEnding: .crlf)

        let data = try Data(contentsOf: url)
        XCTAssertFalse(dataHasPrefix(data, [0xEF, 0xBB, 0xBF]))
        XCTAssertEqual(String(data: data, encoding: .utf8), "Hello\r\nWorld")
    }

    // MARK: - UTF-8 with BOM

    func test_writeUTF8WithBOM() throws {
        let url = tempDir.appendingPathComponent("test_bom.txt")
        let text = "Hello\r\nWorld"
        try DocumentWriter.write(text, to: url, encoding: .utf8WithBOM, lineEnding: .crlf)

        let data = try Data(contentsOf: url)
        XCTAssertTrue(dataHasPrefix(data, [0xEF, 0xBB, 0xBF]))
        let content = String(data: data.subdata(in: 3..<data.count), encoding: .utf8)
        XCTAssertEqual(content, "Hello\r\nWorld")
    }

    // MARK: - UTF-16LE

    func test_writeUTF16LE() throws {
        let url = tempDir.appendingPathComponent("test_utf16le.txt")
        let text = "Hello"
        try DocumentWriter.write(text, to: url, encoding: .utf16LE, lineEnding: .crlf)

        let data = try Data(contentsOf: url)
        XCTAssertTrue(dataHasPrefix(data, [0xFF, 0xFE]))
    }

    // MARK: - UTF-16BE

    func test_writeUTF16BE() throws {
        let url = tempDir.appendingPathComponent("test_utf16be.txt")
        let text = "Hello"
        try DocumentWriter.write(text, to: url, encoding: .utf16BE, lineEnding: .crlf)

        let data = try Data(contentsOf: url)
        XCTAssertTrue(dataHasPrefix(data, [0xFE, 0xFF]))
    }

    // MARK: - Line ending normalization

    func test_writeNormalizesLFtoCRLF() throws {
        let url = tempDir.appendingPathComponent("test_lf.txt")
        let text = "Hello\nWorld"
        try DocumentWriter.write(text, to: url, encoding: .utf8, lineEnding: .crlf)

        let data = try Data(contentsOf: url)
        XCTAssertEqual(String(data: data, encoding: .utf8), "Hello\r\nWorld")
    }

    func test_writeNormalizesCRtoCRLF() throws {
        let url = tempDir.appendingPathComponent("test_cr.txt")
        let text = "Hello\rWorld"
        try DocumentWriter.write(text, to: url, encoding: .utf8, lineEnding: .crlf)

        let data = try Data(contentsOf: url)
        XCTAssertEqual(String(data: data, encoding: .utf8), "Hello\r\nWorld")
    }

    func test_writeNormalizesMixedtoCRLF() throws {
        let url = tempDir.appendingPathComponent("test_mixed.txt")
        let text = "Hello\nWorld\rEnd\r\nLast"
        try DocumentWriter.write(text, to: url, encoding: .utf8, lineEnding: .crlf)

        let data = try Data(contentsOf: url)
        XCTAssertEqual(String(data: data, encoding: .utf8), "Hello\r\nWorld\r\nEnd\r\nLast")
    }

    func test_writeNormalizesMixedtoLF() throws {
        let url = tempDir.appendingPathComponent("test_to_lf.txt")
        let text = "Hello\r\nWorld\rEnd"
        try DocumentWriter.write(text, to: url, encoding: .utf8, lineEnding: .lf)

        let data = try Data(contentsOf: url)
        XCTAssertEqual(String(data: data, encoding: .utf8), "Hello\nWorld\nEnd")
    }

    func test_writeNormalizesMixedtoCR() throws {
        let url = tempDir.appendingPathComponent("test_to_cr.txt")
        let text = "Hello\r\nWorld\nEnd"
        try DocumentWriter.write(text, to: url, encoding: .utf8, lineEnding: .cr)

        let data = try Data(contentsOf: url)
        XCTAssertEqual(String(data: data, encoding: .utf8), "Hello\rWorld\rEnd")
    }

    // MARK: - Round-trip

    func test_writeAndReadRoundTrip() throws {
        let url = tempDir.appendingPathComponent("test_rt.txt")
        let originalText = "Line 1\r\nLine 2\r\nLine 3"
        try DocumentWriter.write(originalText, to: url, encoding: .utf8, lineEnding: .crlf)

        let result = try DocumentReader.read(from: url)
        XCTAssertEqual(result.text, originalText)
        XCTAssertEqual(result.encoding, .utf8)
        XCTAssertEqual(result.eol, .crlf)
    }

    // MARK: - Edge cases

    func test_writeEmptyText() throws {
        let url = tempDir.appendingPathComponent("test_empty.txt")
        try DocumentWriter.write("", to: url, encoding: .utf8, lineEnding: .crlf)

        let data = try Data(contentsOf: url)
        XCTAssertEqual(data.count, 0)
    }

    func test_writeSpecialCharacters() throws {
        let url = tempDir.appendingPathComponent("test_special.txt")
        let text = "Hello world"
        try DocumentWriter.write(text, to: url, encoding: .utf8, lineEnding: .crlf)

        let data = try Data(contentsOf: url)
        XCTAssertEqual(String(data: data, encoding: .utf8), text)
    }
}
