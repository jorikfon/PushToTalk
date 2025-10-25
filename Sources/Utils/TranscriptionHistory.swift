import Foundation
import AppKit

/// Менеджер для хранения истории транскрипций
/// Хранит последние N транскрипций с возможностью копирования
public class TranscriptionHistory: ObservableObject {
    public static let shared = TranscriptionHistory()

    @Published public var history: [TranscriptionEntry] = []

    private let maxHistorySize = 50
    private let storageKey = "transcriptionHistory"

    private init() {
        print("TranscriptionHistory: Инициализация")
        loadHistory()
    }

    /// Добавление новой транскрипции в историю
    public func addTranscription(_ text: String, duration: TimeInterval) {
        let entry = TranscriptionEntry(
            text: text,
            timestamp: Date(),
            duration: duration
        )

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Добавляем в начало списка (последние сверху)
            self.history.insert(entry, at: 0)

            // Ограничиваем размер истории
            if self.history.count > self.maxHistorySize {
                self.history = Array(self.history.prefix(self.maxHistorySize))
            }

            // Сохраняем в UserDefaults
            self.saveHistory()

            print("TranscriptionHistory: Добавлена запись: \"\(text.prefix(30))...\"")
        }
    }

    /// Копирование транскрипции в clipboard
    public func copyToClipboard(_ entry: TranscriptionEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(entry.text, forType: .string)

        print("TranscriptionHistory: Скопирован текст: \"\(entry.text.prefix(30))...\"")
    }

    /// Удаление записи из истории
    public func deleteEntry(_ entry: TranscriptionEntry) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.history.removeAll { $0.id == entry.id }
            self.saveHistory()

            print("TranscriptionHistory: Удалена запись")
        }
    }

    /// Очистка всей истории
    public func clearHistory() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.history.removeAll()
            self.saveHistory()

            print("TranscriptionHistory: История очищена")
        }
    }

    /// Сохранение истории в UserDefaults
    private func saveHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(history)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("TranscriptionHistory: ✗ Ошибка сохранения истории: \(error)")
        }
    }

    /// Загрузка истории из UserDefaults
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            print("TranscriptionHistory: Нет сохранённой истории")
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            history = try decoder.decode([TranscriptionEntry].self, from: data)
            print("TranscriptionHistory: ✓ Загружено записей: \(history.count)")
        } catch {
            print("TranscriptionHistory: ✗ Ошибка загрузки истории: \(error)")
            history = []
        }
    }

    /// Экспорт истории в текстовый файл
    public func exportToFile() -> URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())

        let filename = "PushToTalk_History_\(timestamp).txt"

        // Создаём содержимое файла
        var content = "PushToTalk Transcription History\n"
        content += "Exported: \(Date())\n"
        content += "Total entries: \(history.count)\n"
        content += String(repeating: "=", count: 50) + "\n\n"

        for (index, entry) in history.enumerated() {
            content += "Entry #\(index + 1)\n"
            content += "Timestamp: \(entry.formattedTimestamp)\n"
            content += "Duration: \(String(format: "%.1f", entry.duration))s\n"
            content += "Text: \(entry.text)\n"
            content += "\n" + String(repeating: "-", count: 50) + "\n\n"
        }

        // Сохраняем в Downloads
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let fileURL = downloadsURL.appendingPathComponent(filename)

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            print("TranscriptionHistory: ✓ История экспортирована: \(fileURL.path)")
            return fileURL
        } catch {
            print("TranscriptionHistory: ✗ Ошибка экспорта: \(error)")
            return nil
        }
    }

    /// Статистика по истории
    public var statistics: HistoryStatistics {
        let totalTranscriptions = history.count
        let totalDuration = history.reduce(0.0) { $0 + $1.duration }
        let averageDuration = totalTranscriptions > 0 ? totalDuration / Double(totalTranscriptions) : 0
        let totalWords = history.reduce(0) { $0 + $1.wordCount }

        return HistoryStatistics(
            totalTranscriptions: totalTranscriptions,
            totalDuration: totalDuration,
            averageDuration: averageDuration,
            totalWords: totalWords
        )
    }
}

/// Запись в истории транскрипций
public struct TranscriptionEntry: Identifiable, Codable, Equatable {
    public let id: UUID
    public let text: String
    public let timestamp: Date
    public let duration: TimeInterval

    public init(text: String, timestamp: Date, duration: TimeInterval) {
        self.id = UUID()
        self.text = text
        self.timestamp = timestamp
        self.duration = duration
    }

    /// Форматированная дата и время
    public var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }

    /// Относительное время (например, "2 minutes ago")
    public var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    /// Количество слов
    public var wordCount: Int {
        return text.split(separator: " ").count
    }

    /// Предпросмотр текста (первые 50 символов)
    public var preview: String {
        if text.count <= 50 {
            return text
        } else {
            return String(text.prefix(47)) + "..."
        }
    }
}

/// Статистика по истории транскрипций
public struct HistoryStatistics {
    public let totalTranscriptions: Int
    public let totalDuration: TimeInterval
    public let averageDuration: TimeInterval
    public let totalWords: Int

    public var formattedTotalDuration: String {
        let minutes = Int(totalDuration) / 60
        let seconds = Int(totalDuration) % 60
        return "\(minutes)m \(seconds)s"
    }

    public var formattedAverageDuration: String {
        return String(format: "%.1fs", averageDuration)
    }
}
