import Vapor
import IPAFoundation
import Parser
import Analyzer

// MARK: - Timeout Utility  
func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }
        
        guard let result = try await group.next() else {
            throw TimeoutError()
        }
        
        group.cancelAll()
        return result
    }
}

struct TimeoutError: Error, LocalizedError {
    var errorDescription: String? {
        return "Operation timed out"
    }
}

struct FileUpload: Content {
    var file: File
    var sessionId: String?
}

struct UploadController {
    private let analysisService = IPAAnalysisService()
    private let cleanupService = FileCleanupService()
    
    // POST /upload - Handle IPA file upload and analysis with progress tracking
    func upload(req: Request) async throws -> Response {
        print("🚀 Upload endpoint called")
        
        var uploadPath: String?
        defer {
            // Always cleanup the uploaded file, even on error
            if let path = uploadPath {
                print("🧹 Cleaning up temporary files...")
                self.cleanupService.cleanup(filePath: path)
            }
        }
        
        do {
            print("📥 Decoding multipart form data...")
            
            // Log request headers for debugging
            print("📋 Content-Type: \(req.headers.first(name: .contentType) ?? "unknown")")
            print("📏 Content-Length: \(req.headers.first(name: .contentLength) ?? "unknown")")
            
            // Decode multipart form data
            let data = try req.content.decode(FileUpload.self)
            print("✅ Multipart data decoded successfully")
            let sessionId = data.sessionId ?? UUID().uuidString
            let progressService = ProgressService.shared
            
            print("📝 Session ID: \(sessionId)")
            print("📂 File size: \(data.file.data.readableBytes) bytes")
            
            // Phase 1: Upload complete - start validation
            await progressService.sendProgress(to: sessionId, progress: ProgressUpdate(
                stage: .validating,
                progress: 10,
                message: "Validating uploaded file...",
                details: nil
            ))
            
            print("🧹 Cleaning up old files...")
            // Clean up old files first
            self.cleanupService.cleanupOldFiles()
            
            // Create temporary file
            uploadPath = self.cleanupService.getUploadPath(originalName: data.file.filename ?? "upload.ipa")
            print("📁 Upload path: \(uploadPath!)")
            
            // Save uploaded file
            print("💾 Writing file data...")
            let fileData = Data(buffer: data.file.data)
            try fileData.write(to: URL(fileURLWithPath: uploadPath!))
            print("✅ File written successfully")
            
            // Phase 2: Validation
            await progressService.sendProgress(to: sessionId, progress: ProgressUpdate(
                stage: .extracting,
                progress: 25,
                message: "Extracting IPA contents...",
                details: nil
            ))
            
            print("✅ Validating IPA...")
            try self.cleanupService.validateIPA(at: uploadPath!, language: req.preferredLanguage)
            print("✅ IPA validation completed")
            
            // Phase 3: Parsing
            await progressService.sendProgress(to: sessionId, progress: ProgressUpdate(
                stage: .parsing,
                progress: 50,
                message: "Parsing IPA structure...",
                details: nil
            ))
            
            print("🔬 Starting analysis using unified service...")
            let result = try await self.analysisService.analyzeIPA(
                at: uploadPath!,
                progressHandler: { message, progress in
                    Task { @Sendable in
                        await progressService.sendProgress(to: sessionId, progress: ProgressUpdate(
                            stage: .analyzing,
                            progress: progress,
                            message: message,
                            details: nil
                        ))
                    }
                },
                language: req.preferredLanguage
            )
            
            // Phase 5: Complete - return data directly (no storage)
            await progressService.sendProgress(to: sessionId, progress: ProgressUpdate(
                stage: .complete,
                progress: 100,
                message: "Analysis complete!",
                details: nil
            ))
            
            // Prepare data for direct response (no storage, no redirect)
            print("🔄 Encoding analysis result to JSON...")
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            // Add timeout protection for JSON encoding
            let resultJSON: String
            do {
                let encodingTask = Task {
                    return try encoder.encode(result)
                }
                
                let encodedData = try await withTimeout(seconds: 10) {
                    try await encodingTask.value
                }
                
                resultJSON = String(data: encodedData, encoding: .utf8) ?? "{}"
                print("✅ JSON encoding completed successfully")
            } catch {
                print("⚠️ JSON encoding failed or timed out: \(error)")
                // Create a simplified result without detailed asset analysis
                let simplifiedResult = AnalysisResult(
                    bundleIdentifier: result.bundleIdentifier,
                    bundleName: result.bundleName,
                    version: result.version,
                    shortVersion: result.shortVersion,
                    totalSize: result.totalSize,
                    compressedSize: result.compressedSize,
                    metrics: result.metrics,
                    categorySizes: result.categorySizes,
                    topFiles: result.topFiles,
                    frameworks: result.frameworks,
                    architectures: result.architectures,
                    duplicates: result.duplicates,
                    suggestions: result.suggestions,
                    assetAnalysisResults: [], // Remove detailed asset analysis to prevent freeze
                    analysisErrors: [AnalysisError(type: .timeout, filePath: "encoding", reason: "Asset analysis details omitted due to encoding timeout", skipped: true)]
                )
                let fallbackData = try encoder.encode(simplifiedResult)
                resultJSON = String(data: fallbackData, encoding: .utf8) ?? "{}"
                print("✅ Using simplified result without detailed asset analysis")
            }
            
            // Return JSON with embedded data
            return Response(
                status: .ok,
                headers: HTTPHeaders([("Content-Type", "application/json")]),
                body: .init(string: "{\"success\": true, \"data\": \(resultJSON)}")
            )
            
        } catch {
            // Handle errors
            req.logger.error("Upload failed: \(error)")
            
            let errorMessage: String
            if let abortError = error as? AbortError {
                errorMessage = abortError.reason
            } else {
                errorMessage = "Analysis failed: \(error.localizedDescription)"
            }
            
            let sessionId = (try? req.content.decode(FileUpload.self).sessionId) ?? "unknown"
            await ProgressService.shared.sendError(to: sessionId, error: errorMessage)
            
            return Response(
                status: .badRequest,
                headers: HTTPHeaders([("Content-Type", "application/json")]),
                body: .init(string: "{\"error\": true, \"message\": \"\(errorMessage)\"}")
            )
        }
    }
    
    // Fast upload without multipart overhead
    func uploadFast(req: Request) async throws -> Response {
        print("⚡ Fast upload endpoint called")
        let startTime = Date()
        
        var uploadPath: String?
        defer {
            // Always cleanup the uploaded file, even on error
            if let path = uploadPath {
                print("🧹 Cleaning up temporary files...")
                cleanupService.cleanup(filePath: path)
            }
        }
        
        // Get session ID from query or header
        let sessionId = req.query[String.self, at: "sessionId"] ?? 
                       req.headers.first(name: "X-Session-Id") ?? 
                       UUID().uuidString
        
        // Assets detailed analysis is always enabled
        
        let progressService = ProgressService.shared
        
        print("📝 Session ID: \(sessionId)")
        
        // Send initial progress
        await progressService.sendProgress(to: sessionId, progress: ProgressUpdate(
            stage: .uploading,
            progress: 5,
            message: "Receiving file...",
            details: nil
        ))
        
        // Get raw body data
        guard let bodyData = req.body.data else {
            throw Abort(.badRequest, reason: "No file data received")
        }
        
        let fileSize = bodyData.readableBytes
        print("📂 Received file size: \(fileSize) bytes (\(fileSize / 1_048_576)MB)")
        
        // Save to temporary file
        uploadPath = cleanupService.getUploadPath(originalName: "upload.ipa")
        let fileData = Data(buffer: bodyData)
        try fileData.write(to: URL(fileURLWithPath: uploadPath!))
        
        let uploadTime = Date().timeIntervalSince(startTime)
        print("⚡ File saved in \(String(format: "%.2f", uploadTime))s")
        
        // Now process the file
        await progressService.sendProgress(to: sessionId, progress: ProgressUpdate(
            stage: .validating,
            progress: 10,
            message: "Validating IPA...",
            details: nil
        ))
        
        // Validate
        try cleanupService.validateIPA(at: uploadPath!, language: req.preferredLanguage)
        
        // Parse
        await progressService.sendProgress(to: sessionId, progress: ProgressUpdate(
            stage: .parsing,
            progress: 50,
            message: "Parsing IPA structure...",
            details: nil
        ))
        
        // Analyze using unified service
        let analysisStart = Date()
        let result = try await analysisService.analyzeIPA(
            at: uploadPath!,
            progressHandler: { message, progress in
                Task { @Sendable in
                    await progressService.sendProgress(to: sessionId, progress: ProgressUpdate(
                        stage: .analyzing,
                        progress: progress,
                        message: message,
                        details: nil
                    ))
                }
            },
            language: req.preferredLanguage
        )
        
        let analysisTime = Date().timeIntervalSince(analysisStart)
        print("✅ Analysis completed in \(String(format: "%.2f", analysisTime))s")
        
        // Complete
        await progressService.sendProgress(to: sessionId, progress: ProgressUpdate(
            stage: .complete,
            progress: 100,
            message: "Analysis complete!",
            details: nil
        ))
        
        let totalTime = Date().timeIntervalSince(startTime)
        print("⚡ Total processing time: \(String(format: "%.2f", totalTime))s")
        
        // Prepare data for template (no storage, direct render)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let resultJSON = try String(data: encoder.encode(result), encoding: .utf8) ?? "{}"
        
        // Return success with embedded data (no redirect, no storage)
        return Response(
            status: .ok,
            headers: HTTPHeaders([("Content-Type", "application/json")]),
            body: .init(string: "{\"success\": true, \"data\": \(resultJSON)}")
        )
    }
    
}
