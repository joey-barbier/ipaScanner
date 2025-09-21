import Foundation
import IPAFoundation

public class JSONFormatter: Exportable {
    private let encoder: JSONEncoder
    
    public init() {
        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }
    
    public func export(_ result: AnalysisResult, format: ExportFormat) throws -> Data {
        guard format == .json else {
            throw IPAScannerError.exportFailed(reason: "JSONFormatter only supports JSON format")
        }
        
        do {
            return try encoder.encode(result)
        } catch {
            throw IPAScannerError.exportFailed(reason: "JSON encoding failed: \(error.localizedDescription)")
        }
    }
}