import Foundation
import IPAFoundation

public class IPAExtractor {
    private let fileManager = FileManager.default
    private var temporaryDirectories: Set<URL> = []
    
    public init() {}
    
    deinit {
        cleanup()
    }
    
    public func extract(from ipaURL: URL) throws -> URL {
        guard fileManager.fileExists(atPath: ipaURL.path) else {
            throw IPAScannerError.fileNotFound(path: ipaURL.path)
        }
        
        let tempDir = createTemporaryDirectory()
        temporaryDirectories.insert(tempDir)
        
        do {
            try extractZipUsingSystem(from: ipaURL, to: tempDir)
            return tempDir
        } catch {
            try? fileManager.removeItem(at: tempDir)
            throw IPAScannerError.extractionFailed(reason: error.localizedDescription)
        }
    }
    
    private func extractZipUsingSystem(from source: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", source.path, "-d", destination.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw IPAScannerError.extractionFailed(reason: "unzip command failed with status \(process.terminationStatus)")
        }
    }
    
    private func createTemporaryDirectory() -> URL {
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("ipascanner_\(UUID().uuidString)")
        
        try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    public func cleanup() {
        for directory in temporaryDirectories {
            try? fileManager.removeItem(at: directory)
        }
        temporaryDirectories.removeAll()
    }
}