import Foundation
import IPAFoundation

public class ExportService {
    private let formatters: [ExportFormat: Exportable]
    
    public init() {
        self.formatters = [
            .json: JSONFormatter(),
            .text: TextFormatter()
        ]
    }
    
    public func export(_ result: AnalysisResult, format: ExportFormat, to outputPath: String?) throws -> String {
        guard let formatter = formatters[format] else {
            throw IPAScannerError.exportFailed(reason: "Unsupported format: \(format.rawValue)")
        }
        
        let data = try formatter.export(result, format: format)
        
        // Determine output path
        let finalPath: String
        if let outputPath = outputPath {
            finalPath = outputPath
        } else {
            // Generate default filename
            let appName = result.bundleName.replacingOccurrences(of: " ", with: "_")
            let timestamp = DateFormatter().apply {
                $0.dateFormat = "yyyyMMdd_HHmmss"
            }.string(from: Date())
            finalPath = "\(appName)_analysis_\(timestamp).\(format.fileExtension)"
        }
        
        // Write file
        try data.write(to: URL(fileURLWithPath: finalPath))
        
        return finalPath
    }
    
    public func exportToConsole(_ result: AnalysisResult) throws -> String {
        let formatter = TextFormatter()
        let data = try formatter.export(result, format: .text)
        
        guard let text = String(data: data, encoding: .utf8) else {
            throw IPAScannerError.exportFailed(reason: "Failed to convert data to string")
        }
        
        return text
    }
}

private extension DateFormatter {
    func apply(_ closure: (DateFormatter) -> Void) -> DateFormatter {
        closure(self)
        return self
    }
}