//
//  ServiceContainer.swift
//  PushToTalk
//
//  Created by Claude on 2025-11-09.
//

import Foundation
import AVFoundation

/// Dependency Injection Container для всех сервисов и менеджеров приложения
/// Заменяет singleton паттерн и обеспечивает централизованное управление зависимостями
public final class ServiceContainer {

    // MARK: - Singleton Instance (только для ServiceContainer)

    /// Единственный разрешённый singleton в приложении
    /// Все остальные компоненты создаются через этот контейнер
    public static let shared = ServiceContainer()

    private init() {}

    // MARK: - Services

    /// Сервис транскрипции через WhisperKit
    public lazy var whisperService: WhisperServiceProtocol = {
        WhisperService(
            vocabularyManager: self.vocabularyManager,
            userSettings: self.userSettings
        )
    }()

    /// Сервис захвата аудио с микрофона
    public lazy var audioService: AudioCaptureServiceProtocol = {
        let service = AudioCaptureService()
        return service
    }()

    /// Сервис вставки текста в текущую позицию курсора
    public lazy var textInserter: TextInserterProtocol = {
        TextInserter()
    }()

    /// Сервис мониторинга глобальных хоткеев
    public lazy var keyboardMonitor: KeyboardMonitorProtocol = {
        KeyboardMonitor()
    }()

    // MARK: - Managers

    /// Менеджер моделей WhisperKit (загрузка, удаление, список)
    public lazy var modelManager: ModelManagerProtocol = {
        ModelManager()
    }()

    /// Менеджер аудиоустройств (микрофоны, выбор устройства)
    public lazy var audioDeviceManager: AudioDeviceManagerProtocol = {
        AudioDeviceManager()
    }()

    /// Менеджер словарей и коррекций транскрипции
    public lazy var vocabularyManager: VocabularyManagerProtocol = {
        VocabularyManager()
    }()

    /// Менеджер горячих клавиш
    public lazy var hotkeyManager: HotkeyManagerProtocol = {
        HotkeyManager()
    }()

    // MARK: - Utilities (без протоколов)

    /// Менеджер разрешений (микрофон, accessibility)
    /// TODO: Нужно сделать init public в PermissionManager
    public var permissionManager: PermissionManager {
        return PermissionManager.shared
    }

    /// Менеджер звуковых эффектов
    /// TODO: Нужно сделать init public в SoundManager
    public var soundManager: SoundManager {
        return SoundManager.shared
    }

    /// Менеджер управления громкостью микрофона
    /// TODO: Нужно сделать init public в MicrophoneVolumeManager
    public var microphoneVolumeManager: MicrophoneVolumeManager {
        return MicrophoneVolumeManager.shared
    }

    /// Менеджер ducking аудио (приглушение музыки во время записи)
    /// TODO: Нужно сделать init public в AudioDuckingManager
    public var audioDuckingManager: AudioDuckingManager {
        return AudioDuckingManager.shared
    }

    /// Менеджер аудио фидбека
    /// TODO: Нужно сделать init public в AudioFeedbackManager
    public var audioFeedbackManager: AudioFeedbackManager {
        return AudioFeedbackManager.shared
    }

    /// Менеджер проигрывания аудио файлов
    public lazy var audioPlayerManager: AudioPlayerManager = {
        AudioPlayerManager()
    }()

    /// Менеджер управления медиа через системный MediaRemote
    /// TODO: Нужно сделать init public в MediaRemoteManager
    public var mediaRemoteManager: MediaRemoteManager {
        return MediaRemoteManager.shared
    }

    /// Менеджер уведомлений
    public lazy var notificationManager: NotificationManager = {
        NotificationManager()
    }()

    /// Менеджер громкости микрофона
    public var micVolumeManager: MicrophoneVolumeManager {
        return MicrophoneVolumeManager.shared
    }

    /// Менеджер логирования
    /// Note: LogManager не использует shared singleton - это статический класс
    public var logManager: LogManager.Type {
        return LogManager.self
    }

    /// Сервис для отображения алертов и уведомлений
    public lazy var alertService: AlertService = {
        AlertService()
    }()

    // MARK: - Utilities & Helpers

    /// Менеджер настроек пользователя
    public lazy var userSettings: UserSettings = {
        UserSettings.shared // Пока используем существующий singleton
    }()

    /// Менеджер истории транскрипций
    public lazy var transcriptionHistory: TranscriptionHistory = {
        TranscriptionHistory.shared // Пока используем существующий singleton
    }()

    // MARK: - Configuration

    /// Конфигурация приложения
    public let appConfiguration = AppConfiguration()

    // MARK: - Reset (для тестов)

    /// Сброс всех lazy-загруженных сервисов (для юнит-тестов)
    /// ⚠️ Использовать только в тестах!
    internal func resetServices() {
        // Метод для будущего использования в тестах
        // Позволит пересоздать все сервисы с моками
    }
}

// MARK: - AppConfiguration

/// Конфигурация приложения (глобальные настройки)
public struct AppConfiguration {

    // MARK: - Recording

    public let maxRecordingDuration: TimeInterval = AppConstants.defaultMaxRecordingDuration
    public let minRecordingDuration: TimeInterval = AppConstants.minRecordingDuration

    // MARK: - Audio

    public let whisperSampleRate: Double = AppConstants.whisperSampleRate
    public let audioChannels: UInt32 = AppConstants.audioChannels

    // MARK: - Model

    public let defaultModelSize: String = AppConstants.defaultModelSize
    public let availableModelSizes: [String] = AppConstants.availableModelSizes

    // MARK: - Performance

    public let modelLoadTimeout: TimeInterval = AppConstants.modelLoadTimeout
    public let transcriptionTimeout: TimeInterval = AppConstants.transcriptionTimeout

    // MARK: - History

    public let maxHistoryEntries: Int = AppConstants.maxHistoryEntries

    // MARK: - Environment

    public var isDebugMode: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    public var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    public var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - Convenience Extensions

extension ServiceContainer {

    /// Создание нового изолированного контейнера для тестов
    /// - Returns: Новый экземпляр ServiceContainer
    public static func createTestContainer() -> ServiceContainer {
        return ServiceContainer()
    }
}
