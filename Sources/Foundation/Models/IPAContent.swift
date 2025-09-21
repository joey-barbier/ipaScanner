import Foundation

public struct IPAContent {
    public let bundleIdentifier: String
    public let bundleName: String
    public let bundleVersion: String
    public let bundleShortVersion: String
    public let minimumOSVersion: String?
    public let supportedPlatforms: [String]
    public let executableName: String
    public let extractionPath: URL
    public let payloadPath: URL
    public let infoPlist: [String: Any]
    public let files: [IPAFile]
    public let totalSize: Int64
    
    public init(
        bundleIdentifier: String,
        bundleName: String,
        bundleVersion: String,
        bundleShortVersion: String,
        minimumOSVersion: String?,
        supportedPlatforms: [String],
        executableName: String,
        extractionPath: URL,
        payloadPath: URL,
        infoPlist: [String: Any],
        files: [IPAFile],
        totalSize: Int64
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.bundleName = bundleName
        self.bundleVersion = bundleVersion
        self.bundleShortVersion = bundleShortVersion
        self.minimumOSVersion = minimumOSVersion
        self.supportedPlatforms = supportedPlatforms
        self.executableName = executableName
        self.extractionPath = extractionPath
        self.payloadPath = payloadPath
        self.infoPlist = infoPlist
        self.files = files
        self.totalSize = totalSize
    }
}

public struct IPAFile: Sendable {
    public let path: String
    public let size: Int64
    public let category: FileCategory
    public let isCompressed: Bool
    public let attributes: FileAttributes?
    
    public init(
        path: String,
        size: Int64,
        category: FileCategory,
        isCompressed: Bool = false,
        attributes: FileAttributes? = nil
    ) {
        self.path = path
        self.size = size
        self.category = category
        self.isCompressed = isCompressed
        self.attributes = attributes
    }
}

public struct FileAttributes: Sendable {
    public let isExecutable: Bool
    public let isDirectory: Bool
    public let modificationDate: Date?
    public let permissions: Int?
    
    public init(
        isExecutable: Bool = false,
        isDirectory: Bool = false,
        modificationDate: Date? = nil,
        permissions: Int? = nil
    ) {
        self.isExecutable = isExecutable
        self.isDirectory = isDirectory
        self.modificationDate = modificationDate
        self.permissions = permissions
    }
}