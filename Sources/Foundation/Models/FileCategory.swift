import Foundation

public enum FileCategory: String, CaseIterable, Codable, Sendable {
    case executable = "Executable"
    case framework = "Framework"
    case library = "Library"
    case image = "Image"
    case video = "Video"
    case audio = "Audio"
    case font = "Font"
    case localization = "Localization"
    case plist = "PropertyList"
    case json = "JSON"
    case xml = "XML"
    case storyboard = "Storyboard"
    case xib = "XIB"
    case coreData = "CoreData"
    case certificate = "Certificate"
    case provisioning = "Provisioning"
    case swift = "Swift"
    case objectiveC = "ObjectiveC"
    case header = "Header"
    case archive = "Archive"
    case document = "Document"
    case other = "Other"
    
    public static func from(path: String) -> FileCategory {
        let pathLower = path.lowercased()
        let ext = (pathLower as NSString).pathExtension
        
        // Executable
        if pathLower.contains("/macho") || ext.isEmpty && pathLower.contains("payload") {
            return .executable
        }
        
        // Frameworks and libraries
        if pathLower.contains(".framework") { return .framework }
        if ext == "dylib" || ext == "a" { return .library }
        
        // Media files
        if ["png", "jpg", "jpeg", "gif", "webp", "heic", "svg", "pdf", "ico", "car"].contains(ext) {
            return .image
        }
        if ["mp4", "mov", "avi", "mkv", "m4v", "webm"].contains(ext) {
            return .video
        }
        if ["mp3", "aac", "wav", "m4a", "flac", "ogg", "aiff", "caf"].contains(ext) {
            return .audio
        }
        
        // Fonts
        if ["ttf", "otf", "ttc", "woff", "woff2"].contains(ext) {
            return .font
        }
        
        // Localization
        if pathLower.contains(".lproj") || ext == "strings" || ext == "stringsdict" {
            return .localization
        }
        
        // Configuration and data
        if ext == "plist" { return .plist }
        if ext == "json" { return .json }
        if ext == "xml" { return .xml }
        
        // Interface files
        if ext == "storyboard" || ext == "storyboardc" { return .storyboard }
        if ext == "xib" || ext == "nib" { return .xib }
        
        // Core Data
        if ext == "momd" || ext == "mom" || ext == "sqlite" || ext == "xcdatamodel" {
            return .coreData
        }
        
        // Security
        if ext == "cer" || ext == "der" || ext == "p12" || ext == "pem" {
            return .certificate
        }
        if ext == "mobileprovision" || ext == "provisionprofile" {
            return .provisioning
        }
        
        // Source code
        if ext == "swift" { return .swift }
        if ext == "m" || ext == "mm" { return .objectiveC }
        if ext == "h" || ext == "hpp" { return .header }
        
        // Archives
        if ["zip", "gz", "tar", "bz2", "xz"].contains(ext) {
            return .archive
        }
        
        // Documents
        if ["txt", "md", "rtf", "html", "css", "js"].contains(ext) {
            return .document
        }
        
        return .other
    }
    
    public var displayName: String {
        return self.rawValue
    }
    
    public var emoji: String {
        switch self {
        case .executable: return "⚙️"
        case .framework: return "📦"
        case .library: return "📚"
        case .image: return "🖼"
        case .video: return "🎬"
        case .audio: return "🎵"
        case .font: return "🔤"
        case .localization: return "🌍"
        case .plist: return "📋"
        case .json: return "📊"
        case .xml: return "📄"
        case .storyboard: return "📱"
        case .xib: return "🎨"
        case .coreData: return "💾"
        case .certificate: return "🔐"
        case .provisioning: return "📝"
        case .swift: return "🦉"
        case .objectiveC: return "📘"
        case .header: return "📑"
        case .archive: return "🗜"
        case .document: return "📃"
        case .other: return "❓"
        }
    }
}