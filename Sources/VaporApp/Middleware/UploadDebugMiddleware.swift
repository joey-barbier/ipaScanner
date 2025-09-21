import Vapor
import Foundation

struct UploadDebugMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Log upload requests
        if request.url.path == "/upload" && request.method == .POST {
            let startTime = Date()
            
            print("🔍 [MIDDLEWARE] Upload request received")
            print("  📋 Method: \(request.method)")
            print("  📍 Path: \(request.url.path)")
            print("  📦 Content-Type: \(request.headers.first(name: .contentType) ?? "unknown")")
            
            if let contentLength = request.headers.first(name: .contentLength),
               let bytes = Int64(contentLength) {
                let mb = Double(bytes) / 1_048_576
                print("  📏 Content-Length: \(String(format: "%.1f", mb))MB (\(bytes) bytes)")
            }
            
            // Check if body has been collected
            if let body = request.body.data {
                let bodySize = body.readableBytes
                print("  ✅ Body already collected: \(bodySize) bytes")
            } else {
                print("  ⏳ Body not yet collected (streaming)")
            }
            
            let response = try await next.respond(to: request)
            
            let duration = Date().timeIntervalSince(startTime)
            print("⏱️ [MIDDLEWARE] Upload request completed in \(String(format: "%.2f", duration))s")
            
            return response
        }
        
        return try await next.respond(to: request)
    }
}