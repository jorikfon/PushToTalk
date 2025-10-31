import SwiftUI
import AppKit

/// Контроллер menu bar приложения
/// Управляет иконкой в menu bar и выпадающим меню
public class MenuBarController: ObservableObject {
    private var statusItem: NSStatusItem?
    private var settingsWindowController: SettingsWindowController?

    @Published public var isRecording = false
    @Published public var isProcessing = false
    @Published public var modelSize: String = "small"

    // Callbacks (вызываются из AppDelegate)
    public var transcribeFilesCallback: (([URL]) -> Void)?
    public var modelChangedCallback: ((String) -> Void)?

    public init() {
        LogManager.app.info("MenuBarController: Инициализация")
    }

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

    /// Показать выпадающее меню при клике на иконку
    @objc func showMenu() {
        guard let button = statusItem?.button else { return }

        let menu = NSMenu()

        // 1. Распознать аудиофайл
        let transcribeItem = NSMenuItem(
            title: "Распознать аудиофайл",
            action: #selector(openFileTranscription),
            keyEquivalent: ""
        )
        transcribeItem.target = self
        menu.addItem(transcribeItem)

        menu.addItem(NSMenuItem.separator())

        // 2. Настройки
        let settingsItem = NSMenuItem(
            title: "Настройки",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        // 3. Выбор аудиоустройства (submenu)
        let audioDeviceItem = NSMenuItem(
            title: "Аудиоустройство",
            action: nil,
            keyEquivalent: ""
        )
        let audioSubmenu = NSMenu()

        // Получаем список доступных устройств
        let audioDeviceManager = AudioDeviceManager.shared
        let devices = audioDeviceManager.availableDevices
        let selectedDevice = audioDeviceManager.selectedDevice

        if devices.isEmpty {
            // Нет доступных устройств
            let noDevicesItem = NSMenuItem(title: "Нет доступных устройств", action: nil, keyEquivalent: "")
            noDevicesItem.isEnabled = false
            audioSubmenu.addItem(noDevicesItem)
        } else {
            // Добавляем каждое устройство
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

                audioSubmenu.addItem(deviceItem)
            }

            audioSubmenu.addItem(NSMenuItem.separator())

            // Кнопка обновления списка
            let refreshItem = NSMenuItem(
                title: "Обновить список",
                action: #selector(refreshAudioDevices),
                keyEquivalent: ""
            )
            refreshItem.target = self
            audioSubmenu.addItem(refreshItem)
        }

        audioDeviceItem.submenu = audioSubmenu
        menu.addItem(audioDeviceItem)

        menu.addItem(NSMenuItem.separator())

        // 4. Выход
        let quitItem = NSMenuItem(
            title: "Выход",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        // Показываем меню у кнопки
        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil
    }

    /// Открыть окно транскрибации файла
    @objc func openFileTranscription() {
        LogManager.app.info("MenuBarController: Открыть транскрибацию файла")

        // Показываем диалог выбора файла
        let openPanel = NSOpenPanel()
        openPanel.title = "Выберите аудио файлы для транскрибации"
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = [
            .audio,
            .mp3,
            .mpeg4Audio,
            .wav
        ]

        openPanel.begin { [weak self] response in
            if response == .OK {
                let selectedFiles = openPanel.urls
                if !selectedFiles.isEmpty {
                    self?.transcribeFilesCallback?(selectedFiles)
                    LogManager.app.info("Выбрано файлов для транскрибации: \(selectedFiles.count)")
                }
            }
        }
    }

    /// Открыть окно настроек
    @objc func openSettings() {
        settingsWindowController?.showSettings()
        LogManager.app.info("MenuBarController: Открыть настройки")
    }

    /// Выбрать конкретное аудиоустройство
    @objc func selectSpecificDevice(_ sender: NSMenuItem) {
        guard let device = sender.representedObject as? AudioDevice else {
            LogManager.app.error("MenuBarController: Не удалось получить устройство из menu item")
            return
        }

        AudioDeviceManager.shared.saveSelectedDevice(device)
        LogManager.app.info("MenuBarController: Выбрано аудиоустройство: \(device.displayName)")

        // Показываем уведомление
        showInfo("Аудиоустройство изменено", message: "Выбрано: \(device.displayName)")
    }

    /// Обновить список аудиоустройств
    @objc func refreshAudioDevices() {
        AudioDeviceManager.shared.scanAvailableDevices()
        LogManager.app.info("MenuBarController: Список аудиоустройств обновлен")
        showInfo("Список обновлен", message: "Найдено устройств: \(AudioDeviceManager.shared.availableDevices.count)")
    }

    /// Выход из приложения
    @objc func quitApp() {
        LogManager.app.info("MenuBarController: Выход из приложения")
        NSApplication.shared.terminate(nil)
    }

    /// Обновление иконки в зависимости от состояния записи
    public func updateIcon(recording: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.isRecording = recording

            if let button = self.statusItem?.button {
                // Меняем иконку в зависимости от состояния
                let iconName = recording ? "mic.fill" : "mic"

                // Создаём SF Symbol с автоматической адаптацией к теме
                let config = NSImage.SymbolConfiguration(
                    pointSize: 14,
                    weight: .regular
                )

                if let image = NSImage(
                    systemSymbolName: iconName,
                    accessibilityDescription: recording ? "Recording" : "PushToTalk"
                )?.withSymbolConfiguration(config) {

                    // Для темной темы - белая иконка, для светлой - черная
                    // isTemplate = true автоматически адаптирует цвет
                    button.image = image
                    button.image?.isTemplate = true

                    // Цвет иконки: красный при записи, системный в остальных случаях
                    if recording {
                        button.contentTintColor = .systemRed
                    } else {
                        button.contentTintColor = nil  // nil = использовать системный цвет
                    }
                }

                // ВАЖНО: Отключаем возможность открытия панели выбора эмодзи/символов
                button.refusesFirstResponder = true
                button.sendAction(on: [.leftMouseDown])  // Только левый клик

                // Убедимся что alpha всегда 1.0 (без пульсации)
                button.alphaValue = 1.0
            }
        }
    }

    /// Обновление иконки для состояния обработки
    public func updateProcessingState(_ processing: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.isProcessing = processing

            if let button = self.statusItem?.button {
                if processing {
                    // Создаём SF Symbol с автоматической адаптацией к теме
                    let config = NSImage.SymbolConfiguration(
                        pointSize: 14,
                        weight: .regular
                    )

                    // Иконка обработки (синий цвет, без анимации)
                    if let image = NSImage(
                        systemSymbolName: "waveform.circle.fill",
                        accessibilityDescription: "Processing"
                    )?.withSymbolConfiguration(config) {
                        button.image = image
                        button.image?.isTemplate = true
                        button.contentTintColor = .systemBlue
                        button.alphaValue = 1.0
                    }

                    // ВАЖНО: Отключаем возможность открытия панели выбора эмодзи/символов
                    button.refusesFirstResponder = true
                    button.sendAction(on: [.leftMouseDown])  // Только левый клик
                } else {
                    // Возвращаем обычную иконку
                    self.updateIcon(recording: false)
                }
            }
        }
    }


    /// Показ ошибки пользователю
    public func showError(_ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "PushToTalk Error"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    /// Показ информационного сообщения
    public func showInfo(_ title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
