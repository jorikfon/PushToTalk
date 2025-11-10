import Foundation
import AppKit

/// Менеджер для воспроизведения системных звуков
public class SoundManager {
    public static let shared = SoundManager()

    private init() {
        print("SoundManager: Инициализация")
    }

    /// Воспроизведение звука по событию
    public func play(_ event: SoundEvent) {
        let soundName = event.systemSoundName

        if let sound = NSSound(named: soundName) {
            sound.play()
            print("SoundManager: ✓ Воспроизведен звук: \(soundName)")
        } else {
            print("SoundManager: ✗ Не найден звук: \(soundName)")
        }
    }

    /// Воспроизведение звука по имени
    public func playSound(named name: String) {
        if let sound = NSSound(named: name) {
            sound.play()
        }
    }
}

/// События со звуковым feedback
public enum SoundEvent {
    case recordingStarted   // Начало записи
    case recordingStopped   // Остановка записи
    case transcriptionSuccess // Успешная транскрипция
    case transcriptionError // Ошибка транскрипции
    case textInserted      // Текст вставлен

    public var systemSoundName: String {
        switch self {
        case .recordingStarted:
            return "Pop"
        case .recordingStopped:
            return "Tink"
        case .transcriptionSuccess, .textInserted:
            return "Glass"
        case .transcriptionError:
            return "Basso"
        }
    }
}
