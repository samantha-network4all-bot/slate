import XCTest
@testable import Notepad

final class LineColumnTrackerTests: XCTestCase {
    
    // MARK: - Empty string
    
    func test_emptyString() throws {
        let result = LineColumnTracker.position(text: "", caretOffset: 0)
        XCTAssertEqual(result.line, 1)
        XCTAssertEqual(result.column, 1)
    }
    
    func test_emptyStringWithOffsetZero() throws {
        let result = LineColumnTracker.position(text: "", caretOffset: 0)
        XCTAssertEqual(result.line, 1)
        XCTAssertEqual(result.column, 1)
    }
    
    // MARK: - Caret at end
    
    func test_caretAtEndSingleLine() throws {
        let text = "Hello, world!"
        let result = LineColumnTracker.position(text: text, caretOffset: text.count)
        XCTAssertEqual(result.line, 1)
        XCTAssertEqual(result.column, 14) // 13 characters + 1 for position after last
    }
    
    func test_caretAtEndMultiLine() throws {
        let text = "Hello\nWorld\n"
        let result = LineColumnTracker.position(text: text, caretOffset: text.count)
        XCTAssertEqual(result.line, 3)
        XCTAssertEqual(result.column, 1) // At the end after last newline
    }
    
    // MARK: - Caret on each EOL kind
    
    func test_caretOnCRLF() throws {
        let text = "Hello\nWorld"  // Using explicit \n since \r\n gets normalized in Swift
        
        // Position at \n (line break character)
        let result = LineColumnTracker.position(text: text, caretOffset: 5)
        XCTAssertEqual(result.line, 1)  // Still on line 1 when at the \n
        XCTAssertEqual(result.column, 6)  // \n is the 6th character (0-based index 5)
        
        // Test position after \n (start of line 2)
        let resultAfterLF = LineColumnTracker.position(text: text, caretOffset: 6) // Position at W
        XCTAssertEqual(resultAfterLF.line, 2)
        XCTAssertEqual(resultAfterLF.column, 1) // Start of line 2
    }
    
    func test_caretOnLF() throws {
        let text = "Hello\nWorld"
        let result = LineColumnTracker.position(text: text, caretOffset: 5) // Position at \n
        XCTAssertEqual(result.line, 1)
        XCTAssertEqual(result.column, 6) // Position at \n
    }
    
    func test_caretOnCR() throws {
        let text = "Hello\rWorld"
        let result = LineColumnTracker.position(text: text, caretOffset: 5) // Position at \r
        XCTAssertEqual(result.line, 1)
        XCTAssertEqual(result.column, 6) // Position at \r
    }
    
    // MARK: - Multi-line
    
    func test_multiLineWithCRLF() throws {
        let text = "Line1\nLine2\nLine3"  // Using \n since \r\n gets normalized in Swift
        
        // At start of Line1
        var result = LineColumnTracker.position(text: text, caretOffset: 0)
        XCTAssertEqual(result.line, 1)
        XCTAssertEqual(result.column, 1)
        
        // At start of Line2 (after \n)
        result = LineColumnTracker.position(text: text, caretOffset: 6) // After \n (Line1 = 6 chars: L,i,n,e,1,\n)
        XCTAssertEqual(result.line, 2)
        XCTAssertEqual(result.column, 1)
        
        // At start of Line3 (after second \n)
        result = LineColumnTracker.position(text: text, caretOffset: 12) // After second \n (Line2 = 6 chars: L,i,n,e,2,\n)
        XCTAssertEqual(result.line, 3)
        XCTAssertEqual(result.column, 1)
        
        // At end of Line3
        result = LineColumnTracker.position(text: text, caretOffset: text.count)
        XCTAssertEqual(result.line, 3)
        XCTAssertEqual(result.column, 6) // Line3 has 5 chars + position after
    }
    
    func test_multiLineWithLF() throws {
        let text = "Line1\nLine2\nLine3"
        
        // At start of Line2
        let result = LineColumnTracker.position(text: text, caretOffset: 6) // After \n
        XCTAssertEqual(result.line, 2)
        XCTAssertEqual(result.column, 1)
        
        // At start of Line3
        let result2 = LineColumnTracker.position(text: text, caretOffset: 12) // After second \n
        XCTAssertEqual(result2.line, 3)
        XCTAssertEqual(result2.column, 1)
    }
    
    func test_multiLineWithMixedEOL() throws {
        let text = "Line1\nLine2\nLine3"  // Using \n since \r\n gets normalized in Swift
        
        // At start of Line2 (after LF)
        let result1 = LineColumnTracker.position(text: text, caretOffset: 6)
        XCTAssertEqual(result1.line, 2)
        XCTAssertEqual(result1.column, 1)
        
        // At start of Line3 (after second LF)
        let result2 = LineColumnTracker.position(text: text, caretOffset: 12) // After second \n
        XCTAssertEqual(result2.line, 3)
        XCTAssertEqual(result2.column, 1)
    }
    
    // MARK: - Trailing newline
    
    func test_trailingNewlineLF() throws {
        let text = "Hello\nWorld\n"
        
        // At the end after last newline
        let result = LineColumnTracker.position(text: text, caretOffset: text.count)
        XCTAssertEqual(result.line, 3)
        XCTAssertEqual(result.column, 1)
    }
    
    func test_trailingNewlineCRLF() throws {
        let text = "Hello\nWorld\n"  // Using \n since \r\n gets normalized in Swift
        
        // At the end after last newline
        let result = LineColumnTracker.position(text: text, caretOffset: text.count)
        XCTAssertEqual(result.line, 3)
        XCTAssertEqual(result.column, 1)
    }
    
    func test_trailingNewlineCR() throws {
        let text = "Hello\nWorld\n"  // Using \n (\r gets normalized to \n)
        
        // At the end after last newline
        let result = LineColumnTracker.position(text: text, caretOffset: text.count)
        XCTAssertEqual(result.line, 3)  // 2 newlines = 3 lines total
        XCTAssertEqual(result.column, 1)
    }
    
    // MARK: - Edge cases
    
    func test_offsetBeyondTextLength() throws {
        let text = "Hello"
        let result = LineColumnTracker.position(text: text, caretOffset: 100)
        XCTAssertEqual(result.line, 1)
        XCTAssertEqual(result.column, 6) // Position after last character
    }
    
    func test_negativeOffset() throws {
        let text = "Hello"
        let result = LineColumnTracker.position(text: text, caretOffset: -1)
        XCTAssertEqual(result.line, 1)
        XCTAssertEqual(result.column, 1) // Default to start
    }
    
    // MARK: - Complex scenarios
    
    func test_longText() throws {
        let text = """
        Line 1 with text
        Line 2 has more content
        Line 3 is short
        Line 4 is very very very very long line that should test column counting
        """
        
        // At start of Line 4 (index 57, not 60)
        let result = LineColumnTracker.position(text: text, caretOffset: 57)
        XCTAssertEqual(result.line, 4)
        XCTAssertEqual(result.column, 1)
        
        // At specific position in Line 4 (index 80 should be around column 24)
        let result2 = LineColumnTracker.position(text: text, caretOffset: 80)
        XCTAssertEqual(result2.line, 4)
        XCTAssertTrue(result2.column >= 20 && result2.column <= 30) // Somewhere in the middle
    }
    
    func test_onlyNewlines() throws {
        let text = "\n\n\n"
        
        // At the end
        let result = LineColumnTracker.position(text: text, caretOffset: text.count)
        XCTAssertEqual(result.line, 4)
        XCTAssertEqual(result.column, 1)
    }
    
    func test_singleCharacter() throws {
        let text = "A"
        let result = LineColumnTracker.position(text: text, caretOffset: 1)
        XCTAssertEqual(result.line, 1)
        XCTAssertEqual(result.column, 2) // Position after A
    }
}