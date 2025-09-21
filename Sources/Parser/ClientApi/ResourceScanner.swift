import Foundation
import IPAFoundation

public class ResourceScanner {
    private let fileManager = FileManager.default
    
    public init() {}
    
    public func scanResources(in directory: URL) throws -> [IPAFile] {
        var ipaFiles: [IPAFile] = []
        
        print("📂 Scanning resources in \(directory.path)...")
        
        let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .isExecutableKey],
            options: [.skipsHiddenFiles]
        )
        
        var fileCount = 0
        while let fileURL = enumerator?.nextObject() as? URL {
            fileCount += 1
            
            // Progress indicator for large directories
            if fileCount % 1000 == 0 {
                print("📊 Processed \(fileCount) files...")
            }
            
            do {
                let resourceValues = try fileURL.resourceValues(
                    forKeys: [.isRegularFileKey, .fileSizeKey, .isExecutableKey]
                )
                
                guard let isRegularFile = resourceValues.isRegularFile,
                      isRegularFile else {
                    continue
                }
                
                let relativePath = fileURL.path.replacingOccurrences(of: directory.path, with: "")
                let size = Int64(resourceValues.fileSize ?? 0)
                let category = FileCategory.from(path: fileURL.path)
                let isExecutable = resourceValues.isExecutable ?? false
                
                // Simplified attributes to avoid extra I/O
                let attributes = FileAttributes(
                    isExecutable: isExecutable,
                    isDirectory: false
                )
                
                let ipaFile = IPAFile(
                    path: relativePath,
                    size: size,
                    category: category,
                    isCompressed: false, // Skip compression check for performance
                    attributes: attributes
                )
                
                ipaFiles.append(ipaFile)
            } catch {
                // Skip files that can't be accessed
                continue
            }
        }
        
        print("✅ Scanned \(ipaFiles.count) files total")
        return ipaFiles
    }
    
    private func isCompressedFile(at url: URL) -> Bool {
        let compressedExtensions = ["zip", "gz", "bz2", "xz", "tar", "car", "aar"]
        let ext = url.pathExtension.lowercased()
        return compressedExtensions.contains(ext)
    }
    
    public func findPayloadDirectory(in extractedPath: URL) throws -> URL {
        let payloadPath = extractedPath.appendingPathComponent("Payload")
        
        guard fileManager.fileExists(atPath: payloadPath.path) else {
            throw IPAScannerError.invalidIPAFormat(reason: "No Payload directory found")
        }
        
        // Find the .app directory inside Payload
        let contents = try fileManager.contentsOfDirectory(at: payloadPath, includingPropertiesForKeys: nil)
        
        guard let appDirectory = contents.first(where: { $0.pathExtension == "app" }) else {
            throw IPAScannerError.invalidIPAFormat(reason: "No .app directory found in Payload")
        }
        
        return appDirectory
    }
    
    public func calculateTotalSize(of files: [IPAFile]) -> Int64 {
        return files.reduce(0) { $0 + $1.size }
    }
}