import Foundation

/// Менеджер для управления приглушением системного аудио во время записи
/// Уменьшает системную громкость для чистой записи голоса
public class AudioDuckingManager: ObservableObject {
    public static let shared = AudioDuckingManager()

    @Published public var isDucked: Bool = false
    @Published public var duckingEnabled: Bool = true // Можно отключить в настройках
    @Published public var muteOutputCompletely: Bool = true // Полностью выключать звук или приглушать

    private init() {
        print("AudioDuckingManager: Инициализация")
        loadSettings()
    }

    /// Загрузка настроек из UserDefaults
    private func loadSettings() {
        duckingEnabled = UserDefaults.standard.object(forKey: "audioDuckingEnabled") as? Bool ?? true
        muteOutputCompletely = UserDefaults.standard.object(forKey: "muteOutputCompletely") as? Bool ?? true

        if UserDefaults.standard.object(forKey: "audioDuckingEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "audioDuckingEnabled")
        }
        if UserDefaults.standard.object(forKey: "muteOutputCompletely") == nil {
            UserDefaults.standard.set(true, forKey: "muteOutputCompletely")
        }
    }

    /// Сохранение настроек
    public func saveDuckingEnabled(_ enabled: Bool) {
        duckingEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "audioDuckingEnabled")
        print("AudioDuckingManager: Ducking \(enabled ? "enabled" : "disabled")")
    }

    /// Сохранение режима mute
    public func saveMuteOutputCompletely(_ mute: Bool) {
        muteOutputCompletely = mute
        UserDefaults.standard.set(mute, forKey: "muteOutputCompletely")
        print("AudioDuckingManager: Mute output \(mute ? "полностью" : "приглушение")")
    }

    private var originalVolume: Float = 0.5
    private var wasPlaying: Bool = false

    /// Приглушить системное аудио (начало записи)
    public func duck() {
        guard duckingEnabled, !isDucked else { return }

        print("AudioDuckingManager: \(muteOutputCompletely ? "Выключение" : "Приглушение") системного аудио...")

        // Сохраняем текущую громкость
        originalVolume = getSystemVolume()

        if muteOutputCompletely {
            // Полностью выключаем звук
            setSystemVolume(0.0)
            // ОТКЛЮЧЕНО: pausePlayback() вызывает Ctrl+Cmd+Space который открывает Emoji picker!
            // pausePlayback()
            print("AudioDuckingManager: ✓ Аудио выключено полностью (громкость \(Int(originalVolume * 100))% → 0%)")
        } else {
            // Уменьшаем громкость на 50%
            setSystemVolume(originalVolume * 0.5)
            print("AudioDuckingManager: ✓ Аудио приглушено (громкость \(Int(originalVolume * 100))% → \(Int(originalVolume * 50))%)")
        }

        isDucked = true
    }

    /// Восстановить системное аудио (конец записи)
    public func unduck() {
        guard isDucked else { return }

        print("AudioDuckingManager: Восстановление системного аудио...")

        // Восстанавливаем исходную громкость
        setSystemVolume(originalVolume)

        isDucked = false
        print("AudioDuckingManager: ✓ Аудио восстановлено (громкость восстановлена до \(Int(originalVolume * 100))%)")
    }

    /// Получить текущую системную громкость (0.0 - 1.0)
    private func getSystemVolume() -> Float {
        let script = "output volume of (get volume settings)"

        if let result = runAppleScript(script),
           let volume = Float(result) {
            return volume / 100.0
        }

        return 0.5 // Значение по умолчанию
    }

    /// Установить системную громкость (0.0 - 1.0)
    private func setSystemVolume(_ volume: Float) {
        let volumePercent = Int(volume * 100)
        let script = "set volume output volume \(volumePercent)"
        _ = runAppleScript(script)
    }

    /// Выполнение AppleScript
    private func runAppleScript(_ script: String) -> String? {
        var error: NSDictionary?

        if let scriptObject = NSAppleScript(source: script) {
            let output = scriptObject.executeAndReturnError(&error)

            if let error = error {
                print("AudioDuckingManager: AppleScript error: \(error)")
                return nil
            }

            return output.stringValue
        }

        return nil
    }

    /// Приостановить воспроизведение музыки
    private func pausePlayback() {
        // Используем медиакей для остановки воспроизведения
        let script = """
        tell application "System Events"
            try
                keystroke " " using {control down, command down}
            end try
        end tell
        """
        _ = runAppleScript(script)
        print("AudioDuckingManager: Media playback paused")
    }

    /// Возобновить воспроизведение музыки (если было активно)
    private func resumePlayback() {
        // Пока не реализовано автоматическое возобновление,
        // так как не можем точно знать, было ли что-то активно
        // Пользователь может возобновить вручную
    }
}
