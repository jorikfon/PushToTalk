import Foundation
import AVFoundation
import CoreAudio

/// Менеджер для управления аудио устройствами записи
/// Позволяет выбрать конкретный микрофон или аудио вход
public class AudioDeviceManager: ObservableObject {
    public static let shared = AudioDeviceManager()

    @Published public var availableDevices: [AudioDevice] = []
    @Published public var selectedDevice: AudioDevice?

    private let storageKey = "selectedAudioDeviceUID"

    private init() {
        print("AudioDeviceManager: Инициализация")
        scanAvailableDevices()
        // loadSelectedDevice() вызывается в scanAvailableDevices() после заполнения списка
    }

    /// Сканирование доступных устройств записи
    public func scanAvailableDevices() {
        print("AudioDeviceManager: Сканирование устройств...")

        var devices: [AudioDevice] = []

        // Получаем список всех аудио устройств
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == noErr else {
            print("AudioDeviceManager: ✗ Ошибка получения размера данных")
            return
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var audioDevices = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &audioDevices
        )

        guard status == noErr else {
            print("AudioDeviceManager: ✗ Ошибка получения устройств")
            return
        }

        // Фильтруем только устройства с входом (микрофоны)
        for deviceID in audioDevices {
            if hasInputStream(deviceID), let device = getDeviceInfo(deviceID) {
                devices.append(device)
            }
        }

        DispatchQueue.main.async {
            self.availableDevices = devices
            print("AudioDeviceManager: Найдено устройств: \(devices.count)")

            for device in devices {
                print("  - \(device.name) (UID: \(device.uid))")
            }

            // Загружаем сохранённое устройство после того, как список заполнен
            self.loadSelectedDevice()

            // Если нет выбранного устройства, выбираем первое
            if self.selectedDevice == nil && !devices.isEmpty {
                self.selectedDevice = devices.first
                print("AudioDeviceManager: Выбрано устройство по умолчанию: \(devices.first!.name)")
            }
        }
    }

    /// Проверка, имеет ли устройство входной поток
    private func hasInputStream(_ deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: 0
        )

        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == noErr, dataSize > 0 else { return false }

        let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        defer { bufferList.deallocate() }

        let status2 = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            bufferList
        )

        guard status2 == noErr else { return false }

        return bufferList.pointee.mNumberBuffers > 0
    }

    /// Получение информации об устройстве
    private func getDeviceInfo(_ deviceID: AudioDeviceID) -> AudioDevice? {
        // Получаем имя устройства
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceName: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)

        var status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceName
        )

        guard status == noErr else { return nil }

        // Получаем UID устройства
        propertyAddress.mSelector = kAudioDevicePropertyDeviceUID
        var deviceUID: CFString = "" as CFString
        dataSize = UInt32(MemoryLayout<CFString>.size)

        status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceUID
        )

        guard status == noErr else { return nil }

        return AudioDevice(
            id: deviceID,
            name: deviceName as String,
            uid: deviceUID as String
        )
    }

    /// Загрузка сохранённого устройства
    private func loadSelectedDevice() {
        guard let savedUID = UserDefaults.standard.string(forKey: storageKey) else {
            return
        }

        if let device = availableDevices.first(where: { $0.uid == savedUID }) {
            selectedDevice = device
            print("AudioDeviceManager: ✓ Загружено устройство: \(device.name)")
        }
    }

    /// Сохранение выбранного устройства
    public func saveSelectedDevice(_ device: AudioDevice) {
        selectedDevice = device
        UserDefaults.standard.set(device.uid, forKey: storageKey)
        print("AudioDeviceManager: Устройство выбрано: \(device.name)")

        // Уведомляем об изменении
        NotificationCenter.default.post(name: .audioDeviceDidChange, object: device)
    }

    /// Получение выбранного устройства или default
    public func getSelectedDeviceOrDefault() -> AudioDevice? {
        return selectedDevice ?? availableDevices.first
    }
}

/// Структура представляющая аудио устройство
public struct AudioDevice: Identifiable, Codable, Equatable, Hashable {
    public let id: AudioDeviceID
    public let name: String
    public let uid: String

    public var displayName: String {
        return name
    }

    // Реализация Equatable
    public static func == (lhs: AudioDevice, rhs: AudioDevice) -> Bool {
        return lhs.uid == rhs.uid
    }

    // Реализация Hashable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
    }
}

/// Notification для изменения устройства
public extension Notification.Name {
    static let audioDeviceDidChange = Notification.Name("audioDeviceDidChange")
}
