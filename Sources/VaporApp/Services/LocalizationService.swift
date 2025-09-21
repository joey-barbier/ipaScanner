import Foundation
import Vapor
import Leaf

public final class LocalizationService: @unchecked Sendable {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var _translations: [String: [String: Any]] = [:]
    
    private static var translations: [String: [String: Any]] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _translations
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _translations = newValue
        }
    }
    private static let supportedLanguages = ["fr", "en", "es", "de"]
    private static let defaultLanguage = "en"
    
    public static func configure() throws {
        // Load all translation files
        for language in supportedLanguages {
            guard let path = findResourcePath(for: language) else {
                print("⚠️ Warning: Could not find \(language).json translation file")
                continue
            }
            
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                var updatedTranslations = translations
                updatedTranslations[language] = json
                translations = updatedTranslations
                print("✅ Loaded \(language) translations")
            } catch {
                print("❌ Error loading \(language) translations: \(error)")
            }
        }
    }
    
    private static func findResourcePath(for language: String) -> String? {
        // Try different possible paths for the resource
        let possiblePaths = [
            "Resources/Localization/\(language).json",
            "./Resources/Localization/\(language).json",
            "../Resources/Localization/\(language).json"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }
    
    public static func translate(_ key: String, language: String? = nil, fallback: String? = nil) -> String {
        let lang = language ?? defaultLanguage
        
        // Get the translation for the specified language
        let translation = getTranslation(for: key, in: lang)
        
        // If not found and not default language, try default language
        if translation == nil && lang != defaultLanguage {
            if let defaultTranslation = getTranslation(for: key, in: defaultLanguage) {
                return defaultTranslation
            }
        }
        
        // Return translation, fallback, or key
        return translation ?? fallback ?? key
    }
    
    private static func getTranslation(for key: String, in language: String) -> String? {
        guard let languageDict = translations[language] else { return nil }
        
        let keyParts = key.split(separator: ".").map(String.init)
        var current: Any = languageDict
        
        for part in keyParts {
            guard let dict = current as? [String: Any],
                  let next = dict[part] else {
                return nil
            }
            current = next
        }
        
        return current as? String
    }
    
    public static func getSupportedLanguages() -> [String] {
        return supportedLanguages
    }
    
    public static func isLanguageSupported(_ language: String) -> Bool {
        return supportedLanguages.contains(language)
    }
}

// MARK: - Request Extension
extension Request {
    public var preferredLanguage: String {
        // Check if language is set in session/cookies
        if let sessionLang = session.data["language"],
           LocalizationService.isLanguageSupported(sessionLang) {
            return sessionLang
        }
        
        // Check Accept-Language header
        if let acceptLanguage = headers.first(name: .acceptLanguage) {
            let languages = acceptLanguage.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .compactMap { lang -> String? in
                    let code = String(lang.split(separator: ";").first ?? "")
                        .split(separator: "-").first.map(String.init) ?? ""
                    return LocalizationService.isLanguageSupported(code) ? code : nil
                }
            
            if let preferredLang = languages.first {
                return preferredLang
            }
        }
        
        return "en" // Default fallback
    }
    
    public func t(_ key: String, fallback: String? = nil) -> String {
        return LocalizationService.translate(key, language: preferredLanguage, fallback: fallback)
    }
    
    public func setLanguage(_ language: String) {
        if LocalizationService.isLanguageSupported(language) {
            session.data["language"] = language
        }
    }
}

// MARK: - Leaf Tag for translations
public struct TranslationTag: UnsafeUnescapedLeafTag {
    public func render(_ ctx: LeafContext) throws -> LeafData {
        guard let key = ctx.parameters.first?.string else {
            return LeafData.string("MISSING_KEY")
        }
        
        // Try to get language from context (passed from controller)
        let language = (ctx.data["language"]?.string) ?? "en"
        let fallback = ctx.parameters.count > 1 ? ctx.parameters[1].string : nil
        
        let translation = LocalizationService.translate(key, language: language, fallback: fallback)
        return LeafData.string(translation)
    }
}