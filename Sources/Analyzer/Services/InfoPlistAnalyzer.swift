import Foundation
import IPAFoundation

public class InfoPlistAnalyzer {
    
    public init() {}
    
    public func analyzeInfoPlist(_ plist: [String: Any]) -> InfoPlistAnalysis {
        let backgroundModes = extractBackgroundModes(from: plist)
        let capabilities = extractCapabilities(from: plist)
        let permissions = extractPermissions(from: plist)
        let privacyKeys = extractPrivacyKeys(from: plist)
        
        let unusedFeatures = detectUnusedFeatures(
            backgroundModes: backgroundModes,
            capabilities: capabilities,
            permissions: permissions
        )
        
        let estimatedWaste = calculateEstimatedWaste(
            unusedFeatures: unusedFeatures,
            backgroundModes: backgroundModes
        )
        
        return InfoPlistAnalysis(
            backgroundModes: backgroundModes,
            capabilities: capabilities,
            permissions: permissions,
            unusedFeatures: unusedFeatures,
            privacyKeys: privacyKeys,
            estimatedWaste: estimatedWaste
        )
    }
    
    private func extractBackgroundModes(from plist: [String: Any]) -> [String] {
        guard let backgroundModes = plist["UIBackgroundModes"] as? [String] else {
            return []
        }
        return backgroundModes
    }
    
    private func extractCapabilities(from plist: [String: Any]) -> [String] {
        var capabilities: [String] = []
        
        // UIRequiredDeviceCapabilities
        if let required = plist["UIRequiredDeviceCapabilities"] as? [String] {
            capabilities.append(contentsOf: required.map { "required: \($0)" })
        } else if let requiredDict = plist["UIRequiredDeviceCapabilities"] as? [String: Any] {
            capabilities.append(contentsOf: requiredDict.keys.map { "required: \($0)" })
        }
        
        // Check for specific capabilities in other keys
        if plist["NSLocationWhenInUseUsageDescription"] != nil ||
           plist["NSLocationAlwaysAndWhenInUseUsageDescription"] != nil {
            capabilities.append("location-services")
        }
        
        if plist["NSCameraUsageDescription"] != nil {
            capabilities.append("camera")
        }
        
        if plist["NSMicrophoneUsageDescription"] != nil {
            capabilities.append("microphone")
        }
        
        if plist["NSPhotoLibraryUsageDescription"] != nil {
            capabilities.append("photo-library")
        }
        
        return capabilities
    }
    
    private func extractPermissions(from plist: [String: Any]) -> [String] {
        var permissions: [String] = []
        
        let permissionKeys = [
            "NSCameraUsageDescription": "Camera",
            "NSMicrophoneUsageDescription": "Microphone", 
            "NSLocationWhenInUseUsageDescription": "Location (When In Use)",
            "NSLocationAlwaysAndWhenInUseUsageDescription": "Location (Always)",
            "NSPhotoLibraryUsageDescription": "Photo Library",
            "NSPhotoLibraryAddUsageDescription": "Photo Library (Add)",
            "NSContactsUsageDescription": "Contacts",
            "NSCalendarsUsageDescription": "Calendars",
            "NSRemindersUsageDescription": "Reminders",
            "NSMotionUsageDescription": "Motion & Fitness",
            "NSHealthShareUsageDescription": "Health (Read)",
            "NSHealthUpdateUsageDescription": "Health (Write)",
            "NSBluetoothAlwaysUsageDescription": "Bluetooth",
            "NSBluetoothPeripheralUsageDescription": "Bluetooth Peripheral",
            "NSLocalNetworkUsageDescription": "Local Network",
            "NSNearbyInteractionUsageDescription": "Nearby Interaction",
            "NSSpeechRecognitionUsageDescription": "Speech Recognition",
            "NSAppleMusicUsageDescription": "Apple Music",
            "NSFaceIDUsageDescription": "Face ID",
            "NSUserTrackingUsageDescription": "App Tracking Transparency"
        ]
        
        for (key, description) in permissionKeys {
            if plist[key] != nil {
                permissions.append(description)
            }
        }
        
        return permissions
    }
    
    private func extractPrivacyKeys(from plist: [String: Any]) -> [String] {
        let privacyKeys = plist.keys.filter { key in
            key.hasPrefix("NS") && key.hasSuffix("UsageDescription")
        }
        return Array(privacyKeys)
    }
    
    private func detectUnusedFeatures(
        backgroundModes: [String],
        capabilities: [String], 
        permissions: [String]
    ) -> [String] {
        var unused: [String] = []
        
        // Detect potentially unused background modes
        let suspiciousBackgroundModes = [
            "background-app-refresh",
            "background-processing", 
            "remote-notification"
        ]
        
        for mode in backgroundModes {
            if suspiciousBackgroundModes.contains(mode) {
                unused.append("Background Mode: \(mode)")
            }
        }
        
        // Detect over-privileged permissions
        let heavyPermissions = [
            "Location (Always)",
            "Camera",
            "Microphone",
            "Photo Library",
            "Contacts",
            "Health (Write)",
            "App Tracking Transparency"
        ]
        
        for permission in permissions {
            if heavyPermissions.contains(permission) {
                unused.append("Heavy Permission: \(permission)")
            }
        }
        
        return unused
    }
    
    private func calculateEstimatedWaste(
        unusedFeatures: [String],
        backgroundModes: [String]
    ) -> Int64 {
        // Estimate impact on app review time, not binary size
        // Background modes can add complexity without size impact
        var waste: Int64 = 0
        
        // Each unused background mode = ~1KB of plist overhead
        waste += Int64(backgroundModes.count * 512)
        
        // Each unused permission = ~2KB of metadata and strings
        waste += Int64(unusedFeatures.count * 2048)
        
        return waste
    }
}