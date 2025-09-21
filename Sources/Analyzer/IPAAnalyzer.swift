import Foundation
import IPAFoundation
import Parser

public class IPAAnalyzer: IPAAnalyzerProtocol {
    private let sizeCalculator: SizeCalculator
    private let duplicationDetector: DuplicationDetector
    private let optimizationSuggester: OptimizationSuggester
    private let binaryAnalyzer: BinaryAnalyzer
    private let assetAnalyzer: AssetAnalyzer
    private let infoPlistAnalyzer: InfoPlistAnalyzer
    private let localizationAnalyzer: LocalizationAnalyzer
    
    public init() {
        self.sizeCalculator = SizeCalculator()
        self.duplicationDetector = DuplicationDetector()
        self.optimizationSuggester = OptimizationSuggester()
        self.binaryAnalyzer = BinaryAnalyzer()
        self.assetAnalyzer = AssetAnalyzer()
        self.infoPlistAnalyzer = InfoPlistAnalyzer()
        self.localizationAnalyzer = LocalizationAnalyzer()
    }
    
    public func analyze(_ content: IPAContent) async throws -> AnalysisResult {
        return try await analyze(content, progressCallback: nil, language: "en")
    }
    
    public func analyze(_ content: IPAContent, progressCallback: ProgressCallback?) async throws -> AnalysisResult {
        return try await analyze(content, progressCallback: progressCallback, language: "en")
    }
    
    public func analyze(_ content: IPAContent, progressCallback: ProgressCallback?, language: String) async throws -> AnalysisResult {
        progressCallback?("Calculating file sizes...", 76)
        
        // Calculate category sizes
        let categorySizes = sizeCalculator.calculateCategorySizes(
            from: content.files,
            totalSize: content.totalSize
        )
        
        progressCallback?("Finding largest files...", 78)
        
        // Find top files
        let topFiles = sizeCalculator.findTopFiles(
            from: content.files,
            totalSize: content.totalSize,
            limit: 20
        )
        
        progressCallback?("Detecting duplicate files...", 82)
        
        // Detect duplicates
        let duplicates = try await duplicationDetector.detectDuplicates(
            in: content.files,
            at: content.payloadPath
        )
        
        progressCallback?("Analyzing frameworks...", 86)
        
        // Analyze frameworks
        let frameworks = try analyzeFrameworks(in: content)
        
        progressCallback?("Deep analyzing Assets.car files...", 90)
        
        // Analyze Assets.car files for deep optimization insights  
        let carAnalysisResults = try await analyzeAssetCars(in: content, progressCallback: progressCallback)
        
        // Analyze main executable with detailed binary analysis
        let executableFile = content.files.first { $0.category == .executable }
        let executablePath = content.payloadPath.appendingPathComponent(content.executableName)
        
        var binaryInfo: BinaryInfo
        do {
            // Attempt detailed binary analysis with timeout protection
            binaryInfo = try binaryAnalyzer.analyzeExecutable(at: executablePath)
            print("🔍 Binary analysis completed: \(binaryInfo.architectures.joined(separator: ", ")), optimized: \(binaryInfo.isOptimized), debug symbols: \(binaryInfo.hasDebugSymbols)")
        } catch {
            print("⚠️ Binary analysis failed: \(error), using fallback")
            // Fallback to basic analysis
            binaryInfo = BinaryInfo(
                path: content.executableName,
                architectures: ["arm64"], // Default assumption
                isDynamic: true,
                hasDebugSymbols: false,
                size: executableFile?.size ?? 0
            )
        }
        
        progressCallback?("Analyzing Info.plist...", 95)
        
        // Analyze Info.plist capabilities and permissions
        var infoPlistAnalysis: InfoPlistAnalysis
        do {
            infoPlistAnalysis = self.infoPlistAnalyzer.analyzeInfoPlist(content.infoPlist)
            print("✅ Info.plist analysis completed")
        } catch {
            print("⚠️ Info.plist analysis failed: \(error), using fallback")
            infoPlistAnalysis = InfoPlistAnalysis(
                backgroundModes: [],
                capabilities: [],
                permissions: [],
                unusedFeatures: [],
                privacyKeys: [],
                estimatedWaste: 0
            )
        }
        
        progressCallback?("Analyzing localization files...", 96)
        
        // Analyze localizations in detail
        var localizationAnalysis: LocalizationAnalysis
        do {
            localizationAnalysis = self.localizationAnalyzer.analyzeLocalizations(from: content.files)
            print("🌍 Localization analysis: \(localizationAnalysis.totalLanguages) languages, \(localizationAnalysis.totalSize.formattedSize), \(localizationAnalysis.optimizationPotential.formattedSize) potential savings")
        } catch {
            print("⚠️ Localization analysis failed: \(error), using fallback")
            localizationAnalysis = LocalizationAnalysis(
                totalLanguages: 0,
                totalSize: 0,
                totalFiles: 0,
                languages: [],
                unusedLanguages: [],
                oversizedLanguages: [],
                incompleteLanguages: [],
                duplicateContent: [],
                optimizationPotential: 0,
                recommendations: []
            )
        }
        
        // Calculate metrics
        let metrics = AnalysisMetrics(
            fileCount: content.files.count,
            directoryCount: countDirectories(in: content.files),
            executableSize: sizeCalculator.calculateExecutableSize(from: content.files),
            resourcesSize: sizeCalculator.calculateResourcesSize(from: content.files),
            frameworksSize: sizeCalculator.calculateFrameworksSize(from: content.files),
            localizationCount: countLocalizations(in: content.files),
            supportedDevices: extractSupportedDevices(from: content.infoPlist),
            minimumOSVersion: content.minimumOSVersion,
            infoPlistAnalysis: infoPlistAnalysis,
            localizationAnalysis: localizationAnalysis
        )
        
        progressCallback?("Generating optimization suggestions...", 97)
        
        // Generate optimization suggestions with binary analysis
        let suggestions = optimizationSuggester.generateSuggestions(
            from: content,
            analysis: metrics,
            categorySizes: categorySizes,
            duplicates: duplicates,
            frameworks: frameworks,
            carAnalysisResults: carAnalysisResults,
            binaryInfo: binaryInfo,
            language: language
        )
        
        progressCallback?("Finalizing analysis...", 99)
        
        // Get compressed size if available
        let compressedSize = getCompressedSize(content: content)
        
        progressCallback?("Analysis complete!", 100)
        
        return AnalysisResult(
            bundleIdentifier: content.bundleIdentifier,
            bundleName: content.bundleName,
            version: content.bundleVersion,
            shortVersion: content.bundleShortVersion,
            totalSize: content.totalSize,
            compressedSize: compressedSize,
            metrics: metrics,
            categorySizes: categorySizes,
            topFiles: topFiles,
            frameworks: frameworks,
            architectures: binaryInfo.architectures,
            duplicates: duplicates,
            suggestions: suggestions,
            assetAnalysisResults: carAnalysisResults,
            analysisErrors: [] // TODO: Collect errors from different analysis steps
        )
    }
    
    private func analyzeFrameworks(in content: IPAContent) throws -> [FrameworkInfo] {
        // Simplified framework analysis for performance
        let frameworkFiles = content.files.filter { 
            $0.path.contains(".framework")
        }
        
        print("📚 Found \(frameworkFiles.count) framework files")
        
        // Group by framework name and calculate size
        var frameworkSizes: [String: Int64] = [:]
        for file in frameworkFiles {
            let frameworkName = extractFrameworkName(from: file.path)
            frameworkSizes[frameworkName, default: 0] += file.size
        }
        
        return frameworkSizes.map { name, size in
            FrameworkInfo(
                name: name,
                path: "/Frameworks/\(name).framework",
                size: size,
                isSystemFramework: isSystemFramework(name: name),
                isDynamic: true,
                architectures: ["arm64"]
            )
        }
    }
    
    private func extractFrameworkName(from path: String) -> String {
        let components = path.components(separatedBy: "/")
        for component in components {
            if component.hasSuffix(".framework") {
                return component.replacingOccurrences(of: ".framework", with: "")
            }
        }
        return "Unknown"
    }
    
    private func isSystemFramework(name: String) -> Bool {
        let systemFrameworks = ["UIKit", "Foundation", "CoreGraphics", "CoreData"]
        return systemFrameworks.contains(name)
    }
    
    private func countDirectories(in files: [IPAFile]) -> Int {
        let directories = Set(files.compactMap { file in
            URL(fileURLWithPath: file.path).deletingLastPathComponent().path
        })
        return directories.count
    }
    
    private func countLocalizations(in files: [IPAFile]) -> Int {
        let localizationDirs = Set(files.compactMap { file in
            file.path.components(separatedBy: "/").first { $0.contains(".lproj") }
        })
        return localizationDirs.count
    }
    
    private func extractSupportedDevices(from infoPlist: [String: Any]) -> [String] {
        var devices: [String] = []
        
        if let deviceFamily = infoPlist["UIDeviceFamily"] as? [Int] {
            if deviceFamily.contains(1) { devices.append("iPhone") }
            if deviceFamily.contains(2) { devices.append("iPad") }
        }
        
        return devices.isEmpty ? ["Universal"] : devices
    }
    
    private func getCompressedSize(content: IPAContent) -> Int64? {
        // Try to get the original IPA size if available
        // This would need to be passed from the parser or stored somewhere
        return nil
    }
    
    private func analyzeAssetCars(in content: IPAContent, progressCallback: ProgressCallback?) async throws -> [CarAnalysisResult] {
        let carFiles = content.files.filter { $0.path.hasSuffix(".car") }
        var results: [CarAnalysisResult] = []
        
        print("🎨 Found \(carFiles.count) Assets.car files")
        
        for (index, carFile) in carFiles.enumerated() {
            let progress = 90 + (index * 5 / max(carFiles.count, 1)) // 90-95% range
            progressCallback?("Analyzing Assets.car files (\(index + 1)/\(carFiles.count))...", progress)
            
            print("🔍 Analyzing \(carFile.path) (\(carFile.size.formattedSize))")
            
            // Build the full path by combining payload path with the relative path
            let fullPath = content.payloadPath.appendingPathComponent(carFile.path.hasPrefix("/") ? String(carFile.path.dropFirst()) : carFile.path).path
            print("🔧 Full path: \(fullPath)")
            
            // Always perform detailed analysis
            
            do {
                // Use the existing AssetAnalyzer with detailed analysis
                let result = try await self.assetAnalyzer.analyzeCarFile(at: fullPath)
                results.append(result)
                
                let duplicateCount = result.duplicates.count
                let unusedCount = result.unusedAssets.count
                let optimizationMB = result.optimizationPotential / 1_048_576
                
                print("✅ \(carFile.path): \(duplicateCount) duplicates, \(unusedCount) unused, \(optimizationMB)MB potential")
                
            } catch {
                print("⚠️ Failed to analyze \(carFile.path): \(error)")
                // Fallback to basic analysis
                results.append(CarAnalysisResult(
                    path: carFile.path,
                    assets: [],
                    duplicates: [],
                    unusedAssets: [],
                    totalSize: carFile.size,
                    optimizationPotential: Int64(Double(carFile.size) * 0.15) // Estimate 15% optimization
                ))
            }
        }
        
        return results
    }
}
