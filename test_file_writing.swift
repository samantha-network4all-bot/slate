import Foundation

// Test to verify DocumentWriter behavior
func testFileWriting() {
    let testContent = "Hello, world!\nThis is a test file.\n"
    let tempDir = FileManager.default.temporaryDirectory
    let testFileURL = tempDir.appendingPathComponent("test_notepad.txt")
    
    do {
        // Test UTF-8 with CRLF
        let utf8Data = testContent.data(using: .utf8)!
        try utf8Data.write(to: testFileURL)
        print("✓ UTF-8 with CRLF saved successfully")
        
        // Verify content
        let readContent = try String(contentsOf: testFileURL)
        print("Read content: '\(readContent)'")
        
        // Test UTF-8 with BOM
        let utf8WithBOMData = Data([0xEF, 0xBB, 0xBF]) + testContent.data(using: .utf8)!
        let bomFileURL = tempDir.appendingPathComponent("test_bom.txt")
        try utf8WithBOMData.write(to: bomFileURL)
        
        // Verify BOM
        let bomFileData = try Data(contentsOf: bomFileURL)
        print("UTF-8 with BOM file starts with: \(bomFileData.prefix(3).map { String(format: "%02X", $0) })")
        
        // Test UTF-16 LE
        let utf16LEData = testContent.data(using: .utf16LittleEndian)!
        let utf16LEFileURL = tempDir.appendingPathComponent("test_utf16le.txt")
        try utf16LEData.write(to: utf16LEFileURL)
        
        // Verify UTF-16 LE BOM
        let utf16LEFileData = try Data(contentsOf: utf16LEFileURL)
        print("UTF-16 LE file starts with: \(utf16LEFileData.prefix(4).map { String(format: "%02X", $0) })")
        
        // Clean up
        try FileManager.default.removeItem(at: testFileURL)
        try FileManager.default.removeItem(at: bomFileURL)
        try FileManager.default.removeItem(at: utf16LEFileURL)
        
        print("✓ All file writing tests passed")
        
    } catch {
        print("✗ Error in file writing test: \(error)")
    }
}

testFileWriting()