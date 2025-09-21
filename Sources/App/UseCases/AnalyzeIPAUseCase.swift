import Foundation
import IPAFoundation
import Parser
import Analyzer

public class AnalyzeIPAUseCase {
    private let parser: IPAParserProtocol
    private let analyzer: IPAAnalyzerProtocol
    
    public init(
        parser: IPAParserProtocol = IPAParser(),
        analyzer: IPAAnalyzerProtocol = IPAAnalyzer()
    ) {
        self.parser = parser
        self.analyzer = analyzer
    }
    
    public func execute(ipaPath: String) async throws -> AnalysisResult {
        // Validate input
        let ipaURL = URL(fileURLWithPath: ipaPath)
        
        guard FileManager.default.fileExists(atPath: ipaPath) else {
            throw IPAScannerError.fileNotFound(path: ipaPath)
        }
        
        guard ipaPath.lowercased().hasSuffix(".ipa") else {
            throw IPAScannerError.invalidInput(reason: "File must have .ipa extension")
        }
        
        // Parse IPA content
        let content = try parser.parse(ipaURL: ipaURL)
        
        // Analyze content
        let result = try await analyzer.analyze(content)
        
        // Cleanup temporary files
        parser.cleanup()
        
        return result
    }
}