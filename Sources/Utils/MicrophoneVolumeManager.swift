import Foundation
import CoreAudio

/// Менеджер для управления громкостью микрофона
/// Устанавливает максимальную громкость при записи и восстанавливает после
public class MicrophoneVolumeManager: ObservableObject {
    public static let shared = MicrophoneVolumeManager()

    @Published public var volumeBoostEnabled: Bool = true

    private var originalVolume: Float = 0.5
    private var isBoosted: Bool = false

    private let storageKey = "micVolumeBoostEnabled"

    private init() {
        LogManager.audio.info("MicrophoneVolumeManager: Инициализация")
        loadSettings()
    }

    /// Загрузка настроек из UserDefaults
    private func loadSettings() {
        volumeBoostEnabled = UserDefaults.standard.object(forKey: storageKey) as? Bool ?? true
        if UserDefaults.standard.object(forKey: storageKey) == nil {
            UserDefaults.standard.set(true, forKey: storageKey)
        }
    }

    /// Сохранение настроек
    public func saveVolumeBoostEnabled(_ enabled: Bool) {
        volumeBoostEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: storageKey)
        LogManager.audio.info("MicrophoneVolumeManager: Volume boost \(enabled ? "включён" : "выключен")")
    }

    /// Установить максимальную громкость микрофона (начало записи)
    public func boostMicrophoneVolume() {
        guard volumeBoostEnabled, !isBoosted else { return }

        LogManager.audio.begin("Boost микрофона")

        // Сохраняем текущую громкость
        originalVolume = getMicrophoneVolume()

        // Устанавливаем максимальную громкость
        setMicrophoneVolume(1.0)

        isBoosted = true
        LogManager.audio.success(
            "Громкость микрофона повышена",
            details: "\(Int(originalVolume * 100))% → 100%"
        )
    }

    /// Восстановить оригинальную громкость микрофона (конец записи)
    public func restoreMicrophoneVolume() {
        guard isBoosted else { return }

        LogManager.audio.begin("Восстановление громкости микрофона")

        // Восстанавливаем исходную громкость
        setMicrophoneVolume(originalVolume)

        isBoosted = false
        LogManager.audio.success(
            "Громкость микрофона восстановлена",
            details: "100% → \(Int(originalVolume * 100))%"
        )
    }

    /// Получить текущую громкость микрофона (0.0 - 1.0)
    private func getMicrophoneVolume() -> Float {
        guard let deviceID = getDefaultInputDevice() else {
            LogManager.audio.error("Не удалось получить устройство ввода")
            return 0.5
        }

        var volume: Float32 = 0.0
        var volumeSize = UInt32(MemoryLayout<Float32>.size)

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &volumeSize,
            &volume
        )

        if status == noErr {
            LogManager.audio.debug("Текущая громкость микрофона: \(Int(volume * 100))%")
            return volume
        } else {
            LogManager.audio.debug("Не удалось получить громкость микрофона (возможно, не поддерживается)")
            return 0.5
        }
    }

    /// Установить громкость микрофона (0.0 - 1.0)
    private func setMicrophoneVolume(_ volume: Float) {
        guard let deviceID = getDefaultInputDevice() else {
            LogManager.audio.error("Не удалось получить устройство ввода")
            return
        }

        var newVolume = volume
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        // Проверяем, можно ли изменять громкость
        var settable: DarwinBoolean = false
        var status = AudioObjectIsPropertySettable(deviceID, &propertyAddress, &settable)

        guard status == noErr, settable.boolValue else {
            LogManager.audio.debug("Громкость микрофона не может быть изменена программно")
            return
        }

        status = AudioObjectSetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            UInt32(MemoryLayout<Float32>.size),
            &newVolume
        )

        if status == noErr {
            LogManager.audio.debug("Установлена громкость микрофона: \(Int(volume * 100))%")
        } else {
            LogManager.audio.error("Ошибка установки громкости микрофона: \(status)")
        }
    }

    /// Получить ID устройства ввода по умолчанию
    private func getDefaultInputDevice() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var deviceIDSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &deviceIDSize,
            &deviceID
        )

        if status == noErr && deviceID != kAudioObjectUnknown {
            return deviceID
        }

        return nil
    }
}
