import Foundation
import AVFoundation
import Combine

/// Менеджер для воспроизведения аудио файлов в FileTranscriptionWindow
/// Поддерживает навигацию по временным меткам (реплики диалога)
public class AudioPlayerManager: ObservableObject {
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: TimeInterval = 0
    @Published public var duration: TimeInterval = 0
    @Published public var volume: Float = 1.0

    private var audioPlayer: AVAudioPlayer?
    private var displayLink: Timer?
    private var audioFileURL: URL?

    public init() {
        LogManager.app.info("AudioPlayerManager: Инициализация")
    }

    /// Загружает аудио файл для воспроизведения
    /// Файл должен быть уже нормализован через AudioFileNormalizer
    public func loadAudio(from url: URL) throws {
        // Если файл уже загружен, не загружаем заново
        if audioFileURL == url, audioPlayer != nil {
            LogManager.app.debug("AudioPlayerManager: Файл уже загружен, пропускаем")
            return
        }

        LogManager.app.info("AudioPlayerManager: Загрузка файла \(url.lastPathComponent)")

        // Останавливаем и освобождаем старый плеер
        if let oldPlayer = audioPlayer {
            oldPlayer.stop()
            stopProgressTimer()
        }
        audioPlayer = nil

        // Создаем новый плеер
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.volume = volume
            audioFileURL = url

            // Обновляем длительность
            duration = audioPlayer?.duration ?? 0
            isPlaying = false
            currentTime = 0

            LogManager.app.success("Файл загружен: \(duration)s")
        } catch {
            LogManager.app.failure("Ошибка загрузки файла", error: error)
            throw AudioPlayerError.loadFailed(error)
        }
    }

    /// Начинает воспроизведение с текущей позиции
    public func play() {
        guard let player = audioPlayer else {
            LogManager.app.error("AudioPlayerManager: Плеер не инициализирован")
            return
        }

        // Если уже играет, не создаем новое воспроизведение
        if player.isPlaying {
            LogManager.app.debug("AudioPlayerManager: Уже воспроизводится")
            return
        }

        player.play()
        isPlaying = true
        startProgressTimer()

        LogManager.app.info("Воспроизведение начато с \(currentTime)s")
    }

    /// Приостанавливает воспроизведение
    public func pause() {
        guard let player = audioPlayer else { return }

        player.pause()
        isPlaying = false
        stopProgressTimer()

        LogManager.app.info("Воспроизведение приостановлено на \(currentTime)s")
    }

    /// Останавливает воспроизведение и сбрасывает позицию
    public func stop() {
        guard let player = audioPlayer else { return }

        player.stop()
        player.currentTime = 0
        isPlaying = false
        currentTime = 0
        stopProgressTimer()

        LogManager.app.info("Воспроизведение остановлено")
    }

    /// Переход к указанному времени
    public func seek(to time: TimeInterval) {
        guard let player = audioPlayer else {
            LogManager.app.error("AudioPlayerManager: Плеер не инициализирован")
            return
        }

        let clampedTime = max(0, min(time, duration))
        player.currentTime = clampedTime
        currentTime = clampedTime

        LogManager.app.info("Переход к \(clampedTime)s")
    }

    /// Переход к указанному времени и начало воспроизведения
    public func seekAndPlay(to time: TimeInterval) {
        // Если уже играет, сначала останавливаем
        if isPlaying {
            pause()
        }
        seek(to: time)
        play()
    }

    /// Изменение громкости (0.0 - 1.0)
    public func setVolume(_ newVolume: Float) {
        let clampedVolume = max(0.0, min(1.0, newVolume))
        volume = clampedVolume
        audioPlayer?.volume = clampedVolume
    }

    /// Переключение воспроизведения (play/pause)
    public func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    // MARK: - Private Methods

    /// Запускает таймер для обновления прогресса
    private func startProgressTimer() {
        stopProgressTimer()

        displayLink = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }

            DispatchQueue.main.async {
                self.currentTime = player.currentTime

                // Автоматическая остановка в конце
                if !player.isPlaying && self.isPlaying {
                    self.isPlaying = false
                    self.stopProgressTimer()
                    LogManager.app.info("Воспроизведение завершено")
                }
            }
        }
    }

    /// Останавливает таймер обновления прогресса
    private func stopProgressTimer() {
        displayLink?.invalidate()
        displayLink = nil
    }

    deinit {
        stop()
        LogManager.app.info("AudioPlayerManager: deinit")
    }
}

/// Ошибки AudioPlayerManager
enum AudioPlayerError: LocalizedError {
    case loadFailed(Error)
    case playbackFailed(String)

    var errorDescription: String? {
        switch self {
        case .loadFailed(let error):
            return "Failed to load audio file: \(error.localizedDescription)"
        case .playbackFailed(let message):
            return "Playback failed: \(message)"
        }
    }
}
