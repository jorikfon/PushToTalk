import Foundation
import Combine

/// Протокол сервиса захвата аудио с микрофона
/// Абстракция для аудио записи позволяет легко подменять реализацию и создавать моки для тестирования
public protocol AudioCaptureServiceProtocol: ObservableObject {
    // MARK: - Properties

    /// Идёт ли запись в данный момент
    var isRecording: Bool { get }

    /// Получено ли разрешение на доступ к микрофону
    var permissionGranted: Bool { get }

    // MARK: - AsyncStream API (Modern)

    /// Поток real-time аудио чанков (async/await)
    /// Используйте для асинхронной обработки аудио фрагментов каждые N секунд
    var audioChunks: AsyncStream<[Float]> { get }

    // MARK: - Deprecated Callback API

    /// Callback для real-time обработки аудио чанков
    /// Вызывается каждые N секунд с накопленным аудио
    /// - Warning: Deprecated. Используйте `audioChunks` AsyncStream вместо callback
    @available(*, deprecated, message: "Use audioChunks AsyncStream instead")
    var onAudioChunkReady: (([Float]) -> Void)? { get set }

    // MARK: - Permissions

    /// Проверка разрешений на доступ к микрофону
    /// - Returns: true если разрешение получено, false иначе
    func checkPermissions() async -> Bool

    // MARK: - Recording

    /// Начать запись аудио
    /// - Throws: AudioError если не удалось начать запись (нет разрешения, невалидный формат и т.д.)
    func startRecording() throws

    /// Остановить запись и вернуть аудио данные
    /// - Returns: Массив Float32 сэмплов (16kHz mono)
    func stopRecording() -> [Float]

    /// Очистить буфер записи (для команды "отмена")
    func clearBuffer()
}
