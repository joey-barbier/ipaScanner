// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ipaScanner",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "ipascanner",
            targets: ["App"]
        ),
        .executable(
            name: "ipascanner-web",
            targets: ["VaporApp"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        .package(url: "https://github.com/vapor/leaf.git", from: "4.2.0"),
        .package(url: "https://github.com/vapor/websocket-kit.git", from: "2.6.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0")
    ],
    targets: [
        // Foundation Module
        .target(
            name: "IPAFoundation",
            dependencies: [],
            path: "Sources/Foundation"
        ),
        
        // Parser Module
        .target(
            name: "Parser",
            dependencies: [
                "IPAFoundation"
            ],
            path: "Sources/Parser"
        ),
        
        // Analyzer Module
        .target(
            name: "Analyzer",
            dependencies: [
                "IPAFoundation",
                "Parser",
                .product(name: "Crypto", package: "swift-crypto")
            ],
            path: "Sources/Analyzer"
        ),
        
        // Main App Module (CLI)
        .executableTarget(
            name: "App",
            dependencies: [
                "IPAFoundation",
                "Parser",
                "Analyzer",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/App"
        ),
        
        // Vapor Web Application Module
        .executableTarget(
            name: "VaporApp",
            dependencies: [
                "IPAFoundation",
                "Parser", 
                "Analyzer",
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Leaf", package: "leaf"),
                .product(name: "WebSocketKit", package: "websocket-kit")
            ],
            path: "Sources/VaporApp"
        ),
        
        // Tests
        .testTarget(
            name: "IPAFoundationTests",
            dependencies: ["IPAFoundation"],
            path: "Tests/IPAFoundationTests"
        ),
        .testTarget(
            name: "ParserTests",
            dependencies: ["Parser"],
            path: "Tests/ParserTests"
        ),
        .testTarget(
            name: "AnalyzerTests",
            dependencies: ["Analyzer"],
            path: "Tests/AnalyzerTests"
        ),
        .testTarget(
            name: "AppTests",
            dependencies: ["App"],
            path: "Tests/AppTests"
        )
    ]
)
