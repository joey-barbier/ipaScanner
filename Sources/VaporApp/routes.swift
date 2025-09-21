import Vapor

func routes(_ app: Application) throws {
    let uploadController = UploadController()
    let languageController = LanguageController()
    
    // Register language routes
    try app.register(collection: languageController)
    
    // Home page - Direct fast upload interface
    app.get { req in
        // Get the current host and port from the request
        let wsHost = req.headers.first(name: .host) ?? "127.0.0.1:8083"
        return req.view.render("fast-upload", [
            "wsHost": wsHost,
            "language": req.preferredLanguage
        ])
    }
    
    // Upload route with progress tracking
    app.post("upload", use: uploadController.upload)
    
    // Fast upload route (raw binary upload)
    app.on(.POST, "upload-fast", body: .collect(maxSize: "500mb")) { req -> Response in
        return try await uploadController.uploadFast(req: req)
    }
    
    // WebSocket endpoint for progress updates
    app.webSocket("ws", "progress", ":sessionId") { req, ws in
        guard let sessionId = req.parameters.get("sessionId") else {
            _ = ws.close(code: .unacceptableData)
            return
        }
        
        Task {
            await ProgressService.shared.register(websocket: ws, for: sessionId)
            
            // Send initial connection confirmation
            let welcomeMessage = ProgressUpdate(
                stage: .uploading,
                progress: 0,
                message: "Connected - ready to receive progress updates",
                details: nil
            )
            await ProgressService.shared.sendProgress(to: sessionId, progress: welcomeMessage)
        }
    }
    
    // Direct results page (no ID, data passed from frontend)
    app.get("results") { req in
        return try await req.view.render("results", [
            "wsHost": req.headers.first(name: "host") ?? "localhost:8080",
            "language": req.preferredLanguage
        ])
    }
    
    
    // Health check
    app.get("health") { (req: Request) -> HealthResponse in
        return HealthResponse(
            status: "ok",
            timestamp: Date().timeIntervalSince1970,
            version: "1.0.0"
        )
    }
}

struct HealthResponse: Content {
    let status: String
    let timestamp: TimeInterval
    let version: String
}