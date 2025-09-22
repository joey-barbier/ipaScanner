import Foundation
import IPAFoundation
import Crypto

// Simplified version with reliable timeout handling
public actor AssetAnalyzer: Sendable {
    
    // Cache for content hashes to avoid recomputation
    private var hashCache: [String: String] = [:]
    
    public init() {}
    
    public func clearCache() {
        hashCache.removeAll()
    }
    
    public func analyzeCarFile(at path: String) throws -> CarAnalysisResult {
        let fileSize = try getFileSize(at: path)
        
        
        // Skip extremely large files to avoid excessive processing time
        if fileSize > 200_000_000 { // > 200MB
            print("🚫 Skipping extremely large Assets.car (\(fileSize / 1_048_576)MB): \(path)")
            return CarAnalysisResult(
                path: path,
                assets: [],
                duplicates: [],
                unusedAssets: [],
                totalSize: fileSize,
                optimizationPotential: Int64(Double(fileSize) * 0.15), // Estimate 15%
                analysisStatus: .skipped,
                errorMessage: "File too large (\(fileSize / 1_048_576)MB) - skipped to avoid excessive processing"
            )
        }
        
        let assets = extractAssetInfoWithTimeout(from: path)
        let duplicates = detectDuplicates(in: assets, totalFileSize: fileSize)
        let unusedAssets = detectUnusedAssets(in: assets)
        
        let optimizationPotential = calculateOptimizationPotential(
            duplicates: duplicates,
            unusedAssets: unusedAssets,
            totalSize: fileSize
        )
        
        let status: AssetAnalysisStatus = assets.isEmpty ? .failed : .success
        let errorMsg: String? = assets.isEmpty ? "No assets extracted - analysis may have failed" : nil
        
        return CarAnalysisResult(
            path: path,
            assets: assets,
            duplicates: duplicates,
            unusedAssets: unusedAssets,
            totalSize: fileSize,
            optimizationPotential: optimizationPotential,
            analysisStatus: status,
            errorMessage: errorMsg
        )
    }
    
    private func extractAssetInfoWithTimeout(from carPath: String) -> [AssetInfo] {
        print("🔧 Running cartool on: \(carPath)")
        let startTime = Date()
        
        // Use a unique temp directory for cartool extraction
        let tempDir = "/tmp/cartool_\(UUID().uuidString)"
        defer {
            try? FileManager.default.removeItem(atPath: tempDir)
        }
        
        // Dynamic timeout based on file size (min 2s, up to 30s for very large files)
        let fileSize = (try? getFileSize(at: carPath)) ?? 0
        let timeoutSeconds = min(30, max(2, Int(fileSize / 3_000_000))) // ~3MB per second processing
        
        print("🔧 Using \(timeoutSeconds)s timeout for \(fileSize / 1_048_576)MB file")
        
        // Create temp directory and run cartool
        let process = Process()
        process.launchPath = "/bin/sh"
        process.arguments = ["-c", "mkdir -p '\(tempDir)' && timeout \(timeoutSeconds) cartool '\(carPath)' '\(tempDir)' 2>/dev/null"]
        
        do {
            try process.run()
            
            // Don't use waitUntilExit() - poll instead with dynamic timeout
            let maxWait = Double(timeoutSeconds) + 1.0 // +1s buffer
            let pollInterval = 0.2 // Check every 200ms for better performance
            var totalWait = 0.0
            
            while process.isRunning && totalWait < maxWait {
                Thread.sleep(forTimeInterval: pollInterval)
                totalWait += pollInterval
            }
            
            // Force terminate if still running
            if process.isRunning {
                process.terminate()
                print("⚠️ Force terminated CLI process for \(carPath) after \(String(format: "%.1f", totalWait))s")
                Thread.sleep(forTimeInterval: 0.1) // Give it time to terminate
            }
            
        } catch {
            print("❌ Failed to run cartool: \(error)")
            return []
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Check if cartool extracted files successfully
        if FileManager.default.fileExists(atPath: tempDir),
           let extractedFiles = try? FileManager.default.contentsOfDirectory(atPath: tempDir),
           !extractedFiles.isEmpty {
            print("📊 cartool extracted \(extractedFiles.count) files")
            print("⏱️ cartool completed in \(String(format: "%.2f", duration))s")
            return parseExtractedAssets(from: tempDir, extractedFiles: extractedFiles)
        }
        
        print("⏰ Timeout or no output after \(String(format: "%.2f", duration))s for \(carPath)")
        return []
    }
    
    private func parseExtractedAssets(from tempDir: String, extractedFiles: [String]) -> [AssetInfo] {
        var assets: [AssetInfo] = []
        
        print("📊 Analyzing \(extractedFiles.count) extracted files")
        
        // Analyze each extracted file
        for fileName in extractedFiles {
            let filePath = "\(tempDir)/\(fileName)"
            
            guard let fileAttributes = try? FileManager.default.attributesOfItem(atPath: filePath),
                  let fileSize = fileAttributes[.size] as? Int64 else {
                continue
            }
            
            // Determine asset type from file extension
            let fileExtension = (fileName as NSString).pathExtension.lowercased()
            let assetType = getAssetType(from: fileExtension)
            
            // Extract asset name (remove @2x, @3x, ~ipad suffixes)
            let assetName = extractAssetName(from: fileName)
            
            // Determine idiom and scale from filename
            let (idiom, scale) = extractIdiomAndScale(from: fileName)
            
            // Generate a simple hash for the file content
            let contentHash = generateSimpleHash(for: filePath)
            
            let asset = AssetInfo(
                name: assetName,
                type: assetType,
                idiom: idiom,
                scale: scale,
                size: "0x0", // cartool doesn't provide original dimensions
                renditionKey: fileName,
                sizeOnDisk: fileSize,
                contentHash: contentHash
            )
            
            assets.append(asset)
        }
        
        print("✅ Successfully analyzed \(assets.count) assets from cartool extraction")
        return assets
    }
    
    // Helper functions for cartool analysis
    private func getAssetType(from extension: String) -> String {
        switch `extension` {
        case "png", "jpg", "jpeg": return "Image"
        case "pdf": return "PDF"
        case "json": return "Data"
        default: return "Unknown"
        }
    }
    
    private func extractAssetName(from fileName: String) -> String {
        let name = (fileName as NSString).deletingPathExtension
        // Remove @2x, @3x, ~ipad suffixes
        let cleanName = name
            .replacingOccurrences(of: "@3x", with: "")
            .replacingOccurrences(of: "@2x", with: "")
            .replacingOccurrences(of: "~ipad", with: "")
            .replacingOccurrences(of: "~iphone", with: "")
        return cleanName
    }
    
    private func extractIdiomAndScale(from fileName: String) -> (idiom: String, scale: String) {
        if fileName.contains("~ipad") {
            return ("tablet", fileName.contains("@2x") ? "2x" : "1x")
        } else if fileName.contains("~iphone") {
            return ("phone", fileName.contains("@3x") ? "3x" : (fileName.contains("@2x") ? "2x" : "1x"))
        } else if fileName.contains("@3x") {
            return ("universal", "3x")
        } else if fileName.contains("@2x") {
            return ("universal", "2x")
        } else {
            return ("universal", "1x")
        }
    }
    
    private func generateSimpleHash(for filePath: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            return nil
        }
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    private func generateContentHash(sha1Digest: String?, name: String, type: String, size: String) -> String? {
        // If we have SHA1 digest from assetutil, use it as the primary hash
        // This represents the actual image content, not metadata
        guard let sha1 = sha1Digest, !sha1.isEmpty else {
            return nil
        }
        
        // Create cache key to avoid recomputing identical hashes
        let cacheKey = "\(sha1)-\(type)-\(size)"
        
        // Check cache first
        if let cachedHash = hashCache[cacheKey] {
            return cachedHash
        }
        
        // Generate new hash if not in cache
        let contentData = cacheKey.data(using: .utf8) ?? Data()
        let sha256Hash = SHA256.hash(data: contentData)
        let hashString = sha256Hash.map { String(format: "%02x", $0) }.joined()
        
        // Store in cache
        hashCache[cacheKey] = hashString
        
        return hashString
    }
    
    
    private func getAssetSize(_ asset: AssetInfo, estimatedSize: Int64) -> Int64 {
        return asset.sizeOnDisk > 0 ? asset.sizeOnDisk : estimatedSize
    }

    private func detectDuplicates(in assets: [AssetInfo], totalFileSize: Int64) -> [AssetDuplicate] {
        var duplicates: [AssetDuplicate] = []
        
        // Calculate a better estimation: use average of actual sizeOnDisk values when available
        let assetsWithSize = assets.filter { $0.sizeOnDisk > 0 }
        let estimatedSize: Int64
        if !assetsWithSize.isEmpty {
            let totalKnownSize = assetsWithSize.reduce(0) { $0 + $1.sizeOnDisk }
            let averageKnownSize = totalKnownSize / Int64(assetsWithSize.count)
            estimatedSize = max(1024, averageKnownSize) // Use average of known sizes, min 1KB
            print("🔍 Using average size estimation: \(estimatedSize) bytes (from \(assetsWithSize.count) assets with known sizes)")
        } else {
            // Fallback to file-based estimation, but use a more reasonable minimum
            estimatedSize = assets.count > 0 ? max(4096, totalFileSize / Int64(assets.count)) : 4096 // Min 4KB per asset
            print("🔍 Using file-based estimation: \(estimatedSize) bytes (no assets with known sizes)")
        }
        
        // NEW APPROACH: Hash-based duplicate detection using actual image content
        print("🔍 Starting hash-based duplicate detection...")
        
        // Group assets by their content hash (actual image content)
        var hashGroups: [String: [AssetInfo]] = [:]
        var assetsWithoutHash: [AssetInfo] = []
        
        for asset in assets {
            if let contentHash = asset.contentHash, !contentHash.isEmpty {
                hashGroups[contentHash, default: []].append(asset)
            } else {
                assetsWithoutHash.append(asset)
            }
        }
        
        print("🔍 Hash analysis: \(hashGroups.count) unique hashes, \(assetsWithoutHash.count) assets without hash")
        
        // Find hash groups with multiple assets (true duplicates)
        let duplicateHashGroups = hashGroups.filter { $0.value.count > 1 }
        print("🔍 Found \(duplicateHashGroups.count) hash groups with duplicates")
        
        for (contentHash, duplicateAssets) in duplicateHashGroups {
            // Calculate wasted space: (count - 1) * average size for this group
            let groupSize = duplicateAssets.reduce(Int64(0)) { total, asset in
                return total + getAssetSize(asset, estimatedSize: estimatedSize)
            }
            let averageAssetSize = groupSize / Int64(duplicateAssets.count)
            let wastedSpace = Int64(duplicateAssets.count - 1) * averageAssetSize
            
            // Create a readable name for the duplicate group
            let representativeAsset = duplicateAssets.first!
            let groupName = duplicateAssets.count > 3 ? 
                "\(representativeAsset.name) (+ \(duplicateAssets.count - 1) identical assets)" :
                duplicateAssets.map { $0.name }.joined(separator: ", ")
            
            let duplicate = AssetDuplicate(
                name: groupName,
                variants: duplicateAssets,
                wastedSpace: wastedSpace
            )
            duplicates.append(duplicate)
            
            print("🔍 Hash duplicate group: \(duplicateAssets.count) assets with hash \(String(contentHash.prefix(8)))..., waste: \(wastedSpace) bytes")
            print("   Assets: \(duplicateAssets.map { $0.name }.prefix(5).joined(separator: ", "))\(duplicateAssets.count > 5 ? "..." : "")")
        }
        
        // FALLBACK: Same-name duplicate detection for assets without hash
        if !assetsWithoutHash.isEmpty {
            print("🔍 Fallback: analyzing \(assetsWithoutHash.count) assets without content hash")
            let fallbackDuplicates = detectSameNameDuplicates(in: assetsWithoutHash, estimatedSize: estimatedSize)
            duplicates.append(contentsOf: fallbackDuplicates)
        }
        
        print("🔍 Total duplicate groups found: \(duplicates.count)")
        return duplicates
    }
    
    private func detectSameNameDuplicates(in assets: [AssetInfo], estimatedSize: Int64) -> [AssetDuplicate] {
        var duplicates: [AssetDuplicate] = []
        var seenAssets: [String: [AssetInfo]] = [:]
        
        // Group assets by name
        for asset in assets {
            seenAssets[asset.name, default: []].append(asset)
        }
        
        // Find groups with multiple variants that could be duplicates
        for (name, variants) in seenAssets {
            if variants.count > 1 {
                // Create unique identifier for each variant including all distinguishing characteristics
                let uniqueVariants = Set(variants.map { 
                    "\($0.type)-\($0.idiom)-\($0.scale)-\($0.size)-\($0.sizeOnDisk)"
                })
                
                // Only flag as duplicates if there are truly identical variants
                if uniqueVariants.count < variants.count {
                    // Find the actual duplicates by grouping identical variants
                    var variantGroups: [String: [AssetInfo]] = [:]
                    for variant in variants {
                        let key = "\(variant.type)-\(variant.idiom)-\(variant.scale)-\(variant.size)-\(variant.sizeOnDisk)"
                        variantGroups[key, default: []].append(variant)
                    }
                    
                    // Only include groups with actual duplicates (count > 1)
                    let actualDuplicateGroups = variantGroups.filter { $0.value.count > 1 }
                    if !actualDuplicateGroups.isEmpty {
                        // Calculate wasted space: for each duplicate group, waste = (count - 1) * size
                        let totalWastedSpace = actualDuplicateGroups.reduce(Int64(0)) { total, group in
                            let assetSize = getAssetSize(group.value.first!, estimatedSize: estimatedSize)
                            let wasteForGroup = Int64(group.value.count - 1) * assetSize
                            return total + wasteForGroup
                        }
                        
                        let duplicateVariants = actualDuplicateGroups.flatMap { $0.value }
                        
                        let duplicate = AssetDuplicate(
                            name: name,
                            variants: duplicateVariants,
                            wastedSpace: totalWastedSpace
                        )
                        duplicates.append(duplicate)
                        
                        print("🔍 Fallback same-name duplicate: \(name) - \(duplicateVariants.count) duplicates, waste: \(totalWastedSpace) bytes")
                    }
                }
            }
        }
        
        return duplicates
    }
    
    private func detectUnusedAssets(in assets: [AssetInfo]) -> [AssetInfo] {
        // Simple heuristic: assets that are iPad-specific might be unused in iPhone-only apps
        return assets.filter { asset in
            asset.idiom.lowercased().contains("pad") && 
            !asset.type.lowercased().contains("icon")
        }
    }
    
    private func calculateOptimizationPotential(
        duplicates: [AssetDuplicate],
        unusedAssets: [AssetInfo],
        totalSize: Int64
    ) -> Int64 {
        let duplicateWaste = duplicates.reduce(0) { $0 + $1.wastedSpace }
        let unusedWaste = unusedAssets.reduce(0) { $0 + $1.sizeOnDisk }
        
        print("🔍 DEBUG: duplicateWaste=\(duplicateWaste), unusedWaste=\(unusedWaste), duplicates.count=\(duplicates.count)")
        
        // If waste is 0 but we have duplicates/unused assets, estimate based on total size
        if duplicateWaste == 0 && !duplicates.isEmpty {
            let totalDuplicateCount = duplicates.reduce(0) { total, dup in
                return total + dup.variants.count - 1 // Count only the duplicates, not the original
            }
            print("🔍 DEBUG: totalDuplicateCount=\(totalDuplicateCount)")
            if totalDuplicateCount > 0 {
                // Estimate that each duplicate takes roughly totalSize / totalAssetCount
                let totalAssetCount = duplicates.reduce(0) { $0 + $1.variants.count } + unusedAssets.count
                let estimatedAssetSize = totalAssetCount > 0 ? totalSize / Int64(totalAssetCount) : 0
                let estimatedDuplicateWaste = Int64(totalDuplicateCount) * estimatedAssetSize
                print("🔍 DEBUG: totalAssetCount=\(totalAssetCount), estimatedAssetSize=\(estimatedAssetSize), estimatedDuplicateWaste=\(estimatedDuplicateWaste)")
                return estimatedDuplicateWaste + unusedWaste
            }
        }
        
        return duplicateWaste + unusedWaste
    }
    
    
    private func getFileSize(at path: String) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }
}
