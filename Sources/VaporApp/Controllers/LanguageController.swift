import Vapor

public struct LanguageController: RouteCollection {
    
    public func boot(routes: RoutesBuilder) throws {
        let languageRoutes = routes.grouped("language")
        languageRoutes.post("set", use: setLanguage)
        languageRoutes.get("current", use: getCurrentLanguage)
        languageRoutes.get("supported", use: getSupportedLanguages)
    }
    
    public func setLanguage(req: Request) async throws -> Response {
        struct LanguageRequest: Content {
            let language: String
            let redirectTo: String?
        }
        
        let languageRequest = try req.content.decode(LanguageRequest.self)
        
        // Validate language
        guard LocalizationService.isLanguageSupported(languageRequest.language) else {
            throw Abort(.badRequest, reason: "Unsupported language")
        }
        
        // Set language in session
        req.setLanguage(languageRequest.language)
        
        // Always return JSON response since we're using AJAX
        return try await LanguageResponse(success: true, language: languageRequest.language)
            .encodeResponse(for: req)
    }
    
    public func getCurrentLanguage(req: Request) async throws -> LanguageResponse {
        return LanguageResponse(success: true, language: req.preferredLanguage)
    }
    
    public func getSupportedLanguages(req: Request) async throws -> SupportedLanguagesResponse {
        return SupportedLanguagesResponse(
            success: true,
            languages: LocalizationService.getSupportedLanguages(),
            current: req.preferredLanguage
        )
    }
}

public struct LanguageResponse: Content {
    public let success: Bool
    public let language: String
    
    public init(success: Bool, language: String) {
        self.success = success
        self.language = language
    }
}

public struct SupportedLanguagesResponse: Content {
    public let success: Bool
    public let languages: [String]
    public let current: String
    
    public init(success: Bool, languages: [String], current: String) {
        self.success = success
        self.languages = languages
        self.current = current
    }
}