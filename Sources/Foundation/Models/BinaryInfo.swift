import Foundation

public struct BinaryInfo {
    public let path: String
    public let architectures: [String]
    public let isDynamic: Bool
    public let hasDebugSymbols: Bool
    public let size: Int64
    public let isOptimized: Bool
    public let hasUnusedArchitectures: Bool
    public let estimatedDebugSymbolsSize: Int64
    public let optimizationLevel: String
    
    public init(
        path: String,
        architectures: [String],
        isDynamic: Bool,
        hasDebugSymbols: Bool,
        size: Int64,
        isOptimized: Bool = false,
        hasUnusedArchitectures: Bool = false,
        estimatedDebugSymbolsSize: Int64 = 0,
        optimizationLevel: String = "unknown"
    ) {
        self.path = path
        self.architectures = architectures
        self.isDynamic = isDynamic
        self.hasDebugSymbols = hasDebugSymbols
        self.size = size
        self.isOptimized = isOptimized
        self.hasUnusedArchitectures = hasUnusedArchitectures
        self.estimatedDebugSymbolsSize = estimatedDebugSymbolsSize
        self.optimizationLevel = optimizationLevel
    }
}