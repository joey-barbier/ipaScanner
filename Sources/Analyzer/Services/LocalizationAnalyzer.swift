import Foundation
import IPAFoundation

public class LocalizationAnalyzer {
    
    public init() {}
    
    public func analyzeLocalizations(from files: [IPAFile]) -> LocalizationAnalysis {
        let localizationFiles = files.filter { $0.category == .localization }
        
        // Group files by language
        var languageGroups: [String: [IPAFile]] = [:]
        var languagesSizes: [String: Int64] = [:]
        
        for file in localizationFiles {
            if let language = extractLanguage(from: file.path) {
                languageGroups[language, default: []].append(file)
                languagesSizes[language, default: 0] += file.size
            }
        }
        
        // Analyze each language
        var languageDetails: [LocalizationLanguage] = []
        var totalSize: Int64 = 0
        
        for (language, files) in languageGroups {
            let size = languagesSizes[language] ?? 0
            totalSize += size
            
            let fileTypes = analyzeFileTypes(in: files)
            let stringFiles = files.filter { $0.path.hasSuffix(".strings") }
            let storyboardFiles = files.filter { $0.path.hasSuffix(".storyboard") || $0.path.hasSuffix(".xib") }
            
            let languageDetail = LocalizationLanguage(
                code: language,
                name: languageName(for: language),
                fileCount: files.count,
                size: size,
                stringFilesCount: stringFiles.count,
                storyboardFilesCount: storyboardFiles.count,
                fileTypes: fileTypes,
                files: files.map { $0.path }
            )
            
            languageDetails.append(languageDetail)
        }
        
        // Sort by size (largest first)
        languageDetails.sort { $0.size > $1.size }
        
        // Detect issues
        let unusedLanguages = detectUnusedLanguages(languageDetails)
        let oversizedLanguages = languageDetails.filter { $0.size > 5_242_880 } // > 5MB
        let incompleteLanguages = detectIncompleteLocalizations(languageDetails)
        let duplicateContent = detectDuplicateContent(languageDetails)
        
        // Calculate optimization potential
        let optimizationPotential = calculateOptimizationPotential(
            unusedLanguages: unusedLanguages,
            oversizedLanguages: oversizedLanguages,
            duplicateContent: duplicateContent
        )
        
        return LocalizationAnalysis(
            totalLanguages: languageDetails.count,
            totalSize: totalSize,
            totalFiles: localizationFiles.count,
            languages: languageDetails,
            unusedLanguages: unusedLanguages,
            oversizedLanguages: oversizedLanguages.map { $0.code },
            incompleteLanguages: incompleteLanguages,
            duplicateContent: duplicateContent,
            optimizationPotential: optimizationPotential,
            recommendations: generateRecommendations(
                languageDetails: languageDetails,
                unusedLanguages: unusedLanguages,
                oversizedLanguages: oversizedLanguages
            )
        )
    }
    
    private func extractLanguage(from path: String) -> String? {
        let components = path.components(separatedBy: "/")
        for component in components {
            if component.hasSuffix(".lproj") {
                return component.replacingOccurrences(of: ".lproj", with: "")
            }
        }
        return nil
    }
    
    private func languageName(for code: String) -> String {
        let languageNames: [String: String] = [
            "en": "English",
            "fr": "French",
            "es": "Spanish", 
            "de": "German",
            "it": "Italian",
            "pt": "Portuguese",
            "ru": "Russian",
            "ja": "Japanese",
            "ko": "Korean",
            "zh-Hans": "Chinese (Simplified)",
            "zh-Hant": "Chinese (Traditional)",
            "ar": "Arabic",
            "hi": "Hindi",
            "th": "Thai",
            "vi": "Vietnamese",
            "tr": "Turkish",
            "pl": "Polish",
            "nl": "Dutch",
            "sv": "Swedish",
            "da": "Danish",
            "no": "Norwegian",
            "fi": "Finnish",
            "he": "Hebrew",
            "cs": "Czech",
            "sk": "Slovak",
            "hu": "Hungarian",
            "ro": "Romanian",
            "bg": "Bulgarian",
            "hr": "Croatian",
            "uk": "Ukrainian",
            "el": "Greek",
            "ca": "Catalan",
            "id": "Indonesian",
            "ms": "Malay",
            "Base": "Base (Development Language)"
        ]
        
        return languageNames[code] ?? code.uppercased()
    }
    
    private func analyzeFileTypes(in files: [IPAFile]) -> [String: Int] {
        var fileTypes: [String: Int] = [:]
        
        for file in files {
            let fileExtension = URL(fileURLWithPath: file.path).pathExtension.lowercased()
            let fileType: String
            
            switch fileExtension {
            case "strings":
                fileType = "Localizable Strings"
            case "storyboard":
                fileType = "Storyboard"
            case "xib":
                fileType = "XIB Interface"
            case "stringsdict":
                fileType = "Strings Dictionary"
            case "plist":
                fileType = "Property List"
            case "json":
                fileType = "JSON"
            case "xml":
                fileType = "XML"
            default:
                fileType = fileExtension.uppercased() + " File"
            }
            
            fileTypes[fileType, default: 0] += 1
        }
        
        return fileTypes
    }
    
    private func detectUnusedLanguages(_ languages: [LocalizationLanguage]) -> [String] {
        // Detect potentially unused languages based on low adoption markets
        let lowAdoptionLanguages = [
            "bg", "hr", "cs", "sk", "hu", "ro", "sl", "lv", "lt", "et",
            "mt", "ga", "cy", "is", "mk", "sq", "sr", "bs", "me"
        ]
        
        return languages.compactMap { language in
            // Consider unused if it's a low adoption language and very small size
            if lowAdoptionLanguages.contains(language.code) && language.size < 51_200 { // < 50KB
                return language.code
            }
            return nil
        }
    }
    
    private func detectIncompleteLocalizations(_ languages: [LocalizationLanguage]) -> [String] {
        // Find the base/reference language (usually the largest or "en"/"Base")
        guard let referenceLanguage = languages.first(where: { $0.code == "Base" || $0.code == "en" }) ?? languages.first else {
            return []
        }
        
        let referenceFileCount = referenceLanguage.fileCount
        
        // Languages with significantly fewer files are likely incomplete
        return languages.compactMap { language in
            if language.code != referenceLanguage.code && 
               Double(language.fileCount) < Double(referenceFileCount) * 0.7 { // Less than 70% of reference
                return language.code
            }
            return nil
        }
    }
    
    private func detectDuplicateContent(_ languages: [LocalizationLanguage]) -> [String] {
        // This is a simplified approach - in a real implementation you'd compare actual file contents
        // Here we detect languages that have suspiciously similar file structures
        var duplicates: [String] = []
        
        for i in 0..<languages.count {
            for j in (i+1)..<languages.count {
                let lang1 = languages[i]
                let lang2 = languages[j]
                
                // If two languages have identical file counts and very similar sizes
                if lang1.fileCount == lang2.fileCount && 
                   abs(lang1.size - lang2.size) < max(lang1.size, lang2.size) / 10 { // Within 10%
                    if !duplicates.contains(lang2.code) {
                        duplicates.append(lang2.code)
                    }
                }
            }
        }
        
        return duplicates
    }
    
    private func calculateOptimizationPotential(
        unusedLanguages: [String],
        oversizedLanguages: [LocalizationLanguage],
        duplicateContent: [String]
    ) -> Int64 {
        var potential: Int64 = 0
        
        // Unused languages can be completely removed
        potential += unusedLanguages.reduce(0) { total, langCode in
            let lang = oversizedLanguages.first { $0.code == langCode }
            return total + (lang?.size ?? 0)
        }
        
        // Oversized languages can typically be optimized by 30-40%
        potential += oversizedLanguages.reduce(0) { total, lang in
            if !unusedLanguages.contains(lang.code) {
                return total + Int64(Double(lang.size) * 0.35)
            }
            return total
        }
        
        // Duplicate content savings (assume 50% reduction for duplicates)
        potential += duplicateContent.reduce(0) { total, langCode in
            let lang = oversizedLanguages.first { $0.code == langCode }
            return total + Int64(Double(lang?.size ?? 0) * 0.5)
        }
        
        return potential
    }
    
    private func generateRecommendations(
        languageDetails: [LocalizationLanguage],
        unusedLanguages: [String],
        oversizedLanguages: [LocalizationLanguage]
    ) -> [String] {
        var recommendations: [String] = []
        
        if !unusedLanguages.isEmpty {
            recommendations.append("Remove \(unusedLanguages.count) unused language localizations: \(unusedLanguages.joined(separator: ", "))")
        }
        
        if oversizedLanguages.count > 5 {
            recommendations.append("Consider using On-Demand Resources for \(oversizedLanguages.count) large language packs")
        }
        
        if languageDetails.count > 30 {
            recommendations.append("Reduce supported languages from \(languageDetails.count) to core markets (top 10-15 languages)")
        }
        
        let totalSize = languageDetails.reduce(0) { $0 + $1.size }
        if totalSize > 20_971_520 { // > 20MB
            recommendations.append("Compress localization files - current size: \(totalSize.formattedSize)")
        }
        
        let storyboardHeavyLanguages = languageDetails.filter { $0.storyboardFilesCount > 5 }
        if !storyboardHeavyLanguages.isEmpty {
            recommendations.append("Convert Interface Builder files to code for \(storyboardHeavyLanguages.count) languages to reduce size")
        }
        
        return recommendations
    }
}
