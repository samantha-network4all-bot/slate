import XCTest
@testable import Notepad

final class ZoomControllerTests: XCTestCase {
    
    // MARK: - Zoom In tests
    
    func test_zoomInFrom100() throws {
        let result = ZoomController.zoomIn(from: 100)
        XCTAssertEqual(result, 110)
    }
    
    func test_zoomInFrom110() throws {
        let result = ZoomController.zoomIn(from: 110)
        XCTAssertEqual(result, 125)
    }
    
    func test_zoomInFrom125() throws {
        let result = ZoomController.zoomIn(from: 125)
        XCTAssertEqual(result, 150)
    }
    
    func test_zoomInFrom150() throws {
        let result = ZoomController.zoomIn(from: 150)
        XCTAssertEqual(result, 175)
    }
    
    func test_zoomInFrom175() throws {
        let result = ZoomController.zoomIn(from: 175)
        XCTAssertEqual(result, 200)
    }
    
    func test_zoomInFrom200() throws {
        let result = ZoomController.zoomIn(from: 200)
        XCTAssertEqual(result, 250)
    }
    
    func test_zoomInFrom250() throws {
        let result = ZoomController.zoomIn(from: 250)
        XCTAssertEqual(result, 300)
    }
    
    func test_zoomInFrom300() throws {
        let result = ZoomController.zoomIn(from: 300)
        XCTAssertEqual(result, 400)
    }
    
    func test_zoomInFrom400() throws {
        let result = ZoomController.zoomIn(from: 400)
        XCTAssertEqual(result, 500)
    }
    
    func test_zoomInFrom500() throws {
        // At maximum, zoom in should be a no-op
        let result = ZoomController.zoomIn(from: 500)
        XCTAssertEqual(result, 500)
    }
    
    // MARK: - Zoom Out tests
    
    func test_zoomOutFrom100() throws {
        let result = ZoomController.zoomOut(from: 100)
        XCTAssertEqual(result, 90)
    }
    
    func test_zoomOutFrom90() throws {
        let result = ZoomController.zoomOut(from: 90)
        XCTAssertEqual(result, 80)
    }
    
    func test_zoomOutFrom80() throws {
        let result = ZoomController.zoomOut(from: 80)
        XCTAssertEqual(result, 75)
    }
    
    func test_zoomOutFrom75() throws {
        let result = ZoomController.zoomOut(from: 75)
        XCTAssertEqual(result, 67)
    }
    
    func test_zoomOutFrom67() throws {
        let result = ZoomController.zoomOut(from: 67)
        XCTAssertEqual(result, 50)
    }
    
    func test_zoomOutFrom50() throws {
        let result = ZoomController.zoomOut(from: 50)
        XCTAssertEqual(result, 33)
    }
    
    func test_zoomOutFrom33() throws {
        let result = ZoomController.zoomOut(from: 33)
        XCTAssertEqual(result, 25)
    }
    
    func test_zoomOutFrom25() throws {
        let result = ZoomController.zoomOut(from: 25)
        XCTAssertEqual(result, 20)
    }
    
    func test_zoomOutFrom20() throws {
        let result = ZoomController.zoomOut(from: 20)
        XCTAssertEqual(result, 15)
    }
    
    func test_zoomOutFrom15() throws {
        let result = ZoomController.zoomOut(from: 15)
        XCTAssertEqual(result, 10)
    }
    
    func test_zoomOutFrom10() throws {
        // At minimum, zoom out should be a no-op
        let result = ZoomController.zoomOut(from: 10)
        XCTAssertEqual(result, 10)
    }
    
    // MARK: - Full table traversal tests
    
    func test_fullZoomInTraversal() throws {
        var current = 100
        let expectedSequence = [110, 125, 150, 175, 200, 250, 300, 400, 500]
        
        for expected in expectedSequence {
            current = ZoomController.zoomIn(from: current)
            XCTAssertEqual(current, expected, "Zoom in from \(current - 1) should result in \(expected)")
        }
        
        // Should be capped at 500
        current = ZoomController.zoomIn(from: current)
        XCTAssertEqual(current, 500)
    }
    
    func test_fullZoomOutTraversal() throws {
        var current = 100
        let expectedSequence = [90, 80, 75, 67, 50, 33, 25, 20, 15, 10]
        
        for expected in expectedSequence {
            current = ZoomController.zoomOut(from: current)
            XCTAssertEqual(current, expected, "Zoom out from \(expected + (expected == 90 ? 10 : expected == 80 ? 20 : 25)) should result in \(expected)")
        }
        
        // Should be capped at 10
        current = ZoomController.zoomOut(from: current)
        XCTAssertEqual(current, 10)
    }
    
    // MARK: - Restore Default tests
    
    func test_restoreDefaultFromAnyLevel() throws {
        let testLevels = [10, 50, 100, 200, 500]
        
        for level in testLevels {
            let result = ZoomController.restoreDefault()
            XCTAssertEqual(result, 100, "Restore default from \(level) should return 100")
        }
    }
    
    func test_restoreDefaultReturns100() throws {
        let result = ZoomController.restoreDefault()
        XCTAssertEqual(result, 100)
    }
    
    // MARK: - Edge cases
    
    func test_zoomInFromNonLevel() throws {
        // Test with a value not in the levels array
        let result = ZoomController.zoomIn(from: 123)
        XCTAssertEqual(result, 123) // Should return the same value
    }
    
    func test_zoomOutFromNonLevel() throws {
        // Test with a value not in the levels array
        let result = ZoomController.zoomOut(from: 123)
        XCTAssertEqual(result, 123) // Should return the same value
    }
    
    func test_levelsArrayIsCorrect() throws {
        let expectedLevels = [10, 15, 20, 25, 33, 50, 67, 75, 80, 90, 100, 110, 125, 150, 175, 200, 250, 300, 400, 500]
        let actualLevels = ZoomController.levels
        
        XCTAssertEqual(actualLevels, expectedLevels, "Levels array should match the specification")
        
        // Verify the sequence is properly ordered
        for i in 1..<actualLevels.count {
            XCTAssertTrue(actualLevels[i] > actualLevels[i-1], "Levels should be in ascending order")
        }
    }
}