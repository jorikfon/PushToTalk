import Foundation

/// Менеджер для управления приглушением системного аудио во время записи
/// Уменьшает системную громкость для чистой записи голоса
public class AudioDuckingManager: ObservableObject {
    public static let shared = AudioDuckingManager()

    @Published public var isDucked: Bool = false
    @Published public var duckingEnabled: Bool = true // Можно отключить в настройках
    @Published public var muteOutputCompletely: Bool = true // Полностью выключать звук или приглушать
    @Published public var pauseMediaEnabled: Bool = true // Автоматическая пауза медиа-плееров

    private let mediaRemote = MediaRemoteManager.shared

    private init() {
        print("AudioDuckingManager: Инициализация")
        loadSettings()
    }

    /// Загрузка настроек из UserDefaults
    private func loadSettings() {
        duckingEnabled = UserDefaults.standard.object(forKey: "audioDuckingEnabled") as? Bool ?? true
        muteOutputCompletely = UserDefaults.standard.object(forKey: "muteOutputCompletely") as? Bool ?? true
        pauseMediaEnabled = UserDefaults.standard.object(forKey: "pauseMediaEnabled") as? Bool ?? true

        if UserDefaults.standard.object(forKey: "audioDuckingEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "audioDuckingEnabled")
        }
        if UserDefaults.standard.object(forKey: "muteOutputCompletely") == nil {
            UserDefaults.standard.set(true, forKey: "muteOutputCompletely")
        }
        if UserDefaults.standard.object(forKey: "pauseMediaEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "pauseMediaEnabled")
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

    /// Сохранение настройки паузы медиа
    public func savePauseMediaEnabled(_ enabled: Bool) {
        pauseMediaEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "pauseMediaEnabled")
        print("AudioDuckingManager: Пауза медиа \(enabled ? "включена" : "выключена")")
    }

    private var originalVolume: Float = 0.5
    private var wasPlaying: Bool = false

    /// Приглушить системное аудио (начало записи)
    /// - Parameter force: Если true, приглушает независимо от настроек (для Debug кнопок)
    public func duck(force: Bool = false) {
        // Приглушение громкости (только если включено или force)
        if (duckingEnabled && !isDucked) || force {
            print("AudioDuckingManager: \(muteOutputCompletely ? "Выключение" : "Приглушение") системного аудио\(force ? " (принудительно)" : "")...")

            // Сохраняем текущую громкость
            originalVolume = getSystemVolume()

            if muteOutputCompletely || force {
                // Полностью выключаем звук
                setSystemVolume(0.0)
                print("AudioDuckingManager: ✓ Аудио выключено полностью (громкость \(Int(originalVolume * 100))% → 0%)")
            } else {
                // Уменьшаем громкость на 50%
                setSystemVolume(originalVolume * 0.5)
                print("AudioDuckingManager: ✓ Аудио приглушено (громкость \(Int(originalVolume * 100))% → \(Int(originalVolume * 50))%)")
            }

            isDucked = true
        }

        // Пауза медиа-плееров (независимо от ducking!)
        if pauseMediaEnabled || force {
            mediaRemote.pause()
        }
    }

    /// Восстановить системное аудио (конец записи)
    /// - Parameter force: Если true, восстанавливает независимо от флага isDucked (для Debug кнопок)
    public func unduck(force: Bool = false) {
        // Восстановление громкости (только если была приглушена)
        if isDucked || force {
            print("AudioDuckingManager: Восстановление системного аудио\(force ? " (принудительно)" : "")...")

            // Восстанавливаем исходную громкость
            if isDucked {
                setSystemVolume(originalVolume)
                print("AudioDuckingManager: ✓ Громкость восстановлена до \(Int(originalVolume * 100))%")
            }

            isDucked = false
        }

        // Возобновление медиа-плееров (независимо от ducking!)
        if pauseMediaEnabled || force {
            mediaRemote.resume(force: force)
        }
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

}
