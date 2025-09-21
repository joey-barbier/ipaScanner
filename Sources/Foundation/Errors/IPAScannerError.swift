import Foundation

public enum IPAScannerError: LocalizedError {
    case fileNotFound(path: String)
    case invalidIPAFormat(reason: String)
    case extractionFailed(reason: String)
    case plistParsingFailed(reason: String)
    case analysisFailed(reason: String)
    case exportFailed(reason: String)
    case invalidInput(reason: String)
    case permissionDenied(path: String)
    case temporaryDirectoryCreationFailed
    case cleanupFailed(reason: String)
    case unsupportedVersion
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .invalidIPAFormat(let reason):
            return "Invalid IPA format: \(reason)"
        case .extractionFailed(let reason):
            return "Extraction failed: \(reason)"
        case .plistParsingFailed(let reason):
            return "Plist parsing failed: \(reason)"
        case .analysisFailed(let reason):
            return "Analysis failed: \(reason)"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .invalidInput(let reason):
            return "Invalid input: \(reason)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .temporaryDirectoryCreationFailed:
            return "Failed to create temporary directory"
        case .cleanupFailed(let reason):
            return "Cleanup failed: \(reason)"
        case .unsupportedVersion:
            return "Unsupported macOS version. This feature requires macOS 10.15 or later."
        }
    }
}