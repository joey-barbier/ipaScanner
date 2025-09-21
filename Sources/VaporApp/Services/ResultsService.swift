import Foundation
import Analyzer
import IPAFoundation

public actor ResultsService {
    private var results: [String: AnalysisResult] = [:]
    
    public static let shared = ResultsService()
    private init() {}
    
    public func store(result: AnalysisResult) -> String {
        let id = UUID().uuidString
        
        results[id] = result
        
        // Cleanup old results (keep only last 100)
        if results.count > 100 {
            let sortedKeys = results.keys.sorted()
            let toRemove = sortedKeys.prefix(results.count - 100)
            toRemove.forEach { results.removeValue(forKey: $0) }
        }
        
        return id
    }
    
    public func get(id: String) -> AnalysisResult? {
        return results[id]
    }
    
    public func cleanup(id: String) {
        results.removeValue(forKey: id)
    }
}