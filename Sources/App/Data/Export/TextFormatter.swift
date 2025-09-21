import Foundation
import IPAFoundation

public class TextFormatter: Exportable {
    
    public init() {}
    
    public func export(_ result: AnalysisResult, format: ExportFormat) throws -> Data {
        guard format == .text else {
            throw IPAScannerError.exportFailed(reason: "TextFormatter only supports text format")
        }
        
        let output = generateTextReport(result)
        
        guard let data = output.data(using: .utf8) else {
            throw IPAScannerError.exportFailed(reason: "Failed to convert text to data")
        }
        
        return data
    }
    
    private func generateTextReport(_ result: AnalysisResult) -> String {
        var output: [String] = []
        
        // Header
        output.append("📱 IPA Analysis Report")
        output.append(String(repeating: "=", count: 50))
        output.append("")
        
        // Basic info
        output.append("📋 App Information:")
        output.append("   Bundle ID: \(result.bundleIdentifier)")
        output.append("   Name: \(result.bundleName)")
        output.append("   Version: \(result.shortVersion) (\(result.version))")
        output.append("   Analyzed: \(formatDate(result.analyzedAt))")
        output.append("")
        
        // Size overview
        output.append("📊 Size Overview:")
        output.append("   Total Size: \(result.totalSize.formattedSize)")
        if let compressedSize = result.compressedSize {
            output.append("   Compressed Size: \(compressedSize.formattedSize)")
        }
        output.append("   Files: \(result.metrics.fileCount)")
        output.append("   Directories: \(result.metrics.directoryCount)")
        output.append("")
        
        // Architecture and platform info
        output.append("🔧 Technical Details:")
        output.append("   Architectures: \(result.architectures.joined(separator: ", "))")
        output.append("   Supported Devices: \(result.metrics.supportedDevices.joined(separator: ", "))")
        if let minOS = result.metrics.minimumOSVersion {
            output.append("   Minimum iOS: \(minOS)")
        }
        output.append("")
        
        // Size breakdown
        output.append("📦 Size Breakdown:")
        output.append("   Executable: \(result.metrics.executableSize.formattedSize)")
        output.append("   Resources: \(result.metrics.resourcesSize.formattedSize)")
        output.append("   Frameworks: \(result.metrics.frameworksSize.formattedSize)")
        output.append("")
        
        // Category breakdown
        output.append("🗂  File Categories:")
        let sortedCategories = result.categorySizes.sorted { $0.value.totalSize > $1.value.totalSize }
        for (_, metrics) in sortedCategories.prefix(10) {
            let percentage = String(format: "%.1f", metrics.percentage)
            output.append("   \(metrics.category.emoji) \(metrics.category.displayName): \(metrics.totalSize.formattedSize) (\(percentage)%) - \(metrics.fileCount) files")
        }
        output.append("")
        
        // Top files
        output.append("🏆 Top 10 Largest Files:")
        for (index, file) in result.topFiles.prefix(10).enumerated() {
            let percentage = String(format: "%.1f", file.percentage)
            output.append("   \(index + 1). \(file.size.formattedSize) (\(percentage)%) - \(file.path)")
        }
        output.append("")
        
        // Frameworks
        if !result.frameworks.isEmpty {
            output.append("📚 Frameworks (\(result.frameworks.count)):")
            let sortedFrameworks = result.frameworks.sorted { $0.size > $1.size }
            for framework in sortedFrameworks.prefix(10) {
                let type = framework.isSystemFramework ? "System" : "Third-party"
                let dynamic = framework.isDynamic ? "Dynamic" : "Static"
                output.append("   • \(framework.name): \(framework.size.formattedSize) (\(type), \(dynamic))")
                if !framework.architectures.isEmpty {
                    output.append("     Architectures: \(framework.architectures.joined(separator: ", "))")
                }
            }
            output.append("")
        }
        
        // Duplicates
        if !result.duplicates.isEmpty {
            let wastedSpace = result.duplicates.reduce(0) { $0 + $1.wastedSpace }
            output.append("🔄 Duplicate Files (\(result.duplicates.count) groups):")
            output.append("   Total wasted space: \(wastedSpace.formattedSize)")
            
            for duplicate in result.duplicates.prefix(5) {
                output.append("   • \(duplicate.files.count) files × \(duplicate.size.formattedSize) = \(duplicate.wastedSpace.formattedSize) wasted")
                for file in duplicate.files.prefix(3) {
                    output.append("     - \(file)")
                }
                if duplicate.files.count > 3 {
                    output.append("     ... and \(duplicate.files.count - 3) more")
                }
            }
            output.append("")
        }
        
        // Optimization suggestions
        if !result.suggestions.isEmpty {
            output.append("💡 Optimization Suggestions:")
            
            for suggestion in result.suggestions {
                let severity = suggestion.severity.rawValue.uppercased()
                let emoji = severityEmoji(suggestion.severity)
                
                output.append("   \(emoji) [\(severity)] \(suggestion.title)")
                output.append("      \(suggestion.description)")
                
                if let savings = suggestion.estimatedSavings {
                    output.append("      Potential savings: \(savings.formattedSize)")
                }
                
                if !suggestion.affectedFiles.isEmpty {
                    let fileCount = suggestion.affectedFiles.count
                    output.append("      Affects \(fileCount) file\(fileCount == 1 ? "" : "s")")
                }
                
                output.append("")
            }
        }
        
        // Footer
        output.append(String(repeating: "=", count: 50))
        output.append("Generated by IPA Scanner")
        
        return output.joined(separator: "\n")
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func severityEmoji(_ severity: SuggestionSeverity) -> String {
        switch severity {
        case .critical: return "🚨"
        case .high: return "⚠️"
        case .medium: return "💛"
        case .low: return "ℹ️"
        case .info: return "📝"
        }
    }
}