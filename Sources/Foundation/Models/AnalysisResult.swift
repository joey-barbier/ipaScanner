import Foundation

public struct InfoPlistAnalysis: Codable, Sendable {
    public let backgroundModes: [String]
    public let capabilities: [String]
    public let permissions: [String]
    public let unusedFeatures: [String]
    public let privacyKeys: [String]
    public let estimatedWaste: Int64
    
    public init(backgroundModes: [String], capabilities: [String], permissions: [String], unusedFeatures: [String], privacyKeys: [String], estimatedWaste: Int64) {
        self.backgroundModes = backgroundModes
        self.capabilities = capabilities
        self.permissions = permissions
        self.unusedFeatures = unusedFeatures
        self.privacyKeys = privacyKeys
        self.estimatedWaste = estimatedWaste
    }
}

public struct AnalysisResult: Codable, Sendable {
    public let bundleIdentifier: String
    public let bundleName: String
    public let version: String
    public let shortVersion: String
    public let analyzedAt: Date
    public let totalSize: Int64
    public let compressedSize: Int64?
    public let metrics: AnalysisMetrics
    public let categorySizes: [FileCategory: CategoryMetrics]
    public let topFiles: [FileInfo]
    public let frameworks: [FrameworkInfo]
    public let architectures: [String]
    public let duplicates: [DuplicateGroup]
    public let suggestions: [OptimizationSuggestion]
    public let assetAnalysisResults: [CarAnalysisResult]
    public let analysisErrors: [AnalysisError]
    
    public init(
        bundleIdentifier: String,
        bundleName: String,
        version: String,
        shortVersion: String,
        analyzedAt: Date = Date(),
        totalSize: Int64,
        compressedSize: Int64? = nil,
        metrics: AnalysisMetrics,
        categorySizes: [FileCategory: CategoryMetrics],
        topFiles: [FileInfo],
        frameworks: [FrameworkInfo],
        architectures: [String],
        duplicates: [DuplicateGroup],
        suggestions: [OptimizationSuggestion],
        assetAnalysisResults: [CarAnalysisResult] = [],
        analysisErrors: [AnalysisError] = []
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.bundleName = bundleName
        self.version = version
        self.shortVersion = shortVersion
        self.analyzedAt = analyzedAt
        self.totalSize = totalSize
        self.compressedSize = compressedSize
        self.metrics = metrics
        self.categorySizes = categorySizes
        self.topFiles = topFiles
        self.frameworks = frameworks
        self.architectures = architectures
        self.duplicates = duplicates
        self.suggestions = suggestions
        self.assetAnalysisResults = assetAnalysisResults
        self.analysisErrors = analysisErrors
    }
}

public struct AnalysisMetrics: Codable, Sendable {
    public let fileCount: Int
    public let directoryCount: Int
    public let executableSize: Int64
    public let resourcesSize: Int64
    public let frameworksSize: Int64
    public let localizationCount: Int
    public let supportedDevices: [String]
    public let minimumOSVersion: String?
    public let infoPlistAnalysis: InfoPlistAnalysis?
    public let localizationAnalysis: LocalizationAnalysis?
    
    public init(
        fileCount: Int,
        directoryCount: Int,
        executableSize: Int64,
        resourcesSize: Int64,
        frameworksSize: Int64,
        localizationCount: Int,
        supportedDevices: [String],
        minimumOSVersion: String?,
        infoPlistAnalysis: InfoPlistAnalysis? = nil,
        localizationAnalysis: LocalizationAnalysis? = nil
    ) {
        self.fileCount = fileCount
        self.directoryCount = directoryCount
        self.executableSize = executableSize
        self.resourcesSize = resourcesSize
        self.frameworksSize = frameworksSize
        self.localizationCount = localizationCount
        self.supportedDevices = supportedDevices
        self.minimumOSVersion = minimumOSVersion
        self.infoPlistAnalysis = infoPlistAnalysis
        self.localizationAnalysis = localizationAnalysis
    }
}

public struct CategoryMetrics: Codable, Sendable {
    public let category: FileCategory
    public let totalSize: Int64
    public let fileCount: Int
    public let percentage: Double
    public let largestFile: FileInfo?
    
    public init(
        category: FileCategory,
        totalSize: Int64,
        fileCount: Int,
        percentage: Double,
        largestFile: FileInfo? = nil
    ) {
        self.category = category
        self.totalSize = totalSize
        self.fileCount = fileCount
        self.percentage = percentage
        self.largestFile = largestFile
    }
}

public struct FileInfo: Codable, Sendable {
    public let path: String
    public let size: Int64
    public let category: FileCategory
    public let percentage: Double
    
    public init(path: String, size: Int64, category: FileCategory, percentage: Double) {
        self.path = path
        self.size = size
        self.category = category
        self.percentage = percentage
    }
}

public struct FrameworkInfo: Codable, Sendable {
    public let name: String
    public let path: String
    public let size: Int64
    public let isSystemFramework: Bool
    public let isDynamic: Bool
    public let architectures: [String]
    
    public init(
        name: String,
        path: String,
        size: Int64,
        isSystemFramework: Bool,
        isDynamic: Bool,
        architectures: [String]
    ) {
        self.name = name
        self.path = path
        self.size = size
        self.isSystemFramework = isSystemFramework
        self.isDynamic = isDynamic
        self.architectures = architectures
    }
}

public struct DuplicateGroup: Codable, Sendable {
    public let hash: String
    public let files: [String]
    public let size: Int64
    public let wastedSpace: Int64
    
    public init(hash: String, files: [String], size: Int64, wastedSpace: Int64) {
        self.hash = hash
        self.files = files
        self.size = size
        self.wastedSpace = wastedSpace
    }
}

public struct OptimizationSuggestion: Codable, Sendable {
    public let type: SuggestionType
    public let severity: SuggestionSeverity
    public let title: String
    public let description: String
    public let estimatedSavings: Int64?
    public let affectedFiles: [String]
    
    public init(
        type: SuggestionType,
        severity: SuggestionSeverity,
        title: String,
        description: String,
        estimatedSavings: Int64? = nil,
        affectedFiles: [String] = []
    ) {
        self.type = type
        self.severity = severity
        self.title = title
        self.description = description
        self.estimatedSavings = estimatedSavings
        self.affectedFiles = affectedFiles
    }
}

public enum SuggestionType: String, Codable, Sendable {
    case duplicateFiles = "duplicate_files"
    case largeImages = "large_images"
    case unusedArchitectures = "unused_architectures"
    case uncompressedAssets = "uncompressed_assets"
    case debugSymbols = "debug_symbols"
    case redundantLocalizations = "redundant_localizations"
    case largeFrameworks = "large_frameworks"
    case assetCatalogDuplicates = "asset_catalog_duplicates"
    case unusedAssets = "unused_assets"
    case assetCatalogOptimization = "asset_catalog_optimization"
    case buildConfigurationOptimization = "build_configuration_optimization"
    case frameworkAlternatives = "framework_alternatives"
    case onDemandResources = "on_demand_resources"
    case appThinning = "app_thinning"
    case swiftCompilerOptimization = "swift_compiler_optimization"
    case linkTimeOptimization = "link_time_optimization"
}


public enum SuggestionSeverity: String, Codable, Sendable {
    case critical = "critical"
    case high = "high"
    case medium = "medium"
    case low = "low"
    case info = "info"
}

// MARK: - Localization Analysis Models

public struct LocalizationAnalysis: Codable, Sendable {
    public let totalLanguages: Int
    public let totalSize: Int64
    public let totalFiles: Int
    public let languages: [LocalizationLanguage]
    public let unusedLanguages: [String]
    public let oversizedLanguages: [String]
    public let incompleteLanguages: [String]
    public let duplicateContent: [String]
    public let optimizationPotential: Int64
    public let recommendations: [String]
    
    public init(
        totalLanguages: Int,
        totalSize: Int64,
        totalFiles: Int,
        languages: [LocalizationLanguage],
        unusedLanguages: [String],
        oversizedLanguages: [String],
        incompleteLanguages: [String],
        duplicateContent: [String],
        optimizationPotential: Int64,
        recommendations: [String]
    ) {
        self.totalLanguages = totalLanguages
        self.totalSize = totalSize
        self.totalFiles = totalFiles
        self.languages = languages
        self.unusedLanguages = unusedLanguages
        self.oversizedLanguages = oversizedLanguages
        self.incompleteLanguages = incompleteLanguages
        self.duplicateContent = duplicateContent
        self.optimizationPotential = optimizationPotential
        self.recommendations = recommendations
    }
}

public struct LocalizationLanguage: Codable, Sendable {
    public let code: String
    public let name: String
    public let fileCount: Int
    public let size: Int64
    public let stringFilesCount: Int
    public let storyboardFilesCount: Int
    public let fileTypes: [String: Int]
    public let files: [String]
    
    public init(
        code: String,
        name: String,
        fileCount: Int,
        size: Int64,
        stringFilesCount: Int,
        storyboardFilesCount: Int,
        fileTypes: [String: Int],
        files: [String]
    ) {
        self.code = code
        self.name = name
        self.fileCount = fileCount
        self.size = size
        self.stringFilesCount = stringFilesCount
        self.storyboardFilesCount = storyboardFilesCount
        self.fileTypes = fileTypes
        self.files = files
    }
}

// MARK: - Analysis Error Reporting

public struct AnalysisError: Codable, Sendable {
    public let type: AnalysisErrorType
    public let filePath: String
    public let fileName: String
    public let reason: String
    public let skipped: Bool // true if file was skipped, false if failed
    
    public init(type: AnalysisErrorType, filePath: String, reason: String, skipped: Bool = false) {
        self.type = type
        self.filePath = filePath
        self.fileName = URL(fileURLWithPath: filePath).lastPathComponent
        self.reason = reason
        self.skipped = skipped
    }
}

public enum AnalysisErrorType: String, Codable, Sendable {
    case assetAnalysis = "asset_analysis"
    case binaryAnalysis = "binary_analysis"
    case fileTooBig = "file_too_big"
    case timeout = "timeout"
    case invalidFormat = "invalid_format"
    case permissionDenied = "permission_denied"
    case other = "other"
}

// MARK: - Asset Analysis Results

public struct AssetInfo: Codable, Sendable {
    public let name: String
    public let type: String
    public let idiom: String
    public let scale: String
    public let size: String
    public let renditionKey: String
    public let sizeOnDisk: Int64
    public let contentHash: String?
    
    public init(name: String, type: String, idiom: String, scale: String, size: String, renditionKey: String, sizeOnDisk: Int64 = 0, contentHash: String? = nil) {
        self.name = name
        self.type = type
        self.idiom = idiom
        self.scale = scale
        self.size = size
        self.renditionKey = renditionKey
        self.sizeOnDisk = sizeOnDisk
        self.contentHash = contentHash
    }
}

public struct AssetDuplicate: Codable, Sendable {
    public let name: String
    public let variants: [AssetInfo]
    public let wastedSpace: Int64
    
    public init(name: String, variants: [AssetInfo], wastedSpace: Int64) {
        self.name = name
        self.variants = variants
        self.wastedSpace = wastedSpace
    }
}

public struct CarAnalysisResult: Codable, Sendable {
    public let path: String
    public let assets: [AssetInfo]
    public let duplicates: [AssetDuplicate]
    public let unusedAssets: [AssetInfo]
    public let totalSize: Int64
    public let optimizationPotential: Int64
    public let analysisStatus: AssetAnalysisStatus
    public let errorMessage: String?
    
    public init(path: String, assets: [AssetInfo], duplicates: [AssetDuplicate], unusedAssets: [AssetInfo], totalSize: Int64, optimizationPotential: Int64, analysisStatus: AssetAnalysisStatus = .success, errorMessage: String? = nil) {
        self.path = path
        self.assets = assets
        self.duplicates = duplicates
        self.unusedAssets = unusedAssets
        self.totalSize = totalSize
        self.optimizationPotential = optimizationPotential
        self.analysisStatus = analysisStatus
        self.errorMessage = errorMessage
    }
}

public enum AssetAnalysisStatus: String, Codable, Sendable {
    case success = "success"
    case skipped = "skipped"  // File was skipped (too big, etc.)
    case failed = "failed"   // Analysis failed with error
    case timeout = "timeout" // Analysis timed out
}