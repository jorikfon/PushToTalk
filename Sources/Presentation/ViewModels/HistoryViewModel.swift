import Foundation
import Combine
import AppKit

/// ViewModel для управления историей транскрипций
/// Упрощенная версия для совместимости с существующим API
public final class HistoryViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Список записей истории транскрипций
    @Published public private(set) var entries: [TranscriptionEntry] = []

    /// Фильтрованные записи (по поисковому запросу)
    @Published public private(set) var filteredEntries: [TranscriptionEntry] = []

    /// Поисковый запрос
    @Published public var searchQuery: String = "" {
        didSet {
            filterEntries()
        }
    }

    /// Выбранные записи (для bulk operations)
    @Published public var selectedEntries: Set<UUID> = []

    // MARK: - Private Properties

    private let transcriptionHistory: TranscriptionHistory
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    public init(transcriptionHistory: TranscriptionHistory) {
        self.transcriptionHistory = transcriptionHistory

        setupBindings()
        loadEntries()
    }

    // MARK: - Public Methods

    /// Копирует текст записи в буфер обмена
    public func copyToClipboard(_ entry: TranscriptionEntry) {
        transcriptionHistory.copyToClipboard(entry)
    }

    /// Копирует выделенные записи в буфер обмена
    public func copySelectedToClipboard() {
        let selectedTexts = filteredEntries
            .filter { selectedEntries.contains($0.id) }
            .map { $0.text }
            .joined(separator: "\n\n")

        guard !selectedTexts.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(selectedTexts, forType: .string)
    }

    /// Удаляет запись из истории
    public func deleteEntry(_ entry: TranscriptionEntry) {
        transcriptionHistory.deleteEntry(entry)
        loadEntries()
    }

    /// Удаляет выделенные записи
    public func deleteSelectedEntries() {
        let entriesToDelete = filteredEntries.filter { selectedEntries.contains($0.id) }

        for entry in entriesToDelete {
            transcriptionHistory.deleteEntry(entry)
        }

        selectedEntries.removeAll()
        loadEntries()
    }

    /// Очищает всю историю
    public func clearHistory() {
        transcriptionHistory.clearHistory()
        selectedEntries.removeAll()
        loadEntries()
    }

    /// Переключает выбор записи
    public func toggleSelection(_ entryId: UUID) {
        if selectedEntries.contains(entryId) {
            selectedEntries.remove(entryId)
        } else {
            selectedEntries.insert(entryId)
        }
    }

    /// Выбрать все записи
    public func selectAll() {
        selectedEntries = Set(filteredEntries.map { $0.id })
    }

    /// Снять выбор со всех записей
    public func deselectAll() {
        selectedEntries.removeAll()
    }

    /// Форматирует длительность записи
    public func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60

        if minutes > 0 {
            return String(format: "%d%@ %d%@", minutes, Strings.Units.minutes, seconds, Strings.Units.seconds)
        } else {
            return String(format: "%d%@", seconds, Strings.Units.seconds)
        }
    }

    /// Форматирует дату записи
    public func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Подписываемся на изменения истории через objectWillChange
        transcriptionHistory.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadEntries()
            }
            .store(in: &cancellables)
    }

    private func loadEntries() {
        entries = transcriptionHistory.history
        filterEntries()
    }

    private func filterEntries() {
        if searchQuery.isEmpty {
            filteredEntries = entries
        } else {
            filteredEntries = entries.filter { entry in
                entry.text.localizedCaseInsensitiveContains(searchQuery)
            }
        }
    }
}
