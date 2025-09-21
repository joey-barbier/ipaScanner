import Foundation

public extension Int64 {
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.includesUnit = true
        formatter.includesCount = true
        return formatter.string(fromByteCount: self)
    }
    
    var megabytes: Double {
        return Double(self) / (1024 * 1024)
    }
    
    var kilobytes: Double {
        return Double(self) / 1024
    }
}