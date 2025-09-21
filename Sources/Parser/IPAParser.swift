import Foundation
import IPAFoundation

public class IPAParser: IPAParserProtocol {
    private let extractor: IPAExtractor
    private let plistParser: PlistParser
    private let resourceScanner: ResourceScanner
    
    public init() {
        self.extractor = IPAExtractor()
        self.plistParser = PlistParser()
        self.resourceScanner = ResourceScanner()
    }
    
    public func parse(ipaURL: URL) throws -> IPAContent {
        // Extract IPA
        let extractedPath = try extractor.extract(from: ipaURL)
        
        // Find Payload directory and .app bundle
        let appBundle = try resourceScanner.findPayloadDirectory(in: extractedPath)
        
        // Parse Info.plist
        let infoPlistURL = appBundle.appendingPathComponent("Info.plist")
        let infoPlist = try plistParser.parsePlist(at: infoPlistURL)
        let appInfo = plistParser.extractAppInfo(from: infoPlist)
        
        // Scan all resources
        let files = try resourceScanner.scanResources(in: appBundle)
        let totalSize = resourceScanner.calculateTotalSize(of: files)
        
        return IPAContent(
            bundleIdentifier: appInfo.bundleIdentifier,
            bundleName: appInfo.bundleName,
            bundleVersion: appInfo.bundleVersion,
            bundleShortVersion: appInfo.bundleShortVersion,
            minimumOSVersion: appInfo.minimumOSVersion,
            supportedPlatforms: appInfo.supportedPlatforms,
            executableName: appInfo.executableName,
            extractionPath: extractedPath,
            payloadPath: appBundle,
            infoPlist: infoPlist,
            files: files,
            totalSize: totalSize
        )
    }
    
    public func cleanup() {
        extractor.cleanup()
    }
}
