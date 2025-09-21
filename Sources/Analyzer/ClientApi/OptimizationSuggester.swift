import Foundation
import IPAFoundation
import Parser

// Simple localization service for the analyzer
// This mirrors the main LocalizationService but can be used independently
public final class AnalyzerLocalizationService: @unchecked Sendable {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var _translations: [String: [String: Any]] = [:]
    private nonisolated(unsafe) static var _defaultLanguage = "en"
    
    private static var translations: [String: [String: Any]] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _translations
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _translations = newValue
        }
    }
    
    private static var defaultLanguage: String {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _defaultLanguage
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _defaultLanguage = newValue
        }
    }
    
    private static let supportedLanguages = ["fr", "en", "es", "de"]
    
    public static func configure() throws {
        // Load all translation files
        for language in supportedLanguages {
            guard let path = findResourcePath(for: language) else {
                print("⚠️ Warning: Could not find \(language).json translation file")
                continue
            }
            
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                var updatedTranslations = translations
                updatedTranslations[language] = json
                translations = updatedTranslations
                print("✅ Loaded \(language) translations for analyzer")
            } catch {
                print("❌ Error loading \(language) translations: \(error)")
            }
        }
    }
    
    private static func findResourcePath(for language: String) -> String? {
        let possiblePaths = [
            "Resources/Localization/\(language).json",
            "./Resources/Localization/\(language).json",
            "../Resources/Localization/\(language).json",
            "../../Resources/Localization/\(language).json"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }
    
    public static func translate(_ key: String, language: String? = nil, fallback: String? = nil) -> String {
        let lang = language ?? defaultLanguage
        
        // Get the translation for the specified language
        let translation = getTranslation(for: key, in: lang)
        
        // If not found and not default language, try default language
        if translation == nil && lang != defaultLanguage {
            if let defaultTranslation = getTranslation(for: key, in: defaultLanguage) {
                return defaultTranslation
            }
        }
        
        // Return translation, fallback, or key
        return translation ?? fallback ?? key
    }
    
    public static func translate(_ key: String, replacements: [String], language: String? = nil, fallback: String? = nil) -> String {
        var text = translate(key, language: language, fallback: fallback)
        
        // Replace {0}, {1}, etc. with the provided replacements
        for (index, replacement) in replacements.enumerated() {
            text = text.replacingOccurrences(of: "{\(index)}", with: replacement)
        }
        
        return text
    }
    
    public static func setDefaultLanguage(_ language: String) {
        defaultLanguage = language
    }
    
    private static func getTranslation(for key: String, in language: String) -> String? {
        guard let languageDict = translations[language] else { return nil }
        
        let keyParts = key.split(separator: ".").map(String.init)
        var current: Any = languageDict
        
        for part in keyParts {
            guard let dict = current as? [String: Any],
                  let next = dict[part] else {
                return nil
            }
            current = next
        }
        
        return current as? String
    }
}

public class OptimizationSuggester {
    
    public init() {
        // Localization service is already configured at app startup
    }
    
    public func generateSuggestions(
        from content: IPAContent,
        analysis: AnalysisMetrics,
        categorySizes: [FileCategory: CategoryMetrics],
        duplicates: [DuplicateGroup],
        frameworks: [FrameworkInfo],
        carAnalysisResults: [CarAnalysisResult] = [],
        binaryInfo: BinaryInfo? = nil,
        language: String = "en"
    ) -> [OptimizationSuggestion] {
        // Set the language for this analysis session
        AnalyzerLocalizationService.setDefaultLanguage(language)
        
        var suggestions: [OptimizationSuggestion] = []
        
        // Check for duplicate files
        if !duplicates.isEmpty {
            let wastedSpace = duplicates.reduce(0) { $0 + $1.wastedSpace }
            
            var detailedDescription = "\(AnalyzerLocalizationService.translate("optimization_suggestions.common.found", language: language)) \(duplicates.count) \(AnalyzerLocalizationService.translate("optimization_suggestions.common.groups", language: language)) \(AnalyzerLocalizationService.translate("optimization_suggestions.common.of_duplicate_files", language: language)) \(AnalyzerLocalizationService.translate("optimization_suggestions.common.wasting", language: language)) \(wastedSpace.formattedSize)"
            
            // Add detailed breakdown of all duplicate files
            detailedDescription += "\n\n📂 **\(AnalyzerLocalizationService.translate("optimization_suggestions.common.complete_duplicate_files_list", language: language)):**\n"
            detailedDescription += "\n---\n"
            
            for (index, duplicate) in duplicates.enumerated() {
                detailedDescription += "\n### \(AnalyzerLocalizationService.translate("optimization_suggestions.common.group", language: language)) \(index + 1) - \(duplicate.files.count) \(AnalyzerLocalizationService.translate("optimization_suggestions.common.identical_files", language: language))\n"
                detailedDescription += "**📏 \(AnalyzerLocalizationService.translate("optimization_suggestions.common.size", language: language)):** \(duplicate.size.formattedSize) \(AnalyzerLocalizationService.translate("optimization_suggestions.common.per_file", language: language)) × \(duplicate.files.count) \(AnalyzerLocalizationService.translate("optimization_suggestions.common.copies", language: language)) = \(Int64(duplicate.size * Int64(duplicate.files.count)).formattedSize) \(AnalyzerLocalizationService.translate("optimization_suggestions.common.total", language: language))\n"
                detailedDescription += "**🗑️ \(AnalyzerLocalizationService.translate("optimization_suggestions.common.can_save", language: language)):** \(duplicate.wastedSpace.formattedSize) \(AnalyzerLocalizationService.translate("optimization_suggestions.common.by_keeping_only", language: language))\n"
                detailedDescription += "\n**📁 \(AnalyzerLocalizationService.translate("optimization_suggestions.common.file_locations", language: language)):**\n"
                for (fileIndex, file) in duplicate.files.enumerated() {
                    let fileName = file.split(separator: "/").last ?? "unknown"
                    if fileIndex == 0 {
                        detailedDescription += "• \(fileName) ← **\(AnalyzerLocalizationService.translate("optimization_suggestions.common.keep_this_one", language: language))**\n"
                        detailedDescription += "  `\(file)`\n"
                    } else {
                        detailedDescription += "• \(fileName) ← \(AnalyzerLocalizationService.translate("optimization_suggestions.common.remove", language: language))\n"
                        detailedDescription += "  `\(file)`\n"
                    }
                }
                if index < duplicates.count - 1 {
                    detailedDescription += "\n---\n"
                }
            }
            
            detailedDescription += "\n\n🔧 **\(AnalyzerLocalizationService.translate("optimization_suggestions.common.how_to_remove_duplicates", language: language)):**\n"
            detailedDescription += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.duplicate_files.review_each_group", language: language))\n"
            detailedDescription += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.duplicate_files.delete_duplicate_copies", language: language))\n"
            detailedDescription += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.duplicate_files.update_references", language: language))\n"
            detailedDescription += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.duplicate_files.clean_build_folder", language: language))\n"
            detailedDescription += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.duplicate_files.verify_functionality", language: language))\n"
            detailedDescription += "\n💰 **\(AnalyzerLocalizationService.translate("optimization_suggestions.common.total_potential_savings", language: language)):** \(wastedSpace.formattedSize)"
            
            let suggestion = OptimizationSuggestion(
                type: .duplicateFiles,
                severity: wastedSpace > 10_485_760 ? .high : .medium, // > 10MB is high
                title: AnalyzerLocalizationService.translate("optimization_suggestions.titles.remove_duplicate_files", language: language),
                description: detailedDescription,
                estimatedSavings: wastedSpace,
                affectedFiles: duplicates.flatMap { $0.files }
            )
            suggestions.append(suggestion)
        }
        
        // Check for large images
        if let imageMetrics = categorySizes[.image], imageMetrics.totalSize > 52_428_800 { // > 50MB
            let largeImages = content.files
                .filter { $0.category == .image && $0.size > 1_048_576 } // > 1MB
                .map { $0.path }
            
            let actionableDescription = "\(AnalyzerLocalizationService.translate("optimization_suggestions.large_images.images_consume", language: language)) \(imageMetrics.totalSize.formattedSize) (\(String(format: "%.1f", imageMetrics.percentage))% \(AnalyzerLocalizationService.translate("optimization_suggestions.large_images.of_app_size", language: language))).\n\n🔧 \(AnalyzerLocalizationService.translate("optimization_suggestions.common.actions_to_take", language: language)):\n• \(AnalyzerLocalizationService.translate("optimization_suggestions.large_images.webp_recommended", language: language))\n• \(AnalyzerLocalizationService.translate("optimization_suggestions.large_images.heif_warning", language: language))\n• \(AnalyzerLocalizationService.translate("optimization_suggestions.large_images.avif_modern", language: language))\n• \(AnalyzerLocalizationService.translate("optimization_suggestions.large_images.optimize_existing_png", language: language))\n• \(AnalyzerLocalizationService.translate("optimization_suggestions.large_images.reduce_unnecessary_resolution", language: language))\n\n⚠️ \(AnalyzerLocalizationService.translate("optimization_suggestions.common.warning", language: language)): \(AnalyzerLocalizationService.translate("optimization_suggestions.large_images.heif_transparency_warning", language: language))"
            
            let suggestion = OptimizationSuggestion(
                type: .largeImages,
                severity: imageMetrics.totalSize > 104_857_600 ? .high : .medium, // > 100MB is high
                title: AnalyzerLocalizationService.translate("optimization_suggestions.titles.optimize_large_images", language: language),
                description: actionableDescription,
                estimatedSavings: Int64(Double(imageMetrics.totalSize) * 0.3), // Estimate 30% savings
                affectedFiles: Array(largeImages.prefix(10))
            )
            suggestions.append(suggestion)
        }
        
        // Enhanced binary analysis suggestions from BinaryAnalyzer
        if let binary = binaryInfo {
            // Check for debug symbols
            if binary.hasDebugSymbols {
                let debugSymbolsSize = binary.estimatedDebugSymbolsSize
                var description = "\(AnalyzerLocalizationService.translate("optimization_suggestions.debug_symbols.debug_symbols_detected", language: language)) \(debugSymbolsSize.formattedSize) (\(String(format: "%.1f", Double(debugSymbolsSize) / Double(binary.size) * 100))% \(AnalyzerLocalizationService.translate("optimization_suggestions.debug_symbols.of_binary_size", language: language))).\n\n"
                description += "🔧 **\(AnalyzerLocalizationService.translate("optimization_suggestions.debug_symbols.actions_to_remove", language: language)):**\n\n"
                description += "**\(AnalyzerLocalizationService.translate("optimization_suggestions.debug_symbols.xcode_build_settings", language: language)):**\n"
                description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.debug_symbols.debug_info_format", language: language))\n"
                description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.debug_symbols.strip_debug_symbols", language: language))\n"
                description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.debug_symbols.strip_linked_product", language: language))\n"
                description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.debug_symbols.deployment_postprocessing", language: language))\n\n"
                description += "**\(AnalyzerLocalizationService.translate("optimization_suggestions.debug_symbols.manual_stripping", language: language)):**\n"
                description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.debug_symbols.strip_command", language: language))\n"
                description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.debug_symbols.strip_local", language: language))\n\n"
                description += "**\(AnalyzerLocalizationService.translate("optimization_suggestions.debug_symbols.archive_configuration", language: language)):**\n"
                description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.debug_symbols.release_configuration", language: language))\n"
                description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.debug_symbols.strip_swift_symbols", language: language))\n\n"
                description += "⚠️ **\(AnalyzerLocalizationService.translate("optimization_suggestions.common.important", language: language)):** \(AnalyzerLocalizationService.translate("optimization_suggestions.debug_symbols.keep_dsym_warning", language: language))\n\n"
                description += "💰 **\(AnalyzerLocalizationService.translate("optimization_suggestions.common.estimated_savings", language: language)):** \(debugSymbolsSize.formattedSize) \(AnalyzerLocalizationService.translate("optimization_suggestions.debug_symbols.reduction_in_app_size", language: language))"
                
                let debugSuggestion = OptimizationSuggestion(
                    type: .debugSymbols,
                    severity: debugSymbolsSize > 5_242_880 ? .high : .medium, // > 5MB is high
                    title: AnalyzerLocalizationService.translate("optimization_suggestions.titles.strip_debug_symbols", language: language),
                    description: description,
                    estimatedSavings: debugSymbolsSize,
                    affectedFiles: [binary.path]
                )
                suggestions.append(debugSuggestion)
            }
            
            // Check for unused architectures from binary analysis
            if binary.hasUnusedArchitectures {
                let legacyArchitectures = ["armv7", "i386", "x86_64"]
                let unusedArchs = binary.architectures.filter { arch in
                    legacyArchitectures.contains(arch)
                }
                
                var description = "\(AnalyzerLocalizationService.translate("optimization_suggestions.unused_architectures.found_unused_architectures", language: language)): \(unusedArchs.joined(separator: ", ")).\n\n"
                description += "🔧 **\(AnalyzerLocalizationService.translate("optimization_suggestions.unused_architectures.actions_to_remove_architectures", language: language)):**\n\n"
                description += "**\(AnalyzerLocalizationService.translate("optimization_suggestions.debug_symbols.xcode_build_settings", language: language)):**\n"
                if unusedArchs.contains("armv7") {
                    description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.unused_architectures.remove_armv7", language: language))\n"
                    description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.unused_architectures.set_deployment_target", language: language))\n"
                }
                if unusedArchs.contains("i386") || unusedArchs.contains("x86_64") {
                    description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.unused_architectures.remove_simulator_archs", language: language))\n"
                    description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.unused_architectures.simulator_only", language: language))\n"
                }
                description += "\n**\(AnalyzerLocalizationService.translate("optimization_suggestions.unused_architectures.build_for_distribution", language: language)):**\n"
                description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.unused_architectures.archive_excludes_simulator", language: language))\n"
                description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.unused_architectures.use_generic_device", language: language))\n\n"
                description += "**\(AnalyzerLocalizationService.translate("optimization_suggestions.unused_architectures.manual_architecture_control", language: language)):**\n"
                description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.unused_architectures.valid_architectures", language: language))\n"
                description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.unused_architectures.excluded_architectures", language: language))\n\n"
                description += "💡 **\(AnalyzerLocalizationService.translate("optimization_suggestions.common.tip", language: language)):** \(AnalyzerLocalizationService.translate("optimization_suggestions.unused_architectures.each_unused_arch", language: language))\n\n"
                description += "📱 **\(AnalyzerLocalizationService.translate("optimization_suggestions.unused_architectures.device_support_impact", language: language)):**\n"
                if unusedArchs.contains("armv7") {
                    description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.unused_architectures.removing_armv7", language: language))\n"
                }
                description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.unused_architectures.keep_arm64", language: language))\n"
                description += "\n💰 **\(AnalyzerLocalizationService.translate("optimization_suggestions.common.estimated_savings", language: language)):** \(AnalyzerLocalizationService.translate("optimization_suggestions.unused_architectures.binary_size_reduction", language: language))"
                
                let estimatedSavings = Int64(Double(binary.size) * 0.3 * Double(unusedArchs.count))
                
                let archSuggestion = OptimizationSuggestion(
                    type: .unusedArchitectures,
                    severity: .high,
                    title: AnalyzerLocalizationService.translate("optimization_suggestions.titles.remove_unused_architectures", language: language),
                    description: description,
                    estimatedSavings: estimatedSavings,
                    affectedFiles: [binary.path]
                )
                suggestions.append(archSuggestion)
            }
            
            // Check optimization level
            if !binary.isOptimized || binary.optimizationLevel.contains("O0") || binary.optimizationLevel.contains("None") {
                var description = "\(AnalyzerLocalizationService.translate("optimization_suggestions.swift_optimization.binary_not_optimized", language: language)) (\(binary.optimizationLevel)).\n\n"
                description += "🔧 **\(AnalyzerLocalizationService.translate("optimization_suggestions.swift_optimization.swift_compiler_optimization_settings", language: language)):**\n\n"
                description += "**\(AnalyzerLocalizationService.translate("optimization_suggestions.swift_optimization.release_configuration", language: language)):**\n"
                description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.swift_optimization.optimization_level_speed", language: language))\n"
                description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.swift_optimization.compilation_mode", language: language))\n"
                description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.swift_optimization.swift_code_generation", language: language))\n\n"
                description += "**\(AnalyzerLocalizationService.translate("optimization_suggestions.swift_optimization.size_critical_apps", language: language)):**\n"
                description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.swift_optimization.optimization_level_size", language: language))\n"
                description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.swift_optimization.optimize_for_size", language: language))\n\n"
                description += "**\(AnalyzerLocalizationService.translate("optimization_suggestions.swift_optimization.link_time_optimization", language: language)):**\n"
                description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.swift_optimization.lto_yes", language: language))\n"
                description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.swift_optimization.dead_code_stripping", language: language))\n\n"
                description += "**\(AnalyzerLocalizationService.translate("optimization_suggestions.swift_optimization.advanced_optimizations", language: language)):**\n"
                description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.swift_optimization.strip_unused_code", language: language))\n"
                description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.swift_optimization.enable_bitcode", language: language))\n"
                description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.swift_optimization.validate_built_product", language: language))\n\n"
                description += "📊 **\(AnalyzerLocalizationService.translate("optimization_suggestions.swift_optimization.expected_impact", language: language)):**\n"
                description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.swift_optimization.speed_optimization", language: language))\n"
                description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.swift_optimization.size_optimization", language: language))\n"
                description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.swift_optimization.whole_module", language: language))\n"
                description += "• \(AnalyzerLocalizationService.translate("optimization_suggestions.swift_optimization.lto_extra", language: language))\n\n"
                description += "⚠️ **\(AnalyzerLocalizationService.translate("optimization_suggestions.common.important", language: language)):** \(AnalyzerLocalizationService.translate("optimization_suggestions.swift_optimization.test_thoroughly", language: language))\n\n"
                description += "💡 **\(AnalyzerLocalizationService.translate("optimization_suggestions.common.tip", language: language)):** \(AnalyzerLocalizationService.translate("optimization_suggestions.swift_optimization.modern_swift_optimizations", language: language))"
                
                let optimizationSavings = Int64(Double(binary.size) * 0.25) // Estimate 25% savings
                
                let optimizationSuggestion = OptimizationSuggestion(
                    type: .swiftCompilerOptimization,
                    severity: .high,
                    title: AnalyzerLocalizationService.translate("optimization_suggestions.titles.enable_swift_optimization", language: language),
                    description: description,
                    estimatedSavings: optimizationSavings,
                    affectedFiles: [binary.path]
                )
                suggestions.append(optimizationSuggestion)
            }
        }
        
        // Check for unused architectures in frameworks (fallback if no binary info)
        if binaryInfo == nil {
            let architectures = Set(frameworks.flatMap { $0.architectures })
            if architectures.contains("armv7") || architectures.contains("i386") || architectures.contains("x86_64") {
                let unusedArchs = architectures.filter { 
                    $0 == "armv7" || $0 == "i386" || $0 == "x86_64" 
                }
                
                let suggestion = OptimizationSuggestion(
                    type: .unusedArchitectures,
                    severity: .medium,
                    title: AnalyzerLocalizationService.translate("optimization_titles.remove_unused_architectures", language: language),
                    description: AnalyzerLocalizationService.translate("simple_descriptions.found_unused_architectures", replacements: [unusedArchs.joined(separator: ", ")]),
                    estimatedSavings: analysis.frameworksSize / 4, // Rough estimate
                    affectedFiles: frameworks.filter { 
                        !$0.architectures.filter { unusedArchs.contains($0) }.isEmpty 
                    }.map { $0.path }
                )
                suggestions.append(suggestion)
            }
        }
        
        // Check for large frameworks
        let largeFrameworks = frameworks.filter { $0.size > 10_485_760 && !$0.isSystemFramework } // > 10MB
        if !largeFrameworks.isEmpty {
            let totalFrameworkSize = largeFrameworks.reduce(0) { $0 + $1.size }
            let suggestion = OptimizationSuggestion(
                type: .largeFrameworks,
                severity: totalFrameworkSize > 52_428_800 ? .high : .medium, // > 50MB is high
                title: AnalyzerLocalizationService.translate("optimization_titles.review_large_frameworks", language: language),
                description: AnalyzerLocalizationService.translate("simple_descriptions.found_large_frameworks", replacements: ["\(largeFrameworks.count)", totalFrameworkSize.formattedSize]),
                estimatedSavings: nil,
                affectedFiles: largeFrameworks.map { $0.path }
            )
            suggestions.append(suggestion)
        }
        
        // Check for uncompressed assets
        let uncompressedAssets = content.files.filter { 
            [.json, .xml, .plist].contains($0.category) && !$0.isCompressed && $0.size > 10240 // > 10KB
        }
        if !uncompressedAssets.isEmpty {
            let totalUncompressed = uncompressedAssets.reduce(0) { $0 + $1.size }
            let suggestion = OptimizationSuggestion(
                type: .uncompressedAssets,
                severity: .low,
                title: AnalyzerLocalizationService.translate("optimization_titles.compress_text_assets", language: language),
                description: AnalyzerLocalizationService.translate("simple_descriptions.found_uncompressed_files", replacements: ["\(uncompressedAssets.count)", totalUncompressed.formattedSize]),
                estimatedSavings: Int64(Double(totalUncompressed) * 0.6), // Estimate 60% compression
                affectedFiles: Array(uncompressedAssets.map { $0.path }.prefix(10))
            )
            suggestions.append(suggestion)
        }
        
        // Check for redundant localizations
        let localizationFiles = content.files.filter { $0.category == .localization }
        let localizationDirs = Set(localizationFiles.compactMap { file in
            file.path.components(separatedBy: "/").first { $0.contains(".lproj") }
        })
        
        if localizationDirs.count > 10 {
            let localizationSize = localizationFiles.reduce(0) { $0 + $1.size }
            let suggestion = OptimizationSuggestion(
                type: .redundantLocalizations,
                severity: .low,
                title: AnalyzerLocalizationService.translate("optimization_titles.review_localizations", language: language),
                description: AnalyzerLocalizationService.translate("simple_descriptions.app_supports_languages", replacements: ["\(localizationDirs.count)", localizationSize.formattedSize]),
                estimatedSavings: localizationSize / 2, // Estimate removing half
                affectedFiles: []
            )
            suggestions.append(suggestion)
        }
        
        // Assets.car specific optimizations - Group all similar suggestions
        let carResultsWithDuplicates = carAnalysisResults.filter { !$0.duplicates.isEmpty }
        let carResultsWithUnused = carAnalysisResults.filter { !$0.unusedAssets.isEmpty }
        let largeCarResults = carAnalysisResults.filter { $0.totalSize > 10_485_760 }
        
        // Group duplicate assets suggestions into one
        if !carResultsWithDuplicates.isEmpty {
            let totalDuplicateGroups = carResultsWithDuplicates.reduce(0) { $0 + $1.duplicates.count }
            let totalWastedSpace = carResultsWithDuplicates.reduce(0) { result, carResult in
                result + carResult.duplicates.reduce(0) { $0 + $1.wastedSpace }
            }
            
            var actionableDescription = AnalyzerLocalizationService.translate("detailed_messages.duplicate_assets_found", replacements: ["\(totalDuplicateGroups)", "\(carResultsWithDuplicates.count)", totalWastedSpace.formattedSize], language: language) + "\n\n"
            
            actionableDescription += "📂 **\(AnalyzerLocalizationService.translate("asset_optimization.affected_asset_catalogs"))**\n"
            for carResult in carResultsWithDuplicates {
                let catalogName = URL(fileURLWithPath: carResult.path).lastPathComponent
                let carWaste = carResult.duplicates.reduce(0) { $0 + $1.wastedSpace }
                let groupsText = AnalyzerLocalizationService.translate("simple_descriptions.groups_with_waste", replacements: ["\(carResult.duplicates.count)", carWaste.formattedSize])
                actionableDescription += "• **\(catalogName)**: \(groupsText)\n"
            }
            
            actionableDescription += "\n🔧 **\(AnalyzerLocalizationService.translate("simple_descriptions.how_to_remove_duplicates"))**\n\n"
            actionableDescription += "**\(AnalyzerLocalizationService.translate("simple_descriptions.step_1_xcode_review"))**\n"
            actionableDescription += "• Open each .xcassets folder in Xcode\n"
            actionableDescription += "• Use Asset Catalog inspector (View → Inspectors → Attributes)\n"
            actionableDescription += "• Look for identical images with different names or in different sets\n\n"
            actionableDescription += "**\(AnalyzerLocalizationService.translate("simple_descriptions.step_2_complete_list"))**\n"
            
            // Show ALL duplicate groups sorted by waste (largest first) with catalog locations
            var allDuplicatesWithCatalog: [(duplicate: AssetDuplicate, catalogPath: String)] = []
            for carResult in carResultsWithDuplicates {
                let catalogName = URL(fileURLWithPath: carResult.path).lastPathComponent
                for duplicate in carResult.duplicates {
                    allDuplicatesWithCatalog.append((duplicate: duplicate, catalogPath: catalogName))
                }
            }
            allDuplicatesWithCatalog.sort { $0.duplicate.wastedSpace > $1.duplicate.wastedSpace }
            
            for (index, item) in allDuplicatesWithCatalog.enumerated() {
                let duplicate = item.duplicate
                let catalogName = item.catalogPath
                let wasteMB = String(format: "%.1f", Double(duplicate.wastedSpace) / 1_048_576)
                // Handle cross-name duplicates differently from same-name duplicates
                let isDifferentNames = duplicate.name.contains("[") && duplicate.name.contains("]")
                
                if isDifferentNames {
                    // This is multiple assets with different names but identical content
                    actionableDescription += "**\(index + 1).** Multiple assets with identical content in **\(catalogName)** (\(wasteMB) MB waste)\n"
                    actionableDescription += "   These assets are identical but have different names:\n"
                    
                    // Extract asset names from "[name1, name2, name3]" format
                    let cleanName = duplicate.name.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                    let assetNames = cleanName.components(separatedBy: ", ")
                    
                    for (variantIndex, assetName) in assetNames.enumerated() {
                        let keepIndicator = variantIndex == 0 ? " ← **Keep this one**" : " ← **Delete this duplicate**"
                        actionableDescription += "   • **\(assetName)**\(keepIndicator)\n"
                    }
                } else {
                    // Regular same-name duplicate with different variants (@1x, @2x, etc.)
                    actionableDescription += "**\(index + 1).** '\(duplicate.name)' in **\(catalogName)** - \(duplicate.variants.count) identical variants (\(wasteMB) MB waste)\n"
                    
                    // Show all variant details for each duplicate group with precise locations
                    for (variantIndex, variant) in duplicate.variants.enumerated() {
                        let keepIndicator = variantIndex == 0 ? " ← **Keep**" : " ← **Remove**"
                        
                        // Use renditionKey if available (most precise), otherwise use scale info
                        if !variant.renditionKey.isEmpty {
                            actionableDescription += "   • `\(variant.renditionKey)`\(keepIndicator)\n"
                        } else {
                            let idiomInfo = variant.idiom != "universal" ? " (\(variant.idiom))" : ""
                            let sizeInfo = !variant.size.isEmpty && variant.size != "0x0" ? " \(variant.size)px" : ""
                            actionableDescription += "   • \(variant.scale)\(idiomInfo)\(sizeInfo)\(keepIndicator)\n"
                        }
                    }
                }
                actionableDescription += "\n"
            }
            
            actionableDescription += "\n**\(AnalyzerLocalizationService.translate("simple_descriptions.step_3_clean_up"))**\n"
            actionableDescription += "• Keep the best quality/most accessible version\n"
            actionableDescription += "• Delete duplicate copies from asset catalogs\n"
            actionableDescription += "• Update any code references to use the remaining asset\n"
            actionableDescription += "• Build and test to ensure no missing images\n\n"
            actionableDescription += "💡 **Tip:** Use external tools like Duplicate Detective or Image Capture for bulk duplicate detection across multiple catalogs.\n\n"
            actionableDescription += "💰 **Total potential savings:** \(totalWastedSpace.formattedSize)"
            
            let suggestion = OptimizationSuggestion(
                type: .assetCatalogDuplicates,
                severity: totalWastedSpace > 5_242_880 ? .high : .medium, // > 5MB is high
                title: AnalyzerLocalizationService.translate("optimization_titles.remove_duplicate_assets", language: language),
                description: actionableDescription,
                estimatedSavings: totalWastedSpace,
                affectedFiles: carResultsWithDuplicates.map { $0.path }
            )
            suggestions.append(suggestion)
        }
        
        // Group unused assets suggestions into one
        if !carResultsWithUnused.isEmpty {
            let totalUnusedAssets = carResultsWithUnused.reduce(0) { $0 + $1.unusedAssets.count }
            let totalUnusedSavings = carResultsWithUnused.reduce(0) { $0 + $1.optimizationPotential }
            
            var actionableDescription = AnalyzerLocalizationService.translate("detailed_messages.unused_assets_found", replacements: ["\(totalUnusedAssets)", "\(carResultsWithUnused.count)"], language: language) + "\n\n"
            
            actionableDescription += "📂 **\(AnalyzerLocalizationService.translate("asset_optimization.affected_asset_catalogs"))**\n"
            for carResult in carResultsWithUnused {
                let catalogName = URL(fileURLWithPath: carResult.path).lastPathComponent
                actionableDescription += "• **\(catalogName)**: \(carResult.unusedAssets.count) unused assets\n"
            }
            
            actionableDescription += "\n🔍 **Asset Analysis:**\n"
            let allUnusedAssets = carResultsWithUnused.flatMap { $0.unusedAssets }
            let assetsByType = Dictionary(grouping: allUnusedAssets) { $0.type }
            for (type, assets) in assetsByType.sorted(by: { $0.value.count > $1.value.count }) {
                actionableDescription += "• **\(type)**: \(assets.count) assets\n"
            }
            
            actionableDescription += "\n⚠️ **Important Note:**\n"
            actionableDescription += "\(AnalyzerLocalizationService.translate("simple_descriptions.potentially_unused_warning"))\n\n"
            actionableDescription += "🔧 **Verification Steps:**\n"
            actionableDescription += "• Test your app on iPad (if you support iPad)\n"
            actionableDescription += "• Search your codebase for asset names\n"
            actionableDescription += "• Check Interface Builder files (.storyboard, .xib)\n"
            actionableDescription += "• Verify no dynamic image loading uses these assets\n\n"
            actionableDescription += "💡 **Safe Removal Process:**\n"
            actionableDescription += "• Create a backup of your project first\n"
            actionableDescription += "• Remove assets gradually in small batches\n"
            actionableDescription += "• Test thoroughly on all supported devices\n"
            actionableDescription += "• Use App Store Connect to verify no crashes after release\n\n"
            actionableDescription += "💰 **Potential savings:** \(totalUnusedSavings.formattedSize) (if truly unused)"
            
            let suggestion = OptimizationSuggestion(
                type: .unusedAssets,
                severity: .medium,
                title: AnalyzerLocalizationService.translate("optimization_titles.review_unused_assets", language: language),
                description: actionableDescription,
                estimatedSavings: totalUnusedSavings,
                affectedFiles: carResultsWithUnused.map { $0.path }
            )
            suggestions.append(suggestion)
        }
        
        // Group large asset catalog optimizations
        if !largeCarResults.isEmpty {
            let totalSize = largeCarResults.reduce(0) { $0 + $1.totalSize }
            let estimatedCompressionSavings = Int64(Double(totalSize) * 0.15) // 15% compression estimate
            
            var actionableDescription = AnalyzerLocalizationService.translate("detailed_messages.large_catalogs_found", replacements: ["\(largeCarResults.count)", totalSize.formattedSize], language: language) + "\n\n"
            
            actionableDescription += "📂 **\(AnalyzerLocalizationService.translate("asset_optimization.large_asset_catalogs")):**\n"
            for carResult in largeCarResults.sorted(by: { $0.totalSize > $1.totalSize }) {
                let catalogName = URL(fileURLWithPath: carResult.path).lastPathComponent
                let sizeMB = String(format: "%.1f", Double(carResult.totalSize) / 1_048_576)
                actionableDescription += "• **\(catalogName)**: \(sizeMB) MB\n"
            }
            
            actionableDescription += "\n🔧 **\(AnalyzerLocalizationService.translate("asset_optimization.comprehensive_optimization_strategy"))**\n\n"
            actionableDescription += "**Modern Format Migration (iOS 14+):**\n"
            actionableDescription += "• **WebP**: RECOMMANDÉ pour PNG avec transparence (25-35% réduction)\n"
            actionableDescription += "• **HEIF/HEIC**: Pour photos/backgrounds OPAQUES uniquement (30-50% réduction)\n"
            actionableDescription += "• **AVIF** (iOS 16+): Le plus léger avec alpha, si vous ciblez iOS 16+\n\n"
            actionableDescription += "**Xcode Asset Catalog Settings:**\n"
            actionableDescription += "• Compression: Set to 'Automatic' or 'Lossy' for photos\n"
            actionableDescription += "• Memory: Enable 'Optimize for Speed' or 'Optimize for Space'\n"
            actionableDescription += "• Rendering: Use 'Template' for single-color assets\n\n"
            actionableDescription += "**Resolution Optimization:**\n"
            actionableDescription += "• Remove @1x variants (no longer needed for modern devices)\n"
            actionableDescription += "• Keep @2x for standard displays, @3x for Plus/Pro devices\n"
            actionableDescription += "• Enable 'Preserve Vector Data' for PDF assets (scales automatically)\n\n"
            actionableDescription += "**Advanced Techniques:**\n"
            actionableDescription += "• On-Demand Resources for large/optional content\n"
            actionableDescription += "• App Thinning to deliver device-specific assets only\n"
            actionableDescription += "• Asset compression in Build Settings\n\n"
            actionableDescription += "⚠️ **Critical Warning:**\n"
            actionableDescription += "HEIF/HEIC peut supprimer la transparence dans certains pipelines iOS. Pour préserver l'alpha channel, utilisez WebP ou PNG optimisé.\n\n"
            actionableDescription += "💰 **Estimated compression savings:** \(estimatedCompressionSavings.formattedSize) (\(String(format: "%.0f", Double(estimatedCompressionSavings) / Double(totalSize) * 100))% reduction)"
            
            let suggestion = OptimizationSuggestion(
                type: .assetCatalogOptimization,
                severity: totalSize > 52_428_800 ? .high : .medium,
                title: AnalyzerLocalizationService.translate("optimization_titles.optimize_asset_catalogs", language: language),
                description: actionableDescription,
                estimatedSavings: estimatedCompressionSavings,
                affectedFiles: largeCarResults.map { $0.path }
            )
            suggestions.append(suggestion)
        }
        
        // Skip build configuration suggestions - cannot be detected from IPA
        // These are now covered in the "Expert Tips" section instead
        
        // Localization optimization suggestions
        if let localizationAnalysis = analysis.localizationAnalysis {
            addLocalizationSuggestions(&suggestions, analysis: localizationAnalysis)
        }
        
        // Advanced framework optimization suggestions
        addAdvancedFrameworkSuggestions(&suggestions, frameworks: frameworks)
        
        // On-Demand Resources opportunities
        addOnDemandResourcesSuggestions(&suggestions, from: content, categorySizes: categorySizes)
        
        // Sort by severity and estimated savings
        return suggestions.sorted { lhs, rhs in
            if lhs.severity != rhs.severity {
                return severityOrder(lhs.severity) > severityOrder(rhs.severity)
            }
            return (lhs.estimatedSavings ?? 0) > (rhs.estimatedSavings ?? 0)
        }
    }
    
    private func severityOrder(_ severity: SuggestionSeverity) -> Int {
        switch severity {
        case .critical: return 5
        case .high: return 4
        case .medium: return 3
        case .low: return 2
        case .info: return 1
        }
    }
    
    // MARK: - Advanced Optimization Methods
    
    private func addAdvancedFrameworkSuggestions(_ suggestions: inout [OptimizationSuggestion], frameworks: [FrameworkInfo]) {
        let thirdPartyFrameworks = frameworks.filter { !$0.isSystemFramework }
        let totalThirdPartySize = thirdPartyFrameworks.reduce(0) { $0 + $1.size }
        
        if totalThirdPartySize > 5_242_880 { // > 5MB
            var description = "\(AnalyzerLocalizationService.translate("optimization_messages.framework_optimization"))\n\n"
            description += "🔧 \(AnalyzerLocalizationService.translate("optimization_messages.advanced_framework_strategy"))\n\n"
            description += "**\(AnalyzerLocalizationService.translate("optimization_messages.lightweight_alternatives"))**\n"
            
            var alternatives: [String] = []
            var potentialSavings: Int64 = 0
            
            for framework in thirdPartyFrameworks {
                let name = framework.name.lowercased()
                if name.contains("alamofire") {
                    alternatives.append("• Alamofire (~2MB) → URLSession + custom wrapper (0KB) = 2MB saved")
                    potentialSavings += 2_097_152
                } else if name.contains("sdwebimage") {
                    alternatives.append("• SDWebImage (~3MB) → Kingfisher (1.2MB) or native caching = 1.8MB saved")
                    potentialSavings += 1_887_437
                } else if name.contains("realm") {
                    alternatives.append("• Realm (~8MB) → CoreData + optimizations (native) = 8MB saved")
                    potentialSavings += 8_388_608
                } else if name.contains("firebase") {
                    alternatives.append("• Firebase SDK (~15MB) → Individual components only = 8-12MB saved")
                    potentialSavings += 10_485_760
                } else if name.contains("lottie") {
                    alternatives.append("• Lottie (~4MB) → Core Animation for simple animations = 2-4MB saved")
                    potentialSavings += 3_145_728
                }
                
                if framework.size > 10_485_760 { // > 10MB
                    alternatives.append("• \(framework.name) (\(String(format: "%.1f", Double(framework.size) / 1_048_576))MB) → Evaluate if all features are needed")
                }
            }
            
            if !alternatives.isEmpty {
                description += alternatives.joined(separator: "\n") + "\n\n"
            }
            
            description += "**\(AnalyzerLocalizationService.translate("asset_optimization.dynamic_vs_static"))**\n\n"
            description += "**Use Static Frameworks When:** (20-30% smaller)\n"
            description += "• App size is critical concern\n"
            description += "• Fast startup time is priority (+15-20ms per dynamic framework)\n"
            description += "• Single-app deployment\n\n"
            description += "**Use Dynamic Frameworks When:** (50%+ reduction possible)\n"
            description += "• Multiple apps share frameworks\n"
            description += "• App Extensions are used\n"
            description += "• Large shared frameworks >20MB\n\n"
            description += "**Apple Recommendation:** Maximum 6 dynamic frameworks for optimal startup performance.\n\n"
            description += "💡 Framework thinning combined with proper static/dynamic strategy can achieve dramatic size reductions."
            
            let suggestion = OptimizationSuggestion(
                type: .frameworkAlternatives,
                severity: totalThirdPartySize > 20_971_520 ? .high : .medium,
                title: AnalyzerLocalizationService.translate("optimization_titles.optimize_framework_usage"),
                description: description,
                estimatedSavings: max(potentialSavings, Int64(Double(totalThirdPartySize) * 0.20)),
                affectedFiles: thirdPartyFrameworks.map { $0.path }
            )
            suggestions.append(suggestion)
        }
    }
    
    private func addOnDemandResourcesSuggestions(_ suggestions: inout [OptimizationSuggestion], from content: IPAContent, categorySizes: [FileCategory: CategoryMetrics]) {
        // Check for ODR opportunities based on content analysis
        let videoSize = categorySizes[.video]?.totalSize ?? 0
        let audioSize = categorySizes[.audio]?.totalSize ?? 0  
        let imageSize = categorySizes[.image]?.totalSize ?? 0
        let documentsSize = categorySizes[.document]?.totalSize ?? 0
        
        let odrCandidateSize = videoSize + audioSize + (imageSize > 50_331_648 ? imageSize / 2 : 0) + documentsSize
        
        if odrCandidateSize > 10_485_760 { // > 10MB potential ODR content
            var description = "\(AnalyzerLocalizationService.translate("optimization_messages.on_demand_resources"))\n\n"
            description += "🔧 \(AnalyzerLocalizationService.translate("asset_optimization.implementation_strategy"))\n\n"
            description += "**\(AnalyzerLocalizationService.translate("asset_optimization.step_1_xcode"))**\n"
            description += "• Select large assets → Resource Tags → Add tags\n"
            description += "• Recommended tags: 'level1', 'level2', 'premium_content'\n"
            description += "• Tag assets that aren't needed immediately at app launch\n\n"
            
            if videoSize > 5_242_880 {
                description += "**Video Content (\(String(format: "%.1f", Double(videoSize) / 1_048_576))MB detected):**\n"
                description += "• Tag tutorial videos, intro sequences, optional content\n"
                description += "• Keep only essential startup videos in main bundle\n\n"
            }
            
            if audioSize > 2_097_152 {
                description += "**Audio Content (\(String(format: "%.1f", Double(audioSize) / 1_048_576))MB detected):**\n"
                description += "• Tag background music, sound effects, voice overs\n"
                description += "• Keep only critical UI sounds in main bundle\n\n"
            }
            
            if imageSize > 20_971_520 {
                description += "**Image Content (\(String(format: "%.1f", Double(imageSize) / 1_048_576))MB detected):**\n"
                description += "• Tag level backgrounds, user guide images, optional graphics\n"
                description += "• Keep only essential UI elements in main bundle\n\n"
            }
            
            description += "**\(AnalyzerLocalizationService.translate("asset_optimization.step_2_programmatic"))**\n"
            description += "```objc\n"
            description += "NSBundleResourceRequest *request = [[NSBundleResourceRequest alloc] \n"
            description += "    initWithTags:@[@\"level2\"]];\n"
            description += "[request beginAccessingResourcesWithCompletionHandler:^(NSError *error) {\n"
            description += "    // Load level 2 assets when needed\n"
            description += "}];\n\n"
            description += "// Important: Release when done\n"
            description += "[request endAccessingResources]; // System can purge when memory needed\n"
            description += "```\n\n"
            description += "**\(AnalyzerLocalizationService.translate("asset_optimization.step_3_benefits"))**\n"
            description += "• Initial download reduced by 50-70%\n"
            description += "• User retention +25% (faster initial download)\n"
            description += "• Automatic storage management by iOS\n\n"
            description += "⚠️ TESTING: Always test ODR on slower networks to ensure good UX.\n\n"
            description += "💡 Apps using ODR see significant improvements in conversion rates due to faster initial downloads."
            
            let suggestion = OptimizationSuggestion(
                type: .onDemandResources,
                severity: .high,
                title: AnalyzerLocalizationService.translate("optimization_titles.implement_odr"),
                description: description,
                estimatedSavings: Int64(Double(odrCandidateSize) * 0.60), // 60% of candidate content
                affectedFiles: []
            )
            suggestions.append(suggestion)
        }
        
        // App Thinning suggestion - always relevant for apps >30MB
        let totalSize = content.files.reduce(0) { $0 + $1.size }
        if totalSize > 31_457_280 { // > 30MB
            var appThinningDescription = "⚠️ **Note:** App Thinning is performed automatically by Apple on the App Store, not detectable in this IPA analysis.\n\n"
            appThinningDescription += "\(AnalyzerLocalizationService.translate("simple_descriptions.app_thinning_automatic"))\n\n"
            appThinningDescription += "🔧 **To Optimize for App Thinning:**\n\n"
            appThinningDescription += "**Asset Catalog Organization (CRITICAL):**\n"
            appThinningDescription += "• Move ALL images to Assets.xcassets (remove loose image files)\n"
            appThinningDescription += "• Provide proper device variants:\n"
            appThinningDescription += "  - iPhone: @2x, @3x variants\n"
            appThinningDescription += "  - iPad: @1x, @2x variants\n"
            appThinningDescription += "  - Universal: Complete variants for maximum thinning benefit\n\n"
            appThinningDescription += "**This IPA contains your full universal binary (\(String(format: "%.1f", Double(totalSize) / 1_048_576))MB)**\n"
            appThinningDescription += "**After App Store processing, users will download:**\n"
            appThinningDescription += "• iPhone 15 Pro: ~\(String(format: "%.1f", Double(totalSize) * 0.5 / 1_048_576))MB (est. 50% smaller)\n"
            appThinningDescription += "• iPad Pro: ~\(String(format: "%.1f", Double(totalSize) * 0.4 / 1_048_576))MB (est. 60% smaller)\n"
            appThinningDescription += "• iPhone SE: ~\(String(format: "%.1f", Double(totalSize) * 0.3 / 1_048_576))MB (est. 70% smaller)\n\n"
            appThinningDescription += "**Verification:**\n"
            appThinningDescription += "• Check App Store Connect after upload to see device-specific sizes\n"
            appThinningDescription += "• Test downloads on different devices to confirm size reduction\n\n"
            appThinningDescription += "💡 App Thinning is automatic but requires proper asset organization to be effective!"
            
            let appThinningSuggestion = OptimizationSuggestion(
                type: .appThinning,
                severity: .medium, // Reduced since it's automatic by Apple
                title: AnalyzerLocalizationService.translate("optimization_titles.optimize_app_thinning"),
                description: appThinningDescription,
                estimatedSavings: nil, // No direct savings since it's handled by App Store
                affectedFiles: []
            )
            suggestions.append(appThinningSuggestion)
        }
        
        // Add largest files review suggestion
        let largestFiles = content.files
            .filter { $0.size > 1_048_576 } // > 1MB files
            .sorted { $0.size > $1.size }
            .prefix(20)
        
        if !largestFiles.isEmpty {
            let totalLargeFileSize = largestFiles.reduce(0) { $0 + $1.size }
            
            var largestFilesDescription = AnalyzerLocalizationService.translate("optimization_messages.large_files_found", replacements: ["\(largestFiles.count)", totalLargeFileSize.formattedSize])
            
            largestFilesDescription += "\n\n📋 **\(AnalyzerLocalizationService.translate("optimization_messages.complete_analysis"))**\n"
            for (index, file) in largestFiles.enumerated() {
                let fileName = URL(fileURLWithPath: file.path).lastPathComponent
                let percentage = Double(file.size) / Double(totalSize) * 100
                largestFilesDescription += "\n**\(index + 1).** \(fileName)\n"
                largestFilesDescription += "💾 **Size:** \(file.size.formattedSize) (\(String(format: "%.1f", percentage))% of app)\n"
                largestFilesDescription += "📁 **Path:** \(file.path)\n"
                largestFilesDescription += "📂 **Category:** \(file.category.rawValue.capitalized)\n"
            }
            
            largestFilesDescription += "\n\n🔧 **\(AnalyzerLocalizationService.translate("optimization_messages.optimization_actions"))**\n"
            largestFilesDescription += "📸 **\(AnalyzerLocalizationService.translate("optimization_messages.images_action"))**\n"
            largestFilesDescription += "🎵 **\(AnalyzerLocalizationService.translate("optimization_messages.audio_action"))**\n"
            largestFilesDescription += "🎬 **\(AnalyzerLocalizationService.translate("optimization_messages.video_action"))**\n"
            largestFilesDescription += "📚 **\(AnalyzerLocalizationService.translate("optimization_messages.frameworks_action"))**\n"
            largestFilesDescription += "📄 **\(AnalyzerLocalizationService.translate("optimization_messages.data_action"))**\n"
            largestFilesDescription += "🏗️ **\(AnalyzerLocalizationService.translate("optimization_messages.executables_action"))**\n"
            
            largestFilesDescription += "\n\n💡 **\(AnalyzerLocalizationService.translate("optimization_messages.quick_wins")):**\n"
            largestFilesDescription += "• \(AnalyzerLocalizationService.translate("optimization_messages.focus_large_files"))\n"
            largestFilesDescription += "• \(AnalyzerLocalizationService.translate("optimization_messages.use_app_thinning"))\n"
            largestFilesDescription += "• \(AnalyzerLocalizationService.translate("optimization_messages.consider_odr"))\n"
            largestFilesDescription += "• \(AnalyzerLocalizationService.translate("optimization_messages.enable_compression"))"
            
            let largestFilesSuggestion = OptimizationSuggestion(
                type: .unusedAssets, // We'll reuse this type as it's closest
                severity: totalLargeFileSize > 50_000_000 ? .high : .medium, // >50MB high priority
                title: AnalyzerLocalizationService.translate("optimization_titles.review_largest_files"),
                description: largestFilesDescription,
                estimatedSavings: Int64(Double(totalLargeFileSize) * 0.3), // Estimate 30% reduction potential
                affectedFiles: Array(largestFiles.map { $0.path })
            )
            suggestions.append(largestFilesSuggestion)
        }
    }
    
    private func addLocalizationSuggestions(_ suggestions: inout [OptimizationSuggestion], analysis: LocalizationAnalysis) {
        // Unused languages suggestion
        if !analysis.unusedLanguages.isEmpty {
            let languageNames = analysis.unusedLanguages.compactMap { code in
                analysis.languages.first(where: { $0.code == code })?.name ?? code
            }.joined(separator: ", ")
            
            let totalUnusedSize = analysis.unusedLanguages.reduce(Int64(0)) { total, code in
                let lang = analysis.languages.first { $0.code == code }
                return total + (lang?.size ?? 0)
            }
            
            var description = AnalyzerLocalizationService.translate("detailed_messages.unused_languages_found", replacements: ["\(analysis.unusedLanguages.count)", totalUnusedSize.formattedSize]) + "\n\n"
            description += "🌍 **Unused Languages:** \(languageNames)\n\n"
            description += "🔧 **Actions to remove unused localizations:**\n\n"
            description += "**In Xcode:**\n"
            description += "• Select your project in navigator\n"
            description += "• Go to Project Info tab\n"
            description += "• Under 'Localizations' section, remove unused languages\n"
            description += "• Delete .lproj folders for removed languages\n\n"
            description += "**Build Settings:**\n"
            description += "• Check 'Localization Export Supported' setting\n"
            description += "• Remove unused language codes from 'Supported Languages'\n\n"
            description += "**Verification:**\n"
            description += "• Clean build folder (⌘⇧K)\n"
            description += "• Archive and check resulting IPA size\n"
            description += "• Test app functionality in remaining languages\n\n"
            description += "💰 **Estimated savings:** \(totalUnusedSize.formattedSize)"
            
            let suggestion = OptimizationSuggestion(
                type: .redundantLocalizations,
                severity: totalUnusedSize > 5_242_880 ? .high : .medium,
                title: AnalyzerLocalizationService.translate("optimization_titles.remove_unused_languages"),
                description: description,
                estimatedSavings: totalUnusedSize,
                affectedFiles: analysis.unusedLanguages.flatMap { code in
                    analysis.languages.first { $0.code == code }?.files ?? []
                }
            )
            suggestions.append(suggestion)
        }
        
        // Oversized languages suggestion
        if !analysis.oversizedLanguages.isEmpty {
            let oversizedLangs = analysis.oversizedLanguages.compactMap { code in
                analysis.languages.first(where: { $0.code == code })
            }
            
            let totalOversizedSize = oversizedLangs.reduce(0) { $0 + $1.size }
            
            var description = AnalyzerLocalizationService.translate("detailed_messages.oversized_languages_found", replacements: ["\(analysis.oversizedLanguages.count)", totalOversizedSize.formattedSize]) + "\n\n"
            description += "🔍 **Large Language Analysis:**\n\n"
            
            for lang in oversizedLangs.prefix(5) {
                description += "**\(lang.name) (\(lang.code)):**\n"
                description += "• Size: \(lang.size.formattedSize) (\(lang.fileCount) files)\n"
                description += "• Strings files: \(lang.stringFilesCount)\n"
                description += "• Storyboards: \(lang.storyboardFilesCount)\n\n"
            }
            
            if oversizedLangs.count > 5 {
                description += "*And \(oversizedLangs.count - 5) more large language packs...*\n\n"
            }
            
            description += "🔧 **Optimization Actions:**\n\n"
            description += "**String Optimization:**\n"
            description += "• Use NSLocalizedString with shorter keys\n"
            description += "• Remove unused localization strings\n"
            description += "• Use .stringsdict for plurals (more efficient)\n\n"
            description += "**Interface Builder:**\n"
            description += "• Convert localized XIBs/Storyboards to code\n"
            description += "• Use programmatic UI for better size control\n"
            description += "• Share common UI elements across languages\n\n"
            description += "**Advanced Techniques:**\n"
            description += "• On-Demand Resources for secondary languages\n"
            description += "• Server-side translations for dynamic content\n"
            description += "• Compress large localization files\n\n"
            description += "💰 **Potential savings:** \(Int64(Double(totalOversizedSize) * 0.4).formattedSize) (40% compression)"
            
            let suggestion = OptimizationSuggestion(
                type: .redundantLocalizations,
                severity: totalOversizedSize > 20_971_520 ? .high : .medium,
                title: AnalyzerLocalizationService.translate("optimization_titles.optimize_large_languages"),
                description: description,
                estimatedSavings: Int64(Double(totalOversizedSize) * 0.4),
                affectedFiles: oversizedLangs.flatMap { $0.files }.prefix(20).map { String($0) }
            )
            suggestions.append(suggestion)
        }
        
        // Too many languages suggestion
        if analysis.totalLanguages > 20 {
            let topLanguagesBySize = analysis.languages.prefix(10)
            let bottomLanguages = analysis.languages.dropFirst(10)
            let bottomLanguagesSize = bottomLanguages.reduce(0) { $0 + $1.size }
            
            var description = AnalyzerLocalizationService.translate("detailed_messages.many_languages_warning", replacements: ["\(analysis.totalLanguages)"]) + "\n\n"
            description += "🌍 **Language Distribution Analysis:**\n\n"
            description += "**Top 10 Languages (Keep):**\n"
            
            for (index, lang) in topLanguagesBySize.enumerated() {
                let percentage = Double(lang.size) / Double(analysis.totalSize) * 100
                description += "\(index + 1). \(lang.name): \(lang.size.formattedSize) (\(String(format: "%.1f", percentage))%)\n"
            }
            
            description += "\n**Remaining \(analysis.totalLanguages - 10) Languages:**\n"
            description += "• Total size: \(bottomLanguagesSize.formattedSize)\n"
            description += "• Average size: \(Int64(bottomLanguagesSize / Int64(bottomLanguages.count)).formattedSize) per language\n\n"
            
            description += "🔧 **Optimization Strategy:**\n\n"
            description += "**Phase 1: Core Languages (Immediate)**\n"
            description += "• Keep top 5-10 languages by market size\n"
            description += "• Focus on primary revenue markets\n"
            description += "• Consider English + 4-9 regional languages\n\n"
            description += "**Phase 2: On-Demand Localization**\n"
            description += "• Use server-side translations for secondary markets\n"
            description += "• Implement On-Demand Resources for additional languages\n"
            description += "• Allow users to download language packs as needed\n\n"
            description += "📊 **Market Prioritization Tips:**\n"
            description += "• Analyze App Store Connect analytics for language usage\n"
            description += "• Focus on countries with highest revenue per user\n"
            description += "• Consider population size vs localization maintenance cost\n\n"
            description += "💰 **Estimated savings:** \(bottomLanguagesSize.formattedSize) by removing \(analysis.totalLanguages - 10) languages"
            
            let suggestion = OptimizationSuggestion(
                type: .redundantLocalizations,
                severity: analysis.totalLanguages > 30 ? .high : .medium,
                title: AnalyzerLocalizationService.translate("optimization_titles.reduce_language_count"),
                description: description,
                estimatedSavings: bottomLanguagesSize,
                affectedFiles: bottomLanguages.flatMap { $0.files }.prefix(20).map { String($0) }
            )
            suggestions.append(suggestion)
        }
        
        // General localization optimization if significant size
        if analysis.totalSize > 10_485_760 { // > 10MB
            var description = AnalyzerLocalizationService.translate("detailed_messages.localization_summary", replacements: [analysis.totalSize.formattedSize]) + "\n\n"
            description += "📈 **Localization Summary:**\n"
            description += "• Total languages: \(analysis.totalLanguages)\n"
            description += "• Total files: \(analysis.totalFiles)\n"
            description += "• Average per language: \(Int64(analysis.totalSize / Int64(analysis.totalLanguages)).formattedSize)\n\n"
            
            if !analysis.recommendations.isEmpty {
                description += "🔧 **Recommended Actions:**\n"
                for recommendation in analysis.recommendations {
                    description += "• \(recommendation)\n"
                }
                description += "\n"
            }
            
            description += "💡 **Advanced Localization Strategies:**\n"
            description += "• Use base localization to reduce duplicate files\n"
            description += "• Implement string deduplication across languages\n"
            description += "• Convert static localizations to dynamic loading\n"
            description += "• Use more efficient file formats (.stringsdict vs .strings)\n"
            description += "• Consider context-aware translations to reduce string count\n\n"
            description += "💰 **Optimization potential:** \(analysis.optimizationPotential.formattedSize)"
            
            let suggestion = OptimizationSuggestion(
                type: .redundantLocalizations,
                severity: analysis.totalSize > 52_428_800 ? .high : .medium,
                title: AnalyzerLocalizationService.translate("optimization_titles.optimize_localization_strategy"),
                description: description,
                estimatedSavings: analysis.optimizationPotential,
                affectedFiles: []
            )
            suggestions.append(suggestion)
        }
    }
}