import Foundation
import OSLog

/// Централизованная система логирования на базе Apple Unified Logging (OSLog)
/// Логи доступны через Console.app: log stream --predicate 'subsystem == "com.pushtotalk.app"'
public final class LogManager {
    // Subsystem идентификатор (используем bundle ID приложения)
    private static let subsystem = "com.pushtotalk.app"

    // Категории для разных компонентов приложения
    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let keyboard = Logger(subsystem: subsystem, category: "keyboard")
    public static let audio = Logger(subsystem: subsystem, category: "audio")
    public static let transcription = Logger(subsystem: subsystem, category: "transcription")
    public static let permissions = Logger(subsystem: subsystem, category: "permissions")

    /// Запретить создание экземпляров (статический класс)
    private init() {}
}

// MARK: - Convenience Extensions

public extension Logger {
    /// Логирование начала операции
    /// - Parameters:
    ///   - operation: Название операции
    ///   - details: Дополнительные детали (опционально)
    func begin(_ operation: String, details: String? = nil) {
        if let details = details {
            self.info("▶️ Begin: \(operation, privacy: .public) - \(details, privacy: .public)")
        } else {
            self.info("▶️ Begin: \(operation, privacy: .public)")
        }
    }

    /// Логирование успешного завершения операции
    /// - Parameters:
    ///   - operation: Название операции
    ///   - details: Дополнительные детали (опционально)
    func success(_ operation: String, details: String? = nil) {
        if let details = details {
            self.info("✓ Success: \(operation, privacy: .public) - \(details, privacy: .public)")
        } else {
            self.info("✓ Success: \(operation, privacy: .public)")
        }
    }

    /// Логирование ошибки
    /// - Parameters:
    ///   - operation: Название операции
    ///   - error: Объект ошибки или строка с описанием
    func failure(_ operation: String, error: Error) {
        self.error("✗ Failure: \(operation, privacy: .public) - \(error.localizedDescription, privacy: .public)")
    }

    /// Логирование ошибки с текстовым описанием
    /// - Parameters:
    ///   - operation: Название операции
    ///   - message: Описание ошибки
    func failure(_ operation: String, message: String) {
        self.error("✗ Failure: \(operation, privacy: .public) - \(message, privacy: .public)")
    }
}

// MARK: - Log Level Info

/*
 OSLog уровни логирования (от наименее до наиболее критичных):

 1. debug   - Детальная отладочная информация (НЕ сохраняется на диске, только при активном стриминге)
              Используйте для технических деталей, которые нужны только при разработке
              Пример: logger.debug("Audio buffer size: \(bufferSize)")

 2. info    - Информационные сообщения о нормальной работе приложения
              Используйте для важных событий (запуск/остановка операций)
              Пример: logger.info("Recording started")

 3. notice  - Значимые события (default level)
              Используйте для операций, которые важны, но не критичны
              Пример: logger.notice("Model loaded successfully")

 4. error   - Ошибки, которые не критичны для работы приложения
              Используйте для ошибок с возможностью восстановления
              Пример: logger.error("Failed to play sound: \(error)")

 5. fault   - Критические ошибки, требующие немедленного внимания
              Используйте для сбоев, нарушающих работу приложения
              Пример: logger.fault("Failed to initialize audio system")

 Просмотр логов в Terminal:

 # Все логи приложения (real-time stream)
 log stream --predicate 'subsystem == "com.pushtotalk.app"'

 # Только ошибки и критические события
 log stream --predicate 'subsystem == "com.pushtotalk.app" && eventType >= logEventType.error'

 # Только категория keyboard
 log stream --predicate 'subsystem == "com.pushtotalk.app" && category == "keyboard"'

 # Последние 1 час логов
 log show --predicate 'subsystem == "com.pushtotalk.app"' --last 1h

 # Экспорт логов в файл
 log show --predicate 'subsystem == "com.pushtotalk.app"' --last 1h > pushtotalk_logs.txt

 Privacy Controls:

 По умолчанию все строки редактируются в логах для защиты конфиденциальности.
 Используйте .public для данных, которые безопасно логировать:

 logger.info("User transcription: \(text, privacy: .private)")  // <private>
 logger.info("App version: \(version, privacy: .public)")       // 1.0.0
 logger.info("Key code: \(keyCode)")                            // По умолчанию public для чисел
*/
