import Foundation
import IPAFoundation

public protocol IPAAnalyzerProtocol {
    func analyze(_ content: IPAContent) async throws -> AnalysisResult
    func analyze(_ content: IPAContent, progressCallback: ProgressCallback?) async throws -> AnalysisResult
}