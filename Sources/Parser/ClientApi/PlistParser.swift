import Foundation
import IPAFoundation

public class PlistParser {
    
    public init() {}
    
    public func parsePlist(at url: URL) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw IPAScannerError.fileNotFound(path: url.path)
        }
        
        let data = try Data(contentsOf: url)
        
        guard let plist = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any] else {
            throw IPAScannerError.plistParsingFailed(reason: "Invalid plist format at \(url.path)")
        }
        
        return plist
    }
    
    public func extractAppInfo(from infoPlist: [String: Any]) -> AppInfo {
        AppInfo(
            bundleIdentifier: infoPlist["CFBundleIdentifier"] as? String ?? "Unknown",
            bundleName: infoPlist["CFBundleName"] as? String ?? 
                        infoPlist["CFBundleDisplayName"] as? String ?? "Unknown",
            bundleVersion: infoPlist["CFBundleVersion"] as? String ?? "1.0",
            bundleShortVersion: infoPlist["CFBundleShortVersionString"] as? String ?? "1.0",
            executableName: infoPlist["CFBundleExecutable"] as? String ?? "Unknown",
            minimumOSVersion: infoPlist["MinimumOSVersion"] as? String,
            supportedPlatforms: extractSupportedPlatforms(from: infoPlist),
            supportedDevices: extractSupportedDevices(from: infoPlist)
        )
    }
    
    private func extractSupportedPlatforms(from plist: [String: Any]) -> [String] {
        if let platforms = plist["CFBundleSupportedPlatforms"] as? [String] {
            return platforms
        }
        
        // Fallback to device family
        if let deviceFamily = plist["UIDeviceFamily"] as? [Int] {
            var platforms: [String] = []
            if deviceFamily.contains(1) { platforms.append("iPhone") }
            if deviceFamily.contains(2) { platforms.append("iPad") }
            return platforms.isEmpty ? ["iOS"] : platforms
        }
        
        return ["iOS"]
    }
    
    private func extractSupportedDevices(from plist: [String: Any]) -> [String] {
        var devices: [String] = []
        
        if let deviceFamily = plist["UIDeviceFamily"] as? [Int] {
            if deviceFamily.contains(1) { devices.append("iPhone") }
            if deviceFamily.contains(2) { devices.append("iPad") }
        }
        
        if let capabilities = plist["UIRequiredDeviceCapabilities"] as? [String: Any] {
            if capabilities["watch-companion"] != nil {
                devices.append("Apple Watch")
            }
        }
        
        return devices.isEmpty ? ["Universal"] : devices
    }
}

public struct AppInfo {
    public let bundleIdentifier: String
    public let bundleName: String
    public let bundleVersion: String
    public let bundleShortVersion: String
    public let executableName: String
    public let minimumOSVersion: String?
    public let supportedPlatforms: [String]
    public let supportedDevices: [String]
}