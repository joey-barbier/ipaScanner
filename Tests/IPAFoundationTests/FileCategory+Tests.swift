import XCTest
@testable import IPAFoundation

final class FileCategoryTests: XCTestCase {
    
    func testImageFileDetection() {
        XCTAssertEqual(FileCategory.from(path: "icon.png"), .image)
        XCTAssertEqual(FileCategory.from(path: "photo.jpg"), .image)
        XCTAssertEqual(FileCategory.from(path: "logo.PNG"), .image)
        XCTAssertEqual(FileCategory.from(path: "assets/image.gif"), .image)
    }
    
    func testFrameworkDetection() {
        XCTAssertEqual(FileCategory.from(path: "UIKit.framework"), .framework)
        XCTAssertEqual(FileCategory.from(path: "Frameworks/MyFramework.framework"), .framework)
    }
    
    func testExecutableDetection() {
        XCTAssertEqual(FileCategory.from(path: "Payload/App.app/MyApp"), .executable)
        XCTAssertEqual(FileCategory.from(path: "some/macho"), .executable)
    }
    
    func testLocalizationDetection() {
        XCTAssertEqual(FileCategory.from(path: "en.lproj/Localizable.strings"), .localization)
        XCTAssertEqual(FileCategory.from(path: "fr.lproj/Main.strings"), .localization)
        XCTAssertEqual(FileCategory.from(path: "Localizable.stringsdict"), .localization)
    }
    
    func testPlistDetection() {
        XCTAssertEqual(FileCategory.from(path: "Info.plist"), .plist)
        XCTAssertEqual(FileCategory.from(path: "Settings.plist"), .plist)
    }
    
    func testOtherFiles() {
        XCTAssertEqual(FileCategory.from(path: "unknown.xyz"), .other)
        XCTAssertEqual(FileCategory.from(path: "file_without_extension"), .other)
    }
    
    func testEmojiRepresentation() {
        XCTAssertFalse(FileCategory.image.emoji.isEmpty)
        XCTAssertFalse(FileCategory.framework.emoji.isEmpty)
        XCTAssertFalse(FileCategory.executable.emoji.isEmpty)
    }
}