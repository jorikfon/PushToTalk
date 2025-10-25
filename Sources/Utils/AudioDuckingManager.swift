import Foundation

/// Менеджер для управления приглушением системного аудио во время записи
/// Уменьшает системную громкость для чистой записи голоса
public class AudioDuckingManager: ObservableObject {
    public static let shared = AudioDuckingManager()

    @Published public var isDucked: Bool = false
    @Published public var duckingEnabled: Bool = true // Можно отключить в настройках

    private init() {
        print("AudioDuckingManager: Инициализация")
        loadSettings()
    }

    /// Загрузка настроек из UserDefaults
    private func loadSettings() {
        duckingEnabled = UserDefaults.standard.bool(forKey: "audioDuckingEnabled")
        if UserDefaults.standard.object(forKey: "audioDuckingEnabled") == nil {
            // По умолчанию включено
            duckingEnabled = true
            UserDefaults.standard.set(true, forKey: "audioDuckingEnabled")
        }
    }

    /// Сохранение настроек
    public func saveDuckingEnabled(_ enabled: Bool) {
        duckingEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "audioDuckingEnabled")
        print("AudioDuckingManager: Ducking \(enabled ? "enabled" : "disabled")")
    }

    private var originalVolume: Float = 0.5

    /// Приглушить системное аудио (начало записи)
    public func duck() {
        guard duckingEnabled, !isDucked else { return }

        print("AudioDuckingManager: Приглушение системного аудио...")

        // Сохраняем текущую громкость
        originalVolume = getSystemVolume()

        // Уменьшаем громкость на 50%
        setSystemVolume(originalVolume * 0.5)

        isDucked = true
        print("AudioDuckingManager: ✓ Аудио приглушено (громкость снижена с \(Int(originalVolume * 100))% до \(Int(originalVolume * 50))%)")
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
}
