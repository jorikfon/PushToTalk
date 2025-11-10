// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PushToTalkSwift",
    platforms: [.macOS(.v14)],
    dependencies: [
        // WhisperKit для распознавания речи на Apple Silicon
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
        // MediaRemote Private API для управления медиа-плеерами
        .package(url: "https://github.com/PrivateFrameworks/MediaRemote.git", from: "0.1.0")
    ],
    targets: [
        // Библиотека с общими компонентами
        .target(
            name: "PushToTalkCore",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit"),
                .product(name: "PrivateMediaRemote", package: "MediaRemote"),
                .product(name: "MediaRemote", package: "MediaRemote")
            ],
            path: "Sources",
            exclude: [
                "App/PushToTalkApp.swift",
                "App/AppDelegate.swift"
            ],
            resources: [
                .process("../Resources/Localization")
            ]
        ),

        // Основное приложение
        .executableTarget(
            name: "PushToTalkSwift",
            dependencies: [
                "PushToTalkCore",
                .product(name: "WhisperKit", package: "WhisperKit")
            ],
            path: "Sources/App",
            sources: ["PushToTalkApp.swift", "AppDelegate.swift"]
        ),

        // Unit Tests
        .testTarget(
            name: "PushToTalkTests",
            dependencies: [
                "PushToTalkCore"
            ],
            path: "Tests/PushToTalkTests"
        )
    ]
)
