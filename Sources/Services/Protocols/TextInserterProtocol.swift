import Foundation

/// Протокол сервиса вставки текста в позицию курсора
/// Абстракция для text insertion позволяет легко подменять реализацию и создавать моки для тестирования
public protocol TextInserterProtocol {
    // MARK: - Text Insertion

    /// Вставить текст в текущую позицию курсора (clipboard + симуляция Cmd+V).
    /// - Parameters:
    ///   - text: Текст для вставки
    ///   - pressReturnAfter: нажать Enter после вставки (режим «отправить в чат»)
    func insertTextAtCursor(_ text: String, pressReturnAfter: Bool)
}

public extension TextInserterProtocol {
    /// Вставка без нажатия Enter (поведение по умолчанию).
    func insertTextAtCursor(_ text: String) {
        insertTextAtCursor(text, pressReturnAfter: false)
    }
}
