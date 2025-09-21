import XCTest
import Foundation
@testable import App
@testable import IPAFoundation

final class ExportServiceTests: XCTestCase {
    var exportService: ExportService!
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        exportService = ExportService()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExportServiceTests_\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    func testJSONExport() throws {
        let result = createSampleAnalysisResult()
        
        let outputPath = tempDirectory.appendingPathComponent("test_output.json").path
        let finalPath = try exportService.export(result, format: .json, to: outputPath)
        
        XCTAssertEqual(finalPath, outputPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: finalPath))
        
        // Verify the JSON content
        let data = try Data(contentsOf: URL(fileURLWithPath: finalPath))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedResult = try decoder.decode(AnalysisResult.self, from: data)
        
        XCTAssertEqual(decodedResult.bundleIdentifier, result.bundleIdentifier)
        XCTAssertEqual(decodedResult.bundleName, result.bundleName)
    }
    
    func testTextExport() throws {
        let result = createSampleAnalysisResult()
        
        let outputPath = tempDirectory.appendingPathComponent("test_output.txt").path
        let finalPath = try exportService.export(result, format: .text, to: outputPath)
        
        XCTAssertEqual(finalPath, outputPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: finalPath))
        
        // Verify the text content contains expected elements
        let content = try String(contentsOf: URL(fileURLWithPath: finalPath))
        XCTAssertTrue(content.contains("IPA Analysis Report"))
        XCTAssertTrue(content.contains("Test App"))
        XCTAssertTrue(content.contains("com.example.test"))
    }
    
    func testDefaultFilenameGeneration() throws {
        let result = createSampleAnalysisResult()
        
        // Change to temp directory for this test
        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(tempDirectory.path)
        
        defer {
            FileManager.default.changeCurrentDirectoryPath(originalDir)
        }
        
        let finalPath = try exportService.export(result, format: .json, to: nil)
        
        XCTAssertTrue(finalPath.contains("Test_App_analysis_"))
        XCTAssertTrue(finalPath.hasSuffix(".json"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: finalPath))
    }
    
    func testExportToConsole() throws {
        let result = createSampleAnalysisResult()
        
        let consoleOutput = try exportService.exportToConsole(result)
        
        XCTAssertFalse(consoleOutput.isEmpty)
        XCTAssertTrue(consoleOutput.contains("IPA Analysis Report"))
        XCTAssertTrue(consoleOutput.contains("Test App"))
        XCTAssertTrue(consoleOutput.contains("com.example.test"))
    }
    
    func testUnsupportedFormat() {
        let result = createSampleAnalysisResult()
        
        XCTAssertThrowsError(try exportService.export(result, format: .csv, to: "test.csv")) { error in
            guard case IPAScannerError.exportFailed = error else {
                XCTFail("Expected exportFailed error")
                return
            }
        }
    }
    
    private func createSampleAnalysisResult() -> AnalysisResult {
        let metrics = AnalysisMetrics(
            fileCount: 100,
            directoryCount: 20,
            executableSize: 1_000_000,
            resourcesSize: 2_000_000,
            frameworksSize: 500_000,
            localizationCount: 5,
            supportedDevices: ["iPhone", "iPad"],
            minimumOSVersion: "14.0"
        )
        
        let categoryMetrics: [FileCategory: CategoryMetrics] = [
            .image: CategoryMetrics(
                category: .image,
                totalSize: 1_500_000,
                fileCount: 50,
                percentage: 42.8
            )
        ]
        
        return AnalysisResult(
            bundleIdentifier: "com.example.test",
            bundleName: "Test App",
            version: "1.0",
            shortVersion: "1.0.0",
            totalSize: 3_500_000,
            metrics: metrics,
            categorySizes: categoryMetrics,
            topFiles: [],
            frameworks: [],
            architectures: ["arm64"],
            duplicates: [],
            suggestions: []
        )
    }
}