import ArgumentParser
import Foundation
import Analyzer
import IPAFoundation

/// Commande CLI pour tester l'analyse d'IPA
/// Utilise exactement le même service que Vapor
@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
public struct TestAnalysisCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "test-analysis",
        abstract: "Test IPA analysis using the same service as web interface"
    )
    
    @Argument(help: "Path to IPA file")
    public var ipaPath: String
    
    @Option(name: .shortAndLong, help: "Output file path for JSON results")
    public var output: String?
    
    @Flag(name: .shortAndLong, help: "Enable verbose output")
    public var verbose = false
    
    @Flag(name: .shortAndLong, help: "Save results to JSON file")
    public var save = false
    
    public init() {}
    
    public func run() async throws {
        print("🧪 IPA Analysis Test")
        print("=" * 50)
        
        let service = IPAAnalysisService()
        
        let progressHandler: ProgressCallback? = verbose ? { message, progress in
            print("  [\(progress)%] \(message)")
        } : nil
        
        // Use async context for the service calls
        let result: AnalysisResult
        
        do {
            if save {
                result = try await service.analyzeAndSave(
                    ipaPath: ipaPath,
                    outputPath: output,
                    progressHandler: progressHandler
                )
            } else {
                result = try await service.analyzeIPA(
                    at: ipaPath,
                    progressHandler: progressHandler
                )
            }
            
            // Afficher un résumé des résultats
            printSummary(result)
            
        } catch {
            print("❌ Analysis failed: \(error)")
            throw ExitCode.failure
        }
    }
    
    private func printSummary(_ result: AnalysisResult) {
        print("")
        print("=" * 50)
        print("📊 ANALYSIS SUMMARY")
        print("=" * 50)
        
        print("App: \(result.bundleName) (\(result.bundleIdentifier))")
        print("Version: \(result.shortVersion) (\(result.version))")
        print("Total Size: \(result.totalSize.formattedSize)")
        print("Files: \(result.metrics.fileCount)")
        print("")
        
        print("🏆 TOP CATEGORIES:")
        let sortedCategories = result.categorySizes.sorted { $0.value.totalSize > $1.value.totalSize }
        for (category, metrics) in sortedCategories.prefix(5) {
            let percentage = Double(metrics.totalSize) / Double(result.totalSize) * 100
            print("  • \(category): \(metrics.totalSize.formattedSize) (\(String(format: "%.1f", percentage))%)")
        }
        print("")
        
        print("📁 LARGEST FILES:")
        for file in result.topFiles.prefix(5) {
            let fileName = URL(fileURLWithPath: file.path).lastPathComponent
            print("  • \(fileName): \(file.size.formattedSize)")
        }
        print("")
        
        print("♻️  DUPLICATES: \(result.duplicates.count) groups")
        if !result.duplicates.isEmpty {
            let totalWaste = result.duplicates.reduce(0) { $0 + $1.wastedSpace }
            print("  Wasted space: \(totalWaste.formattedSize)")
        }
        print("")
        
        print("💡 OPTIMIZATION OPPORTUNITIES:")
        let totalSavings = result.suggestions.compactMap { $0.estimatedSavings }.reduce(0, +)
        print("  \(result.suggestions.count) suggestions")
        print("  Potential savings: \(totalSavings.formattedSize)")
        
        if verbose {
            print("")
            print("🔍 DETAILED SUGGESTIONS:")
            for suggestion in result.suggestions.prefix(10) {
                print("  • \(suggestion.title)")
                print("    Savings: \((suggestion.estimatedSavings ?? 0).formattedSize)")
                print("    \(suggestion.description)")
                print("")
            }
        }
        
        print("=" * 50)
    }
}

extension String {
    static func *(left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}