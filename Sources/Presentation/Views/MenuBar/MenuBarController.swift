import SwiftUI
import AppKit

/// Контроллер menu bar приложения
/// Управляет иконкой в menu bar и выпадающим меню
///
/// Responsibilities:
/// - Управление NSStatusItem в menu bar
/// - Создание и отображение меню
/// - Обновление иконки в зависимости от состояния
/// - Координация с AlertService и AudioDeviceManager
public class MenuBarController: ObservableObject {

    // MARK: - Properties

    private var statusItem: NSStatusItem?
    private var settingsWindowController: SettingsWindowController?
    private let audioDeviceManager: any AudioDeviceManagerProtocol
    private let alertService: AlertService

    @Published public var isRecording = false
    @Published public var isProcessing = false
    @Published public var modelSize: String = "small"

    // MARK: - Callbacks

    /// Callback для смены модели (deprecated, используйте onModelChanged в SettingsCoordinator)
    /// Note: onSettingsRequested определён через extension в AppCoordinator.swift
    public var modelChangedCallback: ((String) -> Void)?

    // MARK: - Initialization

    /// Инициализация контроллера menu bar
    /// - Parameters:
    ///   - audioDeviceManager: Менеджер аудиоустройств (через DI)
    ///   - alertService: Сервис для отображения алертов (через DI)
    public init(
        audioDeviceManager: any AudioDeviceManagerProtocol,
        alertService: AlertService
    ) {
        self.audioDeviceManager = audioDeviceManager
        self.alertService = alertService

        LogManager.app.info("MenuBarController: Инициализация")
    }

    // MARK: - Setup

    /// Настройка menu bar элемента
    public func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateIcon(recording: false)
            button.action = #selector(showMenu)
            button.target = self
            button.sendAction(on: [.leftMouseDown])
        }

        // Создаем контроллер окна настроек
        settingsWindowController = SettingsWindowController(menuBarController: self)

        LogManager.app.success("MenuBarController: Menu bar настроен")
    }

    // MARK: - Menu Management

    /// Показать выпадающее меню при клике на иконку
    @objc private func showMenu() {
        guard let button = statusItem?.button else { return }

        let menu = NSMenu()

        // 1. Настройки
        addSettingsMenuItem(to: menu)

        // 2. Выбор аудиоустройства (submenu)
        addAudioDeviceSubmenu(to: menu)

        menu.addItem(NSMenuItem.separator())

        // 3. Выход
        addQuitMenuItem(to: menu)

        // Показываем меню у кнопки
        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil
    }

    // MARK: - Menu Items

    /// Добавить пункт "Настройки"
    private func addSettingsMenuItem(to menu: NSMenu) {
        let settingsItem = NSMenuItem(
            title: Strings.MenuBar.settings,
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
    }

    /// Добавить подменю выбора аудиоустройства
    private func addAudioDeviceSubmenu(to menu: NSMenu) {
        let audioDeviceItem = NSMenuItem(
            title: Strings.MenuBar.audioDevice,
            action: nil,
            keyEquivalent: ""
        )

        let audioSubmenu = NSMenu()
        let devices = audioDeviceManager.availableDevices
        let selectedDevice = audioDeviceManager.selectedDevice

        if devices.isEmpty {
            addNoDevicesMenuItem(to: audioSubmenu)
        } else {
            addDeviceMenuItems(to: audioSubmenu, devices: devices, selectedDevice: selectedDevice)
            audioSubmenu.addItem(NSMenuItem.separator())
            addRefreshMenuItem(to: audioSubmenu)
        }

        audioDeviceItem.submenu = audioSubmenu
        menu.addItem(audioDeviceItem)
    }

    /// Добавить пункт "Нет доступных устройств"
    private func addNoDevicesMenuItem(to menu: NSMenu) {
        let noDevicesItem = NSMenuItem(
            title: Strings.MenuBar.noDevicesAvailable,
            action: nil,
            keyEquivalent: ""
        )
        noDevicesItem.isEnabled = false
        menu.addItem(noDevicesItem)
    }

    /// Добавить пункты для каждого устройства
    private func addDeviceMenuItems(
        to menu: NSMenu,
        devices: [AudioDevice],
        selectedDevice: AudioDevice?
    ) {
        for device in devices {
            let deviceItem = NSMenuItem(
                title: device.displayName,
                action: #selector(selectSpecificDevice(_:)),
                keyEquivalent: ""
            )
            deviceItem.target = self
            deviceItem.representedObject = device

            // Показываем галочку у выбранного устройства
            if let selected = selectedDevice, selected.id == device.id {
                deviceItem.state = .on
            }

            menu.addItem(deviceItem)
        }
    }

    /// Добавить пункт "Обновить список"
    private func addRefreshMenuItem(to menu: NSMenu) {
        let refreshItem = NSMenuItem(
            title: Strings.MenuBar.refreshList,
            action: #selector(refreshAudioDevices),
            keyEquivalent: ""
        )
        refreshItem.target = self
        menu.addItem(refreshItem)
    }

    /// Добавить пункт "Выход"
    private func addQuitMenuItem(to menu: NSMenu) {
        let quitItem = NSMenuItem(
            title: Strings.MenuBar.quit,
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: - Actions

    /// Открыть окно настроек
    @objc private func openSettings() {
        // Используем callback если задан (новый подход через AppCoordinator)
        if let callback = onSettingsRequested {
            callback()
        } else {
            // Fallback на старый подход
            settingsWindowController?.showSettings()
        }

        LogManager.app.info("MenuBarController: Открыть настройки")
    }

    /// Выбрать конкретное аудиоустройство
    @objc private func selectSpecificDevice(_ sender: NSMenuItem) {
        guard let device = sender.representedObject as? AudioDevice else {
            LogManager.app.error("MenuBarController: Не удалось получить устройство из menu item")
            return
        }

        audioDeviceManager.selectDevice(device)
        LogManager.app.info("MenuBarController: Выбрано аудиоустройство: \(device.displayName)")

        // Уведомление не показываем - смена устройства происходит часто и это раздражает
        // Информация доступна в логах
    }

    /// Обновить список аудиоустройств
    @objc private func refreshAudioDevices() {
        audioDeviceManager.scanAvailableDevices()
        LogManager.app.info("MenuBarController: Список аудиоустройств обновлен")

        // Popup не показываем - информация доступна в меню
        let devicesCount = audioDeviceManager.availableDevices.count
        LogManager.app.info("MenuBarController: Найдено устройств: \(devicesCount)")
    }

    /// Выход из приложения
    @objc private func quitApp() {
        LogManager.app.info("MenuBarController: Выход из приложения")
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Icon Updates

    /// Обновление иконки в зависимости от состояния записи
    /// - Parameter recording: true если идет запись, false если нет
    public func updateIcon(recording: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.isRecording = recording

            guard let button = self.statusItem?.button else { return }

            // Меняем иконку в зависимости от состояния
            let iconName = recording ? "mic.fill" : "mic"

            // Создаём SF Symbol с конфигурацией
            let config = NSImage.SymbolConfiguration(
                pointSize: UIConstants.MenuBar.iconSize,
                weight: UIConstants.MenuBar.iconWeight
            )

            guard let image = NSImage(
                systemSymbolName: iconName,
                accessibilityDescription: recording ? Strings.MenuBar.recording : Strings.App.name
            )?.withSymbolConfiguration(config) else {
                return
            }

            // Для темной темы - белая иконка, для светлой - черная
            // isTemplate = true автоматически адаптирует цвет
            button.image = image
            button.image?.isTemplate = true

            // Цвет иконки: красный при записи, системный в остальных случаях
            button.contentTintColor = recording ? .systemRed : nil

            // ВАЖНО: Отключаем возможность открытия панели выбора эмодзи/символов
            button.refusesFirstResponder = true
            button.sendAction(on: [.leftMouseDown])  // Только левый клик

            // Убедимся что alpha всегда 1.0 (без пульсации)
            button.alphaValue = 1.0
        }
    }

    /// Обновление иконки для состояния обработки
    /// - Parameter processing: true если идет обработка, false если нет
    public func updateProcessingState(_ processing: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.isProcessing = processing

            guard let button = self.statusItem?.button else { return }

            if processing {
                // Создаём SF Symbol с конфигурацией
                let config = NSImage.SymbolConfiguration(
                    pointSize: UIConstants.MenuBar.iconSize,
                    weight: UIConstants.MenuBar.iconWeight
                )

                // Иконка обработки (синий цвет, без анимации)
                guard let image = NSImage(
                    systemSymbolName: "waveform.circle.fill",
                    accessibilityDescription: Strings.MenuBar.processing
                )?.withSymbolConfiguration(config) else {
                    return
                }

                button.image = image
                button.image?.isTemplate = true
                button.contentTintColor = .systemBlue
                button.alphaValue = 1.0

                // ВАЖНО: Отключаем возможность открытия панели выбора эмодзи/символов
                button.refusesFirstResponder = true
                button.sendAction(on: [.leftMouseDown])  // Только левый клик
            } else {
                // Возвращаем обычную иконку
                self.updateIcon(recording: false)
            }
        }
    }

    // MARK: - Alert Helpers (Deprecated)

    /// Показ ошибки пользователю
    /// @deprecated Используйте напрямую AlertService
    @available(*, deprecated, message: "Используйте alertService.showError() напрямую")
    public func showError(_ message: String) {
        alertService.showError(message)
    }

    /// Показ информационного сообщения
    /// @deprecated Используйте напрямую AlertService
    @available(*, deprecated, message: "Используйте alertService.showInfo() напрямую")
    public func showInfo(_ title: String, message: String) {
        alertService.showInfo(title, message: message)
    }
}
