import Foundation

public protocol Extractable {
    func extract(from url: URL) async throws -> IPAContent
}

public protocol Analyzable {
    func analyze(_ content: IPAContent) async throws -> AnalysisResult
}

public protocol Exportable {
    func export(_ result: AnalysisResult, format: ExportFormat) throws -> Data
}

public enum ExportFormat: String, CaseIterable {
    case json = "json"
    case text = "text"
    case csv = "csv"
    case html = "html"
    
    public var fileExtension: String {
        return self.rawValue
    }
    
    public var mimeType: String {
        switch self {
        case .json: return "application/json"
        case .text: return "text/plain"
        case .csv: return "text/csv"
        case .html: return "text/html"
        }
    }
}