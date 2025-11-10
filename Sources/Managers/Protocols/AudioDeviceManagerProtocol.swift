import Foundation
import Combine

/// Протокол менеджера для управления аудио устройствами записи
/// Абстракция для audio device management позволяет легко подменять реализацию и создавать моки для тестирования
public protocol AudioDeviceManagerProtocol: ObservableObject {
    // MARK: - Properties

    /// Список доступных аудио устройств с возможностью записи
    var availableDevices: [AudioDevice] { get }

    /// Текущее выбранное устройство
    var selectedDevice: AudioDevice? { get set }

    // MARK: - Device Management

    /// Сканирование доступных устройств записи
    func scanAvailableDevices()

    /// Выбрать аудио устройство для записи
    /// - Parameter device: Устройство для выбора
    func selectDevice(_ device: AudioDevice)

    /// Получить выбранное устройство или системное устройство по умолчанию
    /// - Returns: Выбранное устройство или nil если не найдено
    func getSelectedDeviceOrDefault() -> AudioDevice?

    /// Получить системное устройство по умолчанию
    /// - Returns: Системное устройство ввода по умолчанию
    func getDefaultInputDevice() -> AudioDevice?
}
