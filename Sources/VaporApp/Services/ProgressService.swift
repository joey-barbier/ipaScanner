import Vapor
import WebSocketKit
import Foundation

public actor ProgressService {
    private var connections: [String: WebSocket] = [:]
    
    public static let shared = ProgressService()
    private init() {}
    
    public func register(websocket: WebSocket, for sessionId: String) {
        connections[sessionId] = websocket
        print("🔗 WebSocket registered for session: \(sessionId)")
        
        websocket.onClose.whenComplete { [weak self] _ in
            Task {
                await self?.disconnect(sessionId: sessionId)
            }
        }
    }
    
    private func disconnect(sessionId: String) {
        connections.removeValue(forKey: sessionId)
        print("❌ WebSocket disconnected for session: \(sessionId)")
    }
    
    public func sendProgress(to sessionId: String, progress: ProgressUpdate) {
        let websocket = connections[sessionId]
        let connectedSessions = Array(connections.keys)
        
        print("📡 Sending progress to session \(sessionId): \(progress.progress)% - \(progress.message)")
        print("📡 Connected sessions: \(connectedSessions)")
        
        guard let ws = websocket else { 
            print("❌ No WebSocket found for session \(sessionId)")
            return 
        }
        
        do {
            let data = try JSONEncoder().encode(progress)
            let jsonString = String(data: data, encoding: .utf8) ?? "{}"
            ws.send(jsonString)
            print("✅ Progress sent successfully")
        } catch {
            print("❌ Failed to encode progress: \(error)")
        }
    }
    
    public func sendError(to sessionId: String, error: String) {
        let errorUpdate = ProgressUpdate(
            stage: .error,
            progress: 0,
            message: error,
            details: nil
        )
        sendProgress(to: sessionId, progress: errorUpdate)
    }
}

public struct ProgressUpdate: Codable {
    public let stage: ProgressStage
    public let progress: Int // 0-100
    public let message: String
    public let details: ProgressDetails?
    public let timestamp: Date
    
    public init(stage: ProgressStage, progress: Int, message: String, details: ProgressDetails?) {
        self.stage = stage
        self.progress = progress
        self.message = message
        self.details = details
        self.timestamp = Date()
    }
}

public enum ProgressStage: String, Codable {
    case uploading = "uploading"
    case validating = "validating"
    case extracting = "extracting"
    case parsing = "parsing"
    case analyzing = "analyzing"
    case generating = "generating"
    case complete = "complete"
    case error = "error"
}

public struct ProgressDetails: Codable {
    public let currentFile: String?
    public let filesProcessed: Int?
    public let totalFiles: Int?
    public let currentSize: Int64?
    public let totalSize: Int64?
    public let estimatedTimeRemaining: TimeInterval?
}