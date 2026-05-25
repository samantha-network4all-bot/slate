import XCTest
@testable import Notepad

final class DocumentReaderTests: XCTestCase {
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

    // MARK: - Round-trip: write known text, read back, assert encoding + EOL

    // UTF-8 × all EOLs
    func test_roundTrip_UTF8_CRLF() throws {
        try roundTrip(encoding: .utf8, lineEnding: .crlf)
    }

    func test_roundTrip_UTF8_LF() throws {
        try roundTrip(encoding: .utf8, lineEnding: .lf)
    }

    func test_roundTrip_UTF8_CR() throws {
        try roundTrip(encoding: .utf8, lineEnding: .cr)
    }

    // UTF-8 with BOM × all EOLs
    func test_roundTrip_UTF8WithBOM_CRLF() throws {
        try roundTrip(encoding: .utf8WithBOM, lineEnding: .crlf)
    }

    func test_roundTrip_UTF8WithBOM_LF() throws {
        try roundTrip(encoding: .utf8WithBOM, lineEnding: .lf)
    }

    func test_roundTrip_UTF8WithBOM_CR() throws {
        try roundTrip(encoding: .utf8WithBOM, lineEnding: .cr)
    }

    // UTF-16 LE × all EOLs
    func test_roundTrip_UTF16LE_CRLF() throws {
        try roundTrip(encoding: .utf16LE, lineEnding: .crlf)
    }

    func test_roundTrip_UTF16LE_LF() throws {
        try roundTrip(encoding: .utf16LE, lineEnding: .lf)
    }

    func test_roundTrip_UTF16LE_CR() throws {
        try roundTrip(encoding: .utf16LE, lineEnding: .cr)
    }

    // UTF-16 BE × all EOLs
    func test_roundTrip_UTF16BE_CRLF() throws {
        try roundTrip(encoding: .utf16BE, lineEnding: .crlf)
    }

    func test_roundTrip_UTF16BE_LF() throws {
        try roundTrip(encoding: .utf16BE, lineEnding: .lf)
    }

    func test_roundTrip_UTF16BE_CR() throws {
        try roundTrip(encoding: .utf16BE, lineEnding: .cr)
    }

    // MARK: - Empty file

    func test_readEmptyFile() throws {
        let url = tempDir.appendingPathComponent("empty.txt")
        try Data().write(to: url)

        let result = try DocumentReader.read(from: url)
        XCTAssertEqual(result.text, "")
        XCTAssertEqual(result.encoding, .utf8)
        XCTAssertEqual(result.eol, .crlf)
    }

    // MARK: - Helper

    private func roundTrip(encoding: DocumentEncoding, lineEnding: LineEnding) throws {
        let url = tempDir.appendingPathComponent("test.txt")
        let originalText = "Line one\r\nLine two\r\nLine three"

        try DocumentWriter.write(originalText, to: url, encoding: encoding, lineEnding: lineEnding)

        let result = try DocumentReader.read(from: url)

        XCTAssertEqual(result.encoding, encoding, "Encoding mismatch for \(encoding) + \(lineEnding)")
        XCTAssertEqual(result.eol, lineEnding, "EOL mismatch for \(encoding) + \(lineEnding)")
    }
}
