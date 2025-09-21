import Foundation
import IPAFoundation

// Version avec timeout du BinaryAnalyzer
public class BinaryAnalyzer {
    
    public init() {}
    
    public func analyzeExecutable(at url: URL) throws -> BinaryInfo {
        print("🔍 Analyzing binary: \(url.path)")
        let startTime = Date()
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw IPAScannerError.fileNotFound(path: url.path)
        }
        
        let fileSize = url.fileSize ?? 0
        print("📦 Binary size: \(fileSize.formattedSize)")
        
        // Skip analysis for very large files to avoid blocking
        if fileSize > 200_000_000 { // > 200MB
            print("🚫 Skipping large binary (\(fileSize / 1_048_576)MB): \(url.path)")
            return BinaryInfo(
                path: url.path,
                architectures: ["arm64"], // Default assumption
                isDynamic: true,
                hasDebugSymbols: false,
                size: fileSize,
                isOptimized: false,
                hasUnusedArchitectures: false,
                estimatedDebugSymbolsSize: 0,
                optimizationLevel: "unknown"
            )
        }
        
        // Try to extract info with timeout protection
        let architectures = extractArchitecturesWithTimeout(from: url)
        let isDynamic = checkIfDynamicWithTimeout(at: url)
        let hasDebugSymbols = checkDebugSymbolsWithTimeout(at: url)
        let isOptimized = checkOptimizationLevelWithTimeout(at: url)
        let optimizationLevel = extractOptimizationLevelWithTimeout(at: url)
        
        let hasUnusedArchitectures = detectUnusedArchitectures(architectures: architectures)
        let estimatedDebugSymbolsSize = hasDebugSymbols ? estimateDebugSymbolsSize(fileSize: fileSize) : 0
        
        let duration = Date().timeIntervalSince(startTime)
        print("✅ Binary analysis completed in \(String(format: "%.2f", duration))s")
        
        return BinaryInfo(
            path: url.path,
            architectures: architectures,
            isDynamic: isDynamic,
            hasDebugSymbols: hasDebugSymbols,
            size: fileSize,
            isOptimized: isOptimized,
            hasUnusedArchitectures: hasUnusedArchitectures,
            estimatedDebugSymbolsSize: estimatedDebugSymbolsSize,
            optimizationLevel: optimizationLevel
        )
    }
    
    private func extractArchitecturesWithTimeout(from url: URL) -> [String] {
        return runCommandWithTimeout(
            command: "/usr/bin/lipo",
            args: ["-info", url.path],
            timeout: 10.0,
            parser: parseArchitectures,
            fallback: ["arm64"]
        )
    }
    
    private func checkIfDynamicWithTimeout(at url: URL) -> Bool {
        let result = runCommandWithTimeout(
            command: "/usr/bin/otool",
            args: ["-L", url.path],
            timeout: 10.0,
            parser: { output in output.contains("@rpath") || output.contains("dylib") },
            fallback: true
        )
        return result
    }
    
    private func checkDebugSymbolsWithTimeout(at url: URL) -> Bool {
        let result = runCommandWithTimeout(
            command: "/usr/bin/dsymutil",
            args: ["--dump-debug-map", url.path],
            timeout: 10.0,
            parser: { output in !output.isEmpty && !output.contains("error") },
            fallback: false
        )
        return result
    }
    
    private func checkOptimizationLevelWithTimeout(at url: URL) -> Bool {
        let result = runCommandWithTimeout(
            command: "/usr/bin/otool",
            args: ["-t", url.path],
            timeout: 10.0,
            parser: { output in output.count > 1000 }, // Optimized code is usually more compact
            fallback: false
        )
        return result
    }
    
    private func extractOptimizationLevelWithTimeout(at url: URL) -> String {
        let result = runCommandWithTimeout(
            command: "/usr/bin/strings",
            args: [url.path],
            timeout: 10.0,
            parser: { output in
                if output.contains("-O3") { return "O3" }
                if output.contains("-O2") { return "O2" }
                if output.contains("-O1") { return "O1" }
                if output.contains("-Os") { return "Os" }
                if output.contains("-Oz") { return "Oz" }
                return "unknown"
            },
            fallback: "unknown"
        )
        return result
    }
    
    private func runCommandWithTimeout<T>(
        command: String,
        args: [String],
        timeout: TimeInterval,
        parser: (String) -> T,
        fallback: T
    ) -> T {
        let process = Process()
        process.launchPath = "/bin/sh"
        process.arguments = ["-c", "timeout \(Int(timeout)) \(command) \(args.joined(separator: " ")) 2>/dev/null"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            
            // Poll instead of waitUntilExit
            let maxWait = timeout + 1.0 // Give extra second
            let pollInterval = 0.1
            var totalWait = 0.0
            
            while process.isRunning && totalWait < maxWait {
                Thread.sleep(forTimeInterval: pollInterval)
                totalWait += pollInterval
            }
            
            // Force terminate if still running
            if process.isRunning {
                process.terminate()
                print("⚠️ Force terminated command: \(command)")
                return fallback
            }
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if output.isEmpty {
                return fallback
            }
            
            return parser(output)
            
        } catch {
            print("❌ Command failed: \(command) - \(error)")
            return fallback
        }
    }
    
    private func parseArchitectures(from output: String) -> [String] {
        // Output format: "Architectures in the fat file: <path> are: arm64 armv7"
        // Or: "Non-fat file: <path> is architecture: arm64"
        
        if output.contains("are:") {
            let parts = output.components(separatedBy: "are:")
            if parts.count > 1 {
                return parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }
            }
        } else if output.contains("is architecture:") {
            let parts = output.components(separatedBy: "is architecture:")
            if parts.count > 1 {
                let arch = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                return [arch]
            }
        }
        
        return ["unknown"]
    }
    
    private func detectUnusedArchitectures(architectures: [String]) -> Bool {
        // If we have more than 2 architectures, some might be unused
        return architectures.count > 2 || architectures.contains("i386") || architectures.contains("x86_64")
    }
    
    private func estimateDebugSymbolsSize(fileSize: Int64) -> Int64 {
        // Debug symbols typically add 30-50% to binary size
        return Int64(Double(fileSize) * 0.4)
    }
}