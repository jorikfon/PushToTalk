//
//  VocabularyManager.swift
//  PushToTalk
//
//  Менеджер для управления словарем специальных терминов и коррекции транскрипций
//  Используется для исправления часто встречающихся ошибок распознавания
//

import Foundation

public class VocabularyManager: VocabularyManagerProtocol {

    // MARK: - Backwards Compatibility (deprecated)

    /// ⚠️ DEPRECATED: Используйте ServiceContainer.shared.vocabularyManager
    /// Временная совместимость для существующего кода
    @available(*, deprecated, message: "Use ServiceContainer.shared.vocabularyManager instead")
    public static var shared: VocabularyManager {
        return ServiceContainer.shared.vocabularyManager as! VocabularyManager
    }

    // MARK: - Private Properties

    /// Словарь замен: ключ - ошибочное распознавание, значение - правильный вариант
    private var corrections: [String: String] = [:]

    /// Регулярные выражения для замен (для более сложных паттернов)
    private var regexCorrections: [(pattern: NSRegularExpression, replacement: String)] = []

    // MARK: - Initialization

    public init() {
        loadDefaultCorrections()
    }

    // MARK: - Protocol Methods

    /// Добавляет новую коррекцию в словарь
    public func addCorrection(from incorrect: String, to correct: String) {
        let key = incorrect.lowercased()
        corrections[key] = correct
        LogManager.transcription.debug("Добавлена коррекция: '\(incorrect)' → '\(correct)'")
    }

    /// Добавляет коррекцию на основе регулярного выражения
    public func addRegexCorrection(pattern: String, replacement: String) throws {
        let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        regexCorrections.append((pattern: regex, replacement: replacement))
        LogManager.transcription.debug("Добавлена regex коррекция: '\(pattern)' → '\(replacement)'")
    }

    /// Удаляет коррекцию из словаря
    public func removeCorrection(for incorrect: String) {
        let key = incorrect.lowercased()
        corrections.removeValue(forKey: key)
        LogManager.transcription.debug("Удалена коррекция для: '\(incorrect)'")
    }

    /// Очищает все коррекции
    public func clearCorrections() {
        corrections.removeAll()
        regexCorrections.removeAll()
        LogManager.transcription.info("Словарь коррекций очищен")
    }

    /// Сбрасывает коррекции к значениям по умолчанию
    public func resetToDefaults() {
        clearCorrections()
        loadDefaultCorrections()
        LogManager.transcription.info("Коррекции сброшены к значениям по умолчанию")
    }

    /// Применяет коррекции к тексту транскрипции
    public func correctTranscription(_ text: String) -> String {
        var result = text

        // Применяем простые замены (word-by-word)
        let words = result.components(separatedBy: .whitespaces)
        let correctedWords = words.map { word -> String in
            let lowercased = word.lowercased()

            // Проверяем точное совпадение
            if let correction = corrections[lowercased] {
                // Сохраняем капитализацию первой буквы если была
                if word.first?.isUppercase == true && !correction.isEmpty {
                    return correction.prefix(1).uppercased() + correction.dropFirst()
                }
                return correction
            }

            // Проверяем без знаков препинания
            let trimmed = lowercased.trimmingCharacters(in: .punctuationCharacters)
            if let correction = corrections[trimmed] {
                let prefix = String(lowercased.prefix(while: { CharacterSet.punctuationCharacters.contains(Unicode.Scalar(String($0))!) }))
                let suffix = String(lowercased.reversed().prefix(while: { CharacterSet.punctuationCharacters.contains(Unicode.Scalar(String($0))!) }).reversed())

                if word.first?.isUppercase == true && !correction.isEmpty {
                    return prefix + correction.prefix(1).uppercased() + correction.dropFirst() + suffix
                }
                return prefix + correction + suffix
            }

            return word
        }

        result = correctedWords.joined(separator: " ")

        // Применяем regex коррекции
        for (pattern, replacement) in regexCorrections {
            let range = NSRange(result.startIndex..., in: result)
            result = pattern.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: replacement
            )
        }

        return result
    }

    /// Возвращает все текущие коррекции
    public func getAllCorrections() -> [String: String] {
        return corrections
    }

    /// Экспорт коррекций в JSON
    public func exportCorrections() throws -> Data {
        return try JSONEncoder().encode(corrections)
    }

    /// Импорт коррекций из JSON
    public func importCorrections(from data: Data) throws {
        let loaded = try JSONDecoder().decode([String: String].self, from: data)
        corrections.merge(loaded) { _, new in new }
        LogManager.transcription.success("Импортировано \(loaded.count) коррекций")
    }

    // MARK: - Private Methods

    /// Загружает стандартный набор коррекций
    private func loadDefaultCorrections() {
        // Технические термины
        corrections["гит"] = "git"
        corrections["гитхаб"] = "GitHub"
        corrections["свифт"] = "Swift"
        corrections["эксход"] = "Xcode"
        corrections["макос"] = "macOS"
        corrections["айос"] = "iOS"

        // Популярные бренды
        corrections["эпл"] = "Apple"
        corrections["гугл"] = "Google"
        corrections["майкрософт"] = "Microsoft"

        // Общие технические термины
        corrections["апи"] = "API"
        corrections["юарэл"] = "URL"
        corrections["эйчтиэмэл"] = "HTML"
        corrections["цэсэс"] = "CSS"
        corrections["джейэсон"] = "JSON"
        corrections["эсдикей"] = "SDK"

        // Русские термины (частые ошибки)
        corrections["щас"] = "сейчас"
        corrections["чё"] = "что"
        corrections["тя"] = "тебя"

        LogManager.transcription.debug("Загружено \(self.corrections.count) коррекций словаря")
    }

    // MARK: - Helper Properties

    /// Количество загруженных коррекций
    public var count: Int {
        return corrections.count + regexCorrections.count
    }
}
