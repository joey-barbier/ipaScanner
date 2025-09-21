import Foundation
import IPAFoundation
import CryptoKit

// Simplified version with reliable timeout handling
public class AssetAnalyzer {
    
    // Cache for content hashes to avoid recomputation
    private var hashCache: [String: String] = [:]
    private let cacheQueue = DispatchQueue(label: "asset.analyzer.cache", attributes: .concurrent)
    
    public init() {}
    
    public func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.hashCache.removeAll()
        }
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
        print("🔧 Running CLI assetutil on: \(carPath)")
        let startTime = Date()
        
        // Use a unique temp file for this analysis
        let tempFile = "/tmp/assetutil_\(UUID().uuidString).json"
        defer {
            try? FileManager.default.removeItem(atPath: tempFile)
        }
        
        // Dynamic timeout based on file size (min 2s, up to 30s for very large files)
        let fileSize = (try? getFileSize(at: carPath)) ?? 0
        let timeoutSeconds = min(30, max(2, Int(fileSize / 3_000_000))) // ~3MB per second processing
        
        print("🔧 Using \(timeoutSeconds)s timeout for \(fileSize / 1_048_576)MB file")
        
        // Simple CLI command with dynamic timeout using Process
        let process = Process()
        process.launchPath = "/bin/sh"
        process.arguments = ["-c", "timeout \(timeoutSeconds) assetutil -I '\(carPath)' > '\(tempFile)' 2>/dev/null"]
        
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
            print("❌ Failed to run assetutil: \(error)")
            return []
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Check if we have output file (regardless of exit code)
        if FileManager.default.fileExists(atPath: tempFile),
           let outputData = try? Data(contentsOf: URL(fileURLWithPath: tempFile)),
           let output = String(data: outputData, encoding: .utf8),
           !output.isEmpty && !output.contains("timeout: ") {
            print("📊 assetutil output size: \(output.count) bytes")
            print("⏱️ assetutil completed in \(String(format: "%.2f", duration))s")
            return parseAssetUtilJSONOutput(output)
        }
        
        print("⏰ Timeout or no output after \(String(format: "%.2f", duration))s for \(carPath)")
        return []
    }
    
    private func parseAssetUtilJSONOutput(_ output: String) -> [AssetInfo] {
        guard let data = output.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            print("⚠️ Failed to parse assetutil JSON output")
            return []
        }
        
        print("📊 Parsing \(jsonArray.count) asset entries")
        var assets: [AssetInfo] = []
        
        // Skip the first element which contains metadata, start from index 1
        for i in 1..<jsonArray.count {
            let assetDict = jsonArray[i]
            
            guard let name = assetDict["Name"] as? String else {
                continue
            }
            
            let type = assetDict["AssetType"] as? String ?? "Unknown"
            let idiom = assetDict["Idiom"] as? String ?? "universal"
            let scaleValue = assetDict["Scale"] as? NSNumber ?? 1
            let scale = "\(scaleValue)x"
            let sizeString = assetDict["Size"] as? String ?? "0x0"
            let renditionKey = assetDict["RenditionKey"] as? String ?? ""
            let sizeOnDisk = (assetDict["SizeOnDisk"] as? NSNumber)?.int64Value ?? 0
            
            // Extract content hash - use SHA1Digest from assetutil and convert to SHA-256 equivalent
            let sha1Digest = assetDict["SHA1Digest"] as? String
            let contentHash = generateContentHash(sha1Digest: sha1Digest, name: name, type: type, size: sizeString)
            
            let asset = AssetInfo(
                name: name,
                type: type,
                idiom: idiom,
                scale: scale,
                size: sizeString,
                renditionKey: renditionKey,
                sizeOnDisk: sizeOnDisk,
                contentHash: contentHash
            )
            assets.append(asset)
        }
        
        print("✅ Successfully parsed \(assets.count) assets from \(jsonArray.count) entries")
        return assets
    }
    
    private func generateContentHash(sha1Digest: String?, name: String, type: String, size: String) -> String? {
        // If we have SHA1 digest from assetutil, use it as the primary hash
        // This represents the actual image content, not metadata
        guard let sha1 = sha1Digest, !sha1.isEmpty else {
            return nil
        }
        
        // Create cache key to avoid recomputing identical hashes
        let cacheKey = "\(sha1)-\(type)-\(size)"
        
        // Check cache first (thread-safe read)
        return cacheQueue.sync {
            if let cachedHash = hashCache[cacheKey] {
                return cachedHash
            }
            
            // Generate new hash if not in cache
            let contentData = cacheKey.data(using: .utf8) ?? Data()
            let sha256Hash = SHA256.hash(data: contentData)
            let hashString = sha256Hash.map { String(format: "%02x", $0) }.joined()
            
            // Store in cache (barrier write to ensure thread safety)
            cacheQueue.async(flags: .barrier) {
                self.hashCache[cacheKey] = hashString
            }
            
            return hashString
        }
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
