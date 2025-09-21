import Foundation
import ArgumentParser
import IPAFoundation

public struct AnalyzeCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "ipascanner",
        abstract: "Analyze an IPA file and generate detailed metrics"
    )
    
    @Argument(help: "Path to the IPA file to analyze")
    public var ipaPath: String
    
    @Option(name: .shortAndLong, help: "Output format (json, text)")
    public var format: String = "text"
    
    @Option(name: .shortAndLong, help: "Output file path (optional)")
    public var output: String?
    
    @Flag(name: .shortAndLong, help: "Enable verbose output")
    public var verbose: Bool = false
    
    public init() {}
    
    public mutating func run() async throws {
        let startTime = Date()
        
        if verbose {
            print("🔍 Starting IPA analysis...")
            print("📁 Input file: \(ipaPath)")
        }
        
        // Validate format
        guard let exportFormat = ExportFormat(rawValue: format.lowercased()) else {
            print("❌ Error: Invalid format '\(format)'. Supported formats: \(ExportFormat.allCases.map { $0.rawValue }.joined(separator: ", "))")
            throw ExitCode.failure
        }
        
        // Execute analysis
        let result = try await runAnalysis(ipaPath: ipaPath, verbose: verbose)
        
        if verbose {
            print("✅ Analysis completed in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
            print("📊 Analyzed \(result.metrics.fileCount) files (\(result.totalSize.formattedSize))")
        }
        
        // Export results
        let exportService = ExportService()
        
        if exportFormat == .text && output == nil {
            // Print to console
            let textOutput = try exportService.exportToConsole(result)
            print(textOutput)
        } else {
            // Save to file
            let outputPath = try exportService.export(result, format: exportFormat, to: output)
            print("✅ Analysis saved to: \(outputPath)")
            
            if verbose {
                print("📄 Format: \(exportFormat.rawValue.uppercased())")
                print("📈 Found \(result.suggestions.count) optimization suggestions")
                if !result.duplicates.isEmpty {
                    let wastedSpace = result.duplicates.reduce(0) { $0 + $1.wastedSpace }
                    print("🔄 Detected \(wastedSpace.formattedSize) of wasted space in duplicates")
                }
            }
        }
    }
    
    private func runAnalysis(ipaPath: String, verbose: Bool) async throws -> AnalysisResult {
        let useCase = AnalyzeIPAUseCase()
        
        if verbose {
            print("📦 Extracting IPA content...")
        }
        
        return try await useCase.execute(ipaPath: ipaPath)
    }
}