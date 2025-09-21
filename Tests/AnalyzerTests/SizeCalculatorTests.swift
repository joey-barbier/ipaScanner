import XCTest
@testable import Analyzer
@testable import IPAFoundation

final class SizeCalculatorTests: XCTestCase {
    var calculator: SizeCalculator!
    
    override func setUp() {
        super.setUp()
        calculator = SizeCalculator()
    }
    
    func testCalculateCategorySizes() {
        let files: [IPAFile] = [
            IPAFile(path: "icon.png", size: 1024, category: .image),
            IPAFile(path: "photo.jpg", size: 2048, category: .image),
            IPAFile(path: "app.exe", size: 4096, category: .executable),
            IPAFile(path: "config.plist", size: 512, category: .plist)
        ]
        let totalSize: Int64 = 7680 // 1024 + 2048 + 4096 + 512
        
        let categorySizes = calculator.calculateCategorySizes(from: files, totalSize: totalSize)
        
        // Check image category
        let imageMetrics = categorySizes[.image]!
        XCTAssertEqual(imageMetrics.totalSize, 3072) // 1024 + 2048
        XCTAssertEqual(imageMetrics.fileCount, 2)
        XCTAssertEqual(imageMetrics.percentage, 40.0, accuracy: 0.1) // 3072/7680 * 100
        XCTAssertEqual(imageMetrics.largestFile?.size, 2048)
        
        // Check executable category
        let executableMetrics = categorySizes[.executable]!
        XCTAssertEqual(executableMetrics.totalSize, 4096)
        XCTAssertEqual(executableMetrics.fileCount, 1)
        XCTAssertEqual(executableMetrics.percentage, 53.3, accuracy: 0.1) // 4096/7680 * 100
    }
    
    func testFindTopFiles() {
        let files: [IPAFile] = [
            IPAFile(path: "small.txt", size: 100, category: .document),
            IPAFile(path: "large.png", size: 5000, category: .image),
            IPAFile(path: "medium.exe", size: 2000, category: .executable),
            IPAFile(path: "tiny.json", size: 50, category: .json)
        ]
        let totalSize: Int64 = 7150
        
        let topFiles = calculator.findTopFiles(from: files, totalSize: totalSize, limit: 3)
        
        XCTAssertEqual(topFiles.count, 3)
        XCTAssertEqual(topFiles[0].path, "large.png")
        XCTAssertEqual(topFiles[0].size, 5000)
        XCTAssertEqual(topFiles[1].path, "medium.exe")
        XCTAssertEqual(topFiles[1].size, 2000)
        XCTAssertEqual(topFiles[2].path, "small.txt")
        XCTAssertEqual(topFiles[2].size, 100)
    }
    
    func testCalculateResourcesSize() {
        let files: [IPAFile] = [
            IPAFile(path: "icon.png", size: 1024, category: .image),
            IPAFile(path: "sound.mp3", size: 2048, category: .audio),
            IPAFile(path: "app.exe", size: 4096, category: .executable), // Not a resource
            IPAFile(path: "config.plist", size: 512, category: .plist)
        ]
        
        let resourcesSize = calculator.calculateResourcesSize(from: files)
        
        // Should include image, audio, and plist (3584 = 1024 + 2048 + 512)
        XCTAssertEqual(resourcesSize, 3584)
    }
    
    func testCalculateExecutableSize() {
        let files: [IPAFile] = [
            IPAFile(path: "icon.png", size: 1024, category: .image),
            IPAFile(path: "app.exe", size: 4096, category: .executable),
            IPAFile(path: "main", size: 2048, category: .executable)
        ]
        
        let executableSize = calculator.calculateExecutableSize(from: files)
        
        // Should only include executable files (6144 = 4096 + 2048)
        XCTAssertEqual(executableSize, 6144)
    }
    
    func testCalculateFrameworksSize() {
        let files: [IPAFile] = [
            IPAFile(path: "UIKit.framework", size: 1024, category: .framework),
            IPAFile(path: "lib.dylib", size: 2048, category: .library),
            IPAFile(path: "app.exe", size: 4096, category: .executable) // Not a framework
        ]
        
        let frameworksSize = calculator.calculateFrameworksSize(from: files)
        
        // Should include frameworks and libraries (3072 = 1024 + 2048)
        XCTAssertEqual(frameworksSize, 3072)
    }
}