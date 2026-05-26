import Foundation

// Test script to verify status bar popup functionality
// This would be used to programmatically test the EOL and encoding changes

let testContent = "Hello, world!\nThis is a test file.\n"

// Test EOL conversion
func testEOLConversion() {
    let crlfContent = testContent.replacingOccurrences(of: "\n", with: "\r\n")
    let lfContent = testContent // Already LF
    let crContent = testContent.replacingOccurrences(of: "\n", with: "\r")
    
    print("CRLF content: \(crlfContent)")
    print("LF content: \(lfContent)")
    print("CR content: \(crContent)")
}

// Test encoding
func testEncoding() {
    let utf8Data = testContent.data(using: .utf8)!
    let utf8WithBOMData = Data([0xEF, 0xBB, 0xBF]) + utf8Data
    let utf16LEData = testContent.data(using: .utf16LittleEndian)!
    let utf16BEData = testContent.data(using: .utf16BigEndian)!
    
    print("UTF-8 data size: \(utf8Data.count)")
    print("UTF-8 with BOM data size: \(utf8WithBOMData.count)")
    print("UTF-16 LE data size: \(utf16LEData.count)")
    print("UTF-16 BE data size: \(utf16BEData.count)")
}

testEOLConversion()
testEncoding()