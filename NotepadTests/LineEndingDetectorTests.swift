import XCTest
@testable import Notepad

final class LineEndingDetectorTests: XCTestCase {
    // MARK: - Pure CRLF

    func test_pureCRLF() throws {
        let text = "Hello\r\nWorld\r\n"
        XCTAssertEqual(LineEndingDetector.detect(in: text), .crlf)
    }

    func test_singleCRLF() throws {
        let text = "\r\n"
        XCTAssertEqual(LineEndingDetector.detect(in: text), .crlf)
    }

    // MARK: - Pure LF

    func test_pureLF() throws {
        let text = "Hello\nWorld\n"
        XCTAssertEqual(LineEndingDetector.detect(in: text), .lf)
    }

    func test_singleLF() throws {
        let text = "\n"
        XCTAssertEqual(LineEndingDetector.detect(in: text), .lf)
    }

    // MARK: - Pure CR

    func test_pureCR() throws {
        let text = "Hello\rWorld\r"
        XCTAssertEqual(LineEndingDetector.detect(in: text), .cr)
    }

    func test_singleCR() throws {
        let text = "\r"
        XCTAssertEqual(LineEndingDetector.detect(in: text), .cr)
    }

    // MARK: - Mixed — majority wins

    func test_majorityCRLF() throws {
        // 3 CRLF, 1 LF
        let text = "A\r\nB\r\nC\r\nD\n"
        XCTAssertEqual(LineEndingDetector.detect(in: text), .crlf)
    }

    func test_majorityLF() throws {
        // 3 LF, 1 CRLF
        let text = "A\nB\nC\nD\r\n"
        XCTAssertEqual(LineEndingDetector.detect(in: text), .lf)
    }

    func test_majorityCR() throws {
        // 3 CR, 1 LF
        let text = "A\rB\rC\rD\n"
        XCTAssertEqual(LineEndingDetector.detect(in: text), .cr)
    }

    // MARK: - Tie-break ordering: CRLF > LF > CR

    func test_tieCRLFvsLF() throws {
        // 1 CRLF, 1 LF → tie-break CRLF
        let text = "A\r\nB\n"
        XCTAssertEqual(LineEndingDetector.detect(in: text), .crlf)
    }

    func test_tieCRLFvsCR() throws {
        // 1 CRLF, 1 CR → tie-break CRLF
        let text = "A\r\nB\r"
        XCTAssertEqual(LineEndingDetector.detect(in: text), .crlf)
    }

    func test_tieLFvsCR() throws {
        // 1 LF, 1 CR → tie-break LF
        let text = "A\nB\r"
        XCTAssertEqual(LineEndingDetector.detect(in: text), .lf)
    }

    // MARK: - Empty / no line endings

    func test_emptyInput() throws {
        XCTAssertEqual(LineEndingDetector.detect(in: ""), .crlf)
    }

    func test_noLineEndings() throws {
        let text = "Hello, world."
        XCTAssertEqual(LineEndingDetector.detect(in: text), .crlf)
    }

    // MARK: - Edge cases

    func test_threeWayTie() throws {
        // 1 of each → tie-break CRLF > LF > CR
        let text = "A\r\nB\nC\r"
        XCTAssertEqual(LineEndingDetector.detect(in: text), .crlf)
    }

    func test_mixedThreeWayMajority() throws {
        // 2 CR, 1 CRLF, 1 LF → CR wins
        let text = "A\rB\rC\r\nD\n"
        XCTAssertEqual(LineEndingDetector.detect(in: text), .cr)
    }

    func test_longTextWithMajorityCRLF() throws {
        var text = ""
        for _ in 0..<10 { text += "Line\r\n" }
        text += "Last\n" // 1 LF among 10 CRLF
        XCTAssertEqual(LineEndingDetector.detect(in: text), .crlf)
    }
}
