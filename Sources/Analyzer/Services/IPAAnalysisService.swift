import Foundation
import IPAFoundation
import Parser

/// Service central pour l'analyse d'IPA
/// Peut être utilisé par CLI ou Web avec la même logique
public class IPAAnalysisService {
    
    private let parser: IPAParser
    private let analyzer: IPAAnalyzer
    
    public init() {
        self.parser = IPAParser()
        self.analyzer = IPAAnalyzer()
    }
    
    /// Analyse complète d'un fichier IPA
    /// - Parameters:
    ///   - ipaPath: Chemin vers le fichier IPA
    ///   - progressHandler: Callback optionnel pour le suivi de progression
    /// - Returns: Résultat de l'analyse
    public func analyzeIPA(
        at ipaPath: String,
        progressHandler: ProgressCallback? = nil,
        language: String = "en"
    ) async throws -> AnalysisResult {
        
        let startTime = Date()
        
        print("🚀 Starting IPA Analysis")
        print("📱 File: \(ipaPath)")
        
        // Vérifier que le fichier existe
        guard FileManager.default.fileExists(atPath: ipaPath) else {
            throw IPAScannerError.fileNotFound(path: ipaPath)
        }
        
        // Obtenir la taille du fichier
        let attributes = try FileManager.default.attributesOfItem(atPath: ipaPath)
        let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        print("📦 Size: \(fileSize.formattedSize)")
        
        progressHandler?("Validating IPA file...", 10)
        
        // Parser l'IPA
        print("📂 Parsing IPA structure...")
        progressHandler?("Parsing IPA structure...", 25)
        
        let ipaURL = URL(fileURLWithPath: ipaPath)
        let ipaContent = try parser.parse(ipaURL: ipaURL)
        
        print("✅ Parsed \(ipaContent.files.count) files")
        progressHandler?("Analyzing content...", 50)
        
        // Analyser le contenu
        print("🔍 Running comprehensive analysis...")
        print("🔍 Assets analysis: enabled")
        let result = try await analyzer.analyze(ipaContent, progressCallback: progressHandler, language: language)
        
        let duration = Date().timeIntervalSince(startTime)
        print("")
        print("✅ Analysis completed in \(String(format: "%.2f", duration)) seconds")
        print("📊 Found \(result.suggestions.count) optimization suggestions")
        print("💾 Total potential savings: \(result.suggestions.compactMap { $0.estimatedSavings }.reduce(0, +).formattedSize)")
        
        return result
    }
    
    /// Analyse d'un IPA avec sauvegarde automatique des résultats
    /// - Parameters:
    ///   - ipaPath: Chemin vers le fichier IPA
    ///   - outputPath: Chemin de sortie pour les résultats JSON (optionnel)
    ///   - progressHandler: Callback optionnel pour le suivi de progression
    /// - Returns: Résultat de l'analyse
    public func analyzeAndSave(
        ipaPath: String,
        outputPath: String? = nil,
        progressHandler: ProgressCallback? = nil
    ) async throws -> AnalysisResult {
        
        let result = try await analyzeIPA(at: ipaPath, progressHandler: progressHandler)
        
        // Générer le chemin de sortie si non fourni
        let finalOutputPath = outputPath ?? generateOutputPath(for: ipaPath)
        
        // Sauvegarder les résultats
        try saveResults(result, to: finalOutputPath)
        print("💾 Results saved to: \(finalOutputPath)")
        
        return result
    }
    
    /// Sauvegarde les résultats d'analyse au format JSON
    private func saveResults(_ result: AnalysisResult, to path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let jsonData = try encoder.encode(result)
        try jsonData.write(to: URL(fileURLWithPath: path))
    }
    
    /// Génère un nom de fichier de sortie basé sur l'IPA d'entrée
    private func generateOutputPath(for ipaPath: String) -> String {
        let ipaURL = URL(fileURLWithPath: ipaPath)
        let baseName = ipaURL.deletingPathExtension().lastPathComponent
        let timestamp = DateFormatter.timestamp.string(from: Date())
        return "\(baseName)_analysis_\(timestamp).json"
    }
}

// MARK: - Extensions utiles

extension DateFormatter {
    static let timestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
}

extension Int64 {
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: self)
    }
}