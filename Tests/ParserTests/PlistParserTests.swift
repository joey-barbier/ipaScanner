import XCTest
import Foundation
@testable import Parser
@testable import IPAFoundation

final class PlistParserTests: XCTestCase {
    var parser: PlistParser!
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        parser = PlistParser()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlistParserTests_\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    func testParseValidPlist() throws {
        let plistContent: [String: Any] = [
            "CFBundleIdentifier": "com.example.testapp",
            "CFBundleName": "Test App",
            "CFBundleVersion": "1.0",
            "CFBundleShortVersionString": "1.0.0",
            "CFBundleExecutable": "TestApp"
        ]
        
        let plistURL = tempDirectory.appendingPathComponent("Info.plist")
        let plistData = try PropertyListSerialization.data(fromPropertyList: plistContent, format: .xml, options: 0)
        try plistData.write(to: plistURL)
        
        let result = try parser.parsePlist(at: plistURL)
        
        XCTAssertEqual(result["CFBundleIdentifier"] as? String, "com.example.testapp")
        XCTAssertEqual(result["CFBundleName"] as? String, "Test App")
    }
    
    func testExtractAppInfoFromPlist() {
        let plistContent: [String: Any] = [
            "CFBundleIdentifier": "com.example.testapp",
            "CFBundleName": "Test App",
            "CFBundleVersion": "123",
            "CFBundleShortVersionString": "1.2.3",
            "CFBundleExecutable": "TestApp",
            "MinimumOSVersion": "14.0",
            "UIDeviceFamily": [1, 2]
        ]
        
        let appInfo = parser.extractAppInfo(from: plistContent)
        
        XCTAssertEqual(appInfo.bundleIdentifier, "com.example.testapp")
        XCTAssertEqual(appInfo.bundleName, "Test App")
        XCTAssertEqual(appInfo.bundleVersion, "123")
        XCTAssertEqual(appInfo.bundleShortVersion, "1.2.3")
        XCTAssertEqual(appInfo.executableName, "TestApp")
        XCTAssertEqual(appInfo.minimumOSVersion, "14.0")
        XCTAssertTrue(appInfo.supportedDevices.contains("iPhone"))
        XCTAssertTrue(appInfo.supportedDevices.contains("iPad"))
    }
    
    func testFileNotFoundError() {
        let nonExistentURL = tempDirectory.appendingPathComponent("nonexistent.plist")
        
        XCTAssertThrowsError(try parser.parsePlist(at: nonExistentURL)) { error in
            guard case IPAScannerError.fileNotFound = error else {
                XCTFail("Expected fileNotFound error")
                return
            }
        }
    }
}