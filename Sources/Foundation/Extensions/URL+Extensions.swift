import Foundation

public extension URL {
    var fileSize: Int64? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: self.path)
            return attributes[.size] as? Int64
        } catch {
            return nil
        }
    }
    
    var isDirectory: Bool {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: self.path, isDirectory: &isDir)
        return isDir.boolValue
    }
    
    func allFiles() throws -> [URL] {
        guard isDirectory else { return [self] }
        
        var files: [URL] = []
        let enumerator = FileManager.default.enumerator(
            at: self,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        while let fileURL = enumerator?.nextObject() as? URL {
            let isRegularFile = try fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile ?? false
            if isRegularFile {
                files.append(fileURL)
            }
        }
        
        return files
    }
    
    func temporaryDirectory(prefix: String = "ipascanner") -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let uniqueName = "\(prefix)_\(UUID().uuidString)"
        return tempDir.appendingPathComponent(uniqueName)
    }
}