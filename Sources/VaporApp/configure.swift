import Vapor
import Leaf
import Analyzer

public func configure(_ app: Application) throws {
    // Configure Leaf templating
    app.views.use(.leaf)
    
    // Set Leaf configuration
    if app.environment != .testing {
        app.leaf.configuration.rootDirectory = app.directory.workingDirectory + "/Views/"
    }
    
    // Configure localization
    try LocalizationService.configure()
    
    // Configure analyzer localization
    try AnalyzerLocalizationService.configure()
    
    // Add translation tag to Leaf
    app.leaf.tags["t"] = TranslationTag()
    
    // Configure sessions for language persistence  
    app.sessions.use(.memory)
    app.sessions.configuration.cookieName = "vapor-session"
    app.sessions.configuration.cookieFactory = { sessionID in
        HTTPCookies.Value(string: sessionID.string, 
                         expires: Date(timeIntervalSinceNow: 60 * 60 * 24 * 7), // 7 days
                         maxAge: nil,
                         domain: nil,
                         path: "/",
                         isSecure: false,
                         isHTTPOnly: false,
                         sameSite: HTTPCookies.SameSitePolicy.lax)
    }
    app.middleware.use(app.sessions.middleware)
    
    // Enable static file serving from Public directory
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    // Configure upload size limit (1GB max)
    app.routes.defaultMaxBodySize = "1gb"
    
    // Enable compression for better performance
    app.http.server.configuration.requestDecompression = .enabled
    app.http.server.configuration.responseCompression = .enabled
    
    // Use HTTP/1.1 for compatibility (HTTP/2 h2c not supported in plaintext)
    app.http.server.configuration.supportVersions = [.one]
    
    // Add debug middleware for uploads
    app.middleware.use(UploadDebugMiddleware())
    
    // Register routes
    try routes(app)
}