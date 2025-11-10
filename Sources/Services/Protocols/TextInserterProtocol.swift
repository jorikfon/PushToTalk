import Foundation

/// Протокол сервиса вставки текста в позицию курсора
/// Абстракция для text insertion позволяет легко подменять реализацию и создавать моки для тестирования
public protocol TextInserterProtocol {
    // MARK: - Text Insertion

    /// Вставить текст в текущую позицию курсора
    /// Использует clipboard + симуляцию Cmd+V
    /// - Parameter text: Текст для вставки
    func insertTextAtCursor(_ text: String)
}
