import Foundation
import IPAFoundation

public class SizeCalculator {
    
    public init() {}
    
    public func calculateCategorySizes(from files: [IPAFile], totalSize: Int64) -> [FileCategory: CategoryMetrics] {
        var categorySizes: [FileCategory: CategoryMetrics] = [:]
        
        // Group files by category
        let groupedFiles = Dictionary(grouping: files, by: { $0.category })
        
        for (category, categoryFiles) in groupedFiles {
            let categoryTotalSize = categoryFiles.reduce(0) { $0 + $1.size }
            let percentage = totalSize > 0 ? (Double(categoryTotalSize) / Double(totalSize)) * 100 : 0
            let largestFile = categoryFiles.max(by: { $0.size < $1.size })
            
            let metrics = CategoryMetrics(
                category: category,
                totalSize: categoryTotalSize,
                fileCount: categoryFiles.count,
                percentage: percentage,
                largestFile: largestFile.map { file in
                    FileInfo(
                        path: file.path,
                        size: file.size,
                        category: file.category,
                        percentage: totalSize > 0 ? (Double(file.size) / Double(totalSize)) * 100 : 0
                    )
                }
            )
            
            categorySizes[category] = metrics
        }
        
        return categorySizes
    }
    
    public func findTopFiles(from files: [IPAFile], totalSize: Int64, limit: Int = 10) -> [FileInfo] {
        let sortedFiles = files.sorted { $0.size > $1.size }
        let topFiles = sortedFiles.prefix(limit)
        
        return topFiles.map { file in
            FileInfo(
                path: file.path,
                size: file.size,
                category: file.category,
                percentage: totalSize > 0 ? (Double(file.size) / Double(totalSize)) * 100 : 0
            )
        }
    }
    
    public func calculateResourcesSize(from files: [IPAFile]) -> Int64 {
        let resourceCategories: Set<FileCategory> = [
            .image, .video, .audio, .font, .localization,
            .storyboard, .xib, .json, .plist, .xml
        ]
        
        return files
            .filter { resourceCategories.contains($0.category) }
            .reduce(0) { $0 + $1.size }
    }
    
    public func calculateExecutableSize(from files: [IPAFile]) -> Int64 {
        return files
            .filter { $0.category == .executable }
            .reduce(0) { $0 + $1.size }
    }
    
    public func calculateFrameworksSize(from files: [IPAFile]) -> Int64 {
        return files
            .filter { $0.category == .framework || $0.category == .library }
            .reduce(0) { $0 + $1.size }
    }
}