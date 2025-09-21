import Foundation
import Crypto
import IPAFoundation

public struct DuplicationDetector: Sendable {
    
    public init() {}
    
    public func detectDuplicates(in files: [IPAFile], at basePath: URL) async throws -> [DuplicateGroup] {
        // Optimized threshold: 1KB minimum (was 10KB, too conservative)
        let significantFiles = files.filter { $0.size > 1_024 }
        
        print("🔍 Checking duplicates in \(significantFiles.count) significant files (>1KB)...")
        
        // Adaptive processing based on total file count - more aggressive limits
        let maxFiles: Int
        
        if significantFiles.count > 10000 {
            maxFiles = 1000     // Very large IPAs: process top 1000 by size
        } else if significantFiles.count > 2000 {
            maxFiles = 1500     // Large IPAs: process top 1500
        } else {
            maxFiles = significantFiles.count // Small/medium IPAs: process all
        }
        
        // Sort by size descending to prioritize large files
        let filesToCheck = Array(significantFiles.sorted { $0.size > $1.size }.prefix(maxFiles))
        
        print("📦 Processing \(filesToCheck.count) files with concurrent hashing...")
        let startTime = Date()
        
        // Use TaskGroup for modern Swift concurrency  
        let fileHashes = await withTaskGroup(of: (String, String)?.self) { group in
            // Add concurrent hash calculation tasks
            for file in filesToCheck {
                group.addTask { @Sendable in
                    let filePath = basePath.appendingPathComponent(file.path)
                    if let hash = Self.calculateFileHashAsync(at: filePath) {
                        return (hash, file.path)
                    }
                    return nil
                }
            }
            
            // Collect results
            var results: [String: [String]] = [:]
            for await result in group {
                if let (hash, path) = result {
                    if results[hash] == nil {
                        results[hash] = []
                    }
                    results[hash]?.append(path)
                }
            }
            return results
        }
        
        let hashingTime = Date().timeIntervalSince(startTime)
        print("⏱️ Hashing completed in \(String(format: "%.2f", hashingTime))s")
        
        return self.processDuplicateGroups(from: fileHashes, files: files)
    }
    
    private static func calculateFileHashAsync(at url: URL) -> String? {
        let startTime = Date()
        do {
            // Use streaming I/O for large files to avoid memory pressure
            let fileHandle = try FileHandle(forReadingFrom: url)
            defer { try? fileHandle.close() }
            
            var hasher = SHA256()
            let chunkSize = 1024 * 1024 // 1MB chunks
            var totalBytes: Int64 = 0
            
            while true {
                let chunk = fileHandle.readData(ofLength: chunkSize)
                if chunk.isEmpty { break }
                hasher.update(data: chunk)
                totalBytes += Int64(chunk.count)
            }
            
            let hash = hasher.finalize()
            let duration = Date().timeIntervalSince(startTime)
            let speedMBs = Double(totalBytes) / 1_048_576 / duration
            
            if duration > 1.0 { // Log only slow files
                print("🐌 Slow hash: \(url.lastPathComponent) - \(String(format: "%.1f", Double(totalBytes)/1_048_576))MB in \(String(format: "%.2f", duration))s (\(String(format: "%.1f", speedMBs))MB/s)")
            }
            
            return hash.compactMap { String(format: "%02x", $0) }.joined()
        } catch {
            print("⚠️ Failed to hash file \(url.lastPathComponent): \(error)")
            return nil
        }
    }
    
    private func processDuplicateGroups(from fileHashes: [String: [String]], files: [IPAFile]) -> [DuplicateGroup] {
        // Filter out groups with only one file (no duplicates)
        let duplicateGroups = fileHashes.compactMap { (hash, paths) -> DuplicateGroup? in
            guard paths.count > 1 else { return nil }
            
            // Find the size of one of the files
            let fileSize = files.first(where: { $0.path == paths[0] })?.size ?? 0
            let wastedSpace = fileSize * Int64(paths.count - 1)
            
            return DuplicateGroup(
                hash: hash,
                files: paths,
                size: fileSize,
                wastedSpace: wastedSpace
            )
        }
        
        print("✅ Found \(duplicateGroups.count) duplicate groups")
        
        // Sort by wasted space (descending)
        return duplicateGroups.sorted { $0.wastedSpace > $1.wastedSpace }
    }
    
    public func calculateTotalWastedSpace(from duplicates: [DuplicateGroup]) -> Int64 {
        return duplicates.reduce(0) { $0 + $1.wastedSpace }
    }
}