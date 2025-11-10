import SwiftUI

/// Представление истории транскрипций с статистикой, поиском и управлением записями
struct HistorySettingsView: View {
    @ObservedObject var history: TranscriptionHistory
    @ObservedObject var userSettings: UserSettings

    @State private var searchText: String = ""
    @State private var showingExportSuccess = false
    @State private var isTestRecording = false

    var body: some View {
        VStack(spacing: 16) {
            // Statistics Section
            statisticsView

            // History List
            if history.history.isEmpty {
                emptyStateView
            } else {
                historyListView
            }

            // History Controls
            historyControlsView
        }
    }

    // MARK: - Statistics View

    private var statisticsView: some View {
        let stats = history.statistics

        return HStack(spacing: 16) {
            statCard(title: "Total", value: "\(stats.totalTranscriptions)", color: .blue)
            statCard(title: "Words", value: "\(stats.totalWords)", color: .green)
            statCard(title: "Avg Time", value: stats.formattedAverageDuration, color: .orange)
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.bubble")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(Strings.History.noTranscriptions)
                .font(.headline)
                .foregroundColor(.secondary)
            Text(Strings.History.pressHotkeyToRecord)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - History List View

    private var historyListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(history.history) { entry in
                    historyRow(for: entry)
                }
            }
        }
    }

    // MARK: - History Controls View

    private var historyControlsView: some View {
        HStack(spacing: 12) {
            Button(action: testRecording) {
                Label(isTestRecording ? "Recording..." : "Test Recording",
                      systemImage: isTestRecording ? "mic.fill" : "mic")
            }
            .buttonStyle(.borderedProminent)
            .tint(isTestRecording ? .red : .blue)
            .disabled(isTestRecording)

            if !history.history.isEmpty {
                Button(action: exportHistory) {
                    Label(Strings.History.export, systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            if !history.history.isEmpty {
                Button(action: {
                    history.clearHistory()
                }) {
                    Label(Strings.History.clearAll, systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
    }

    // MARK: - Helper Views

    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }

    private func historyRow(for entry: TranscriptionEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with timestamp and metadata
            HStack {
                Text(entry.relativeTimestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(String(format: "%.1fs", entry.duration))
                    .font(.caption2)
                    .padding(4)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)

                Text("\(entry.wordCount) words")
                    .font(.caption2)
                    .padding(4)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }

            // Transcribed text
            Text(entry.text)
                .font(.body)
                .lineLimit(3)

            // Action buttons
            HStack(spacing: 8) {
                Button(action: {
                    history.copyToClipboard(entry)
                }) {
                    Label(Strings.History.copy, systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button(action: {
                    history.deleteEntry(entry)
                }) {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.red)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(10)
    }

    // MARK: - Actions

    private func exportHistory() {
        if history.exportToFile() != nil {
            showingExportSuccess = true
        }
    }

    private func testRecording() {
        isTestRecording = true
        print("🎤 TEST RECORDING: Starting 3-second test recording...")

        NotificationCenter.default.post(name: NSNotification.Name("StartTestRecording"), object: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            print("🎤 TEST RECORDING: Stopping and transcribing...")
            NotificationCenter.default.post(name: NSNotification.Name("StopTestRecording"), object: nil)
            isTestRecording = false
        }
    }
}

#Preview {
    HistorySettingsView(
        history: TranscriptionHistory.shared,
        userSettings: UserSettings.shared
    )
}
