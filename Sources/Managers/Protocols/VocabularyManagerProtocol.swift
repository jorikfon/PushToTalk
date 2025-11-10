import Foundation

/// Протокол менеджера для управления словарем и коррекции транскрипций
/// Абстракция для vocabulary management позволяет легко подменять реализацию и создавать моки для тестирования
public protocol VocabularyManagerProtocol {
    // MARK: - Correction Management

    /// Добавить новую коррекцию в словарь
    /// - Parameters:
    ///   - incorrect: Ошибочный вариант
    ///   - correct: Правильный вариант
    func addCorrection(from incorrect: String, to correct: String)

    /// Добавить коррекцию на основе регулярного выражения
    /// - Parameters:
    ///   - pattern: Regex паттерн для поиска
    ///   - replacement: Строка замены
    /// - Throws: Ошибка если regex паттерн невалиден
    func addRegexCorrection(pattern: String, replacement: String) throws

    /// Удалить коррекцию из словаря
    /// - Parameter incorrect: Ошибочный вариант для удаления
    func removeCorrection(for incorrect: String)

    /// Очистить все коррекции
    func clearCorrections()

    /// Сбросить коррекции к стандартным значениям
    func resetToDefaults()

    // MARK: - Transcription Correction

    /// Применить коррекции к транскрибированному тексту
    /// - Parameter text: Исходный текст транскрипции
    /// - Returns: Скорректированный текст
    func correctTranscription(_ text: String) -> String

    // MARK: - Dictionary Management

    /// Получить все коррекции
    /// - Returns: Словарь с коррекциями [ошибочный вариант: правильный вариант]
    func getAllCorrections() -> [String: String]

    /// Экспортировать коррекции в JSON
    /// - Returns: JSON данные с коррекциями
    /// - Throws: Ошибка если не удалось сериализовать
    func exportCorrections() throws -> Data

    /// Импортировать коррекции из JSON
    /// - Parameter data: JSON данные с коррекциями
    /// - Throws: Ошибка если не удалось десериализовать
    func importCorrections(from data: Data) throws
}
