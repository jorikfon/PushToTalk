// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PushToTalkSwift",
    platforms: [.macOS(.v14)],
    dependencies: [
        // WhisperKit для распознавания речи на Apple Silicon
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0")
    ],
    targets: [
        // Библиотека с общими компонентами
        .target(
            name: "PushToTalkCore",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit")
            ],
            path: "Sources",
            exclude: [
                "transcribe_test.swift",
                "audio_capture_test.swift",
                "integration_test.swift",
                "keyboard_monitor_test.swift",
                "text_inserter_test.swift",
                "performance_benchmark.swift",
                "App/PushToTalkApp.swift",
                "App/AppDelegate.swift"
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

        // Тестовый исполняемый файл для транскрипции
        .executableTarget(
            name: "TranscribeTest",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit")
            ],
            path: "Sources",
            sources: ["transcribe_test.swift"]
        ),

        // Тестовый исполняемый файл для проверки audio capture
        .executableTarget(
            name: "AudioCaptureTest",
            dependencies: ["PushToTalkCore"],
            path: "Sources",
            sources: ["audio_capture_test.swift"]
        ),

        // Интеграционный тест: AudioCapture + Whisper
        .executableTarget(
            name: "IntegrationTest",
            dependencies: ["PushToTalkCore"],
            path: "Sources",
            sources: ["integration_test.swift"]
        ),

        // Тест мониторинга клавиатуры (F16)
        .executableTarget(
            name: "KeyboardMonitorTest",
            dependencies: ["PushToTalkCore"],
            path: "Sources",
            sources: ["keyboard_monitor_test.swift"]
        ),

        // Тест вставки текста (clipboard + Accessibility API)
        .executableTarget(
            name: "TextInserterTest",
            dependencies: ["PushToTalkCore"],
            path: "Sources",
            sources: ["text_inserter_test.swift"]
        ),

        // Performance Benchmark
        .executableTarget(
            name: "PerformanceBenchmark",
            dependencies: ["PushToTalkCore"],
            path: "Sources",
            sources: ["performance_benchmark.swift"]
        ),

        // Unit тесты
        .testTarget(
            name: "PushToTalkSwiftTests",
            dependencies: [
                "PushToTalkCore",
                .product(name: "WhisperKit", package: "WhisperKit")
            ],
            path: "Tests"
        )
    ]
)
