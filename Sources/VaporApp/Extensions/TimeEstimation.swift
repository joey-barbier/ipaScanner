import Foundation

extension Int64 {
    /// Estimate processing time based on file size
    /// Small files: ~50MB/sec, Large files: ~20MB/sec (due to I/O bottleneck)
    var estimatedProcessingTime: TimeInterval {
        let sizeInMB = Double(self) / 1_048_576.0
        
        switch sizeInMB {
        case 0..<10:
            return sizeInMB / 50.0 // Small files: 50MB/sec
        case 10..<100:
            return sizeInMB / 30.0 // Medium files: 30MB/sec
        default:
            return sizeInMB / 20.0 // Large files: 20MB/sec
        }
    }
    
    /// Format time estimate as human-readable string
    func formatTimeEstimate(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            let remainingSeconds = Int(seconds) % 60
            return "\(minutes)m \(remainingSeconds)s"
        } else {
            let hours = Int(seconds / 3600)
            let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }
}