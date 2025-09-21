import Vapor
import Foundation

class FileCleanupService {
    private let uploadDirectory: URL
    
    init(uploadDirectory: String = "uploads") {
        let workDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        self.uploadDirectory = workDir.appendingPathComponent(uploadDirectory)
        
        // Create upload directory if it doesn't exist
        try? FileManager.default.createDirectory(at: self.uploadDirectory, 
                                               withIntermediateDirectories: true)
    }
    
    /// Clean up uploaded file after analysis
    func cleanup(filePath: String) {
        do {
            let fileURL = URL(fileURLWithPath: filePath)
            if FileManager.default.fileExists(atPath: filePath) {
                try FileManager.default.removeItem(at: fileURL)
                print("✅ Cleaned up file: \(fileURL.lastPathComponent)")
            }
        } catch {
            print("⚠️ Failed to cleanup file \(filePath): \(error)")
        }
    }
    
    /// Get unique upload path for new file
    func getUploadPath(originalName: String) -> String {
        let fileExtension = URL(fileURLWithPath: originalName).pathExtension
        let fileName = "\(UUID().uuidString).\(fileExtension)"
        return uploadDirectory.appendingPathComponent(fileName).path
    }
    
    /// Clean up old files (older than 1 hour)
    func cleanupOldFiles() {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .hour, value: -1, to: Date()) ?? Date()
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: uploadDirectory, 
                                                                  includingPropertiesForKeys: [.creationDateKey])
            
            for fileURL in files {
                let attributes = try fileURL.resourceValues(forKeys: [.creationDateKey])
                if let creationDate = attributes.creationDate, 
                   creationDate < cutoffDate {
                    try FileManager.default.removeItem(at: fileURL)
                    print("🗑️ Cleaned up old file: \(fileURL.lastPathComponent)")
                }
            }
        } catch {
            print("⚠️ Error during cleanup: \(error)")
        }
    }
    
    /// Validate uploaded IPA file
    func validateIPA(at path: String, language: String = "en") throws {
        let fileURL = URL(fileURLWithPath: path)
        
        // Check file exists
        guard FileManager.default.fileExists(atPath: path) else {
            throw Abort(.notFound, reason: "File not found")
        }
        
        // Check file extension - special handling for APK files
        let fileExtension = fileURL.pathExtension.lowercased()
        
        // Reject APK files with troll message
        if fileExtension == "apk" {
            let trollMessage = LocalizationService.translate("errors.android_troll", language: language)
            throw Abort(.badRequest, reason: trollMessage)
        }
        
        // Check file extension must be IPA
        guard fileExtension == "ipa" else {
            let errorMessage = LocalizationService.translate("errors.invalid_format", language: language)
            throw Abort(.badRequest, reason: errorMessage)
        }
        
        // Check file size (max 500MB)
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        if let fileSize = attributes[.size] as? Int64, fileSize > 500 * 1024 * 1024 {
            throw Abort(.badRequest, reason: "File too large (max 500MB)")
        }
        
        // Basic ZIP header check
        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer { fileHandle.closeFile() }
        
        let headerData = fileHandle.readData(ofLength: 4)
        let zipHeader = Data([0x50, 0x4B, 0x03, 0x04]) // "PK.." ZIP header
        
        guard headerData == zipHeader else {
            throw Abort(.badRequest, reason: "Invalid IPA file format")
        }
    }
}