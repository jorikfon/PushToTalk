import SwiftUI

/// Представление настроек моделей Whisper
struct ModelSettingsView: View {
    @ObservedObject var modelManager: ModelManager
    @Binding var showingDeleteAlert: Bool
    @Binding var modelToDelete: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Download error alert
            if let error = modelManager.downloadError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Dismiss") {
                        modelManager.downloadError = nil
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
            }

            // Current model info
            SettingsCard(title: "Active Model", icon: "checkmark.circle.fill", color: .green) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(modelManager.currentModel.uppercased())
                            .font(.headline)
                        if let info = modelManager.getModelInfo(modelManager.currentModel) {
                            Text("\(info.speed) • \(info.accuracy) accuracy")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Text(modelManager.getModelSize(modelManager.currentModel))
                        .font(.caption)
                        .padding(6)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
            }

            // Available models
            Text("Available Models")
                .font(.headline)
                .padding(.top, 8)

            ForEach(modelManager.supportedModels) { model in
                modelRow(for: model)
            }
        }
    }

    private func modelRow(for model: WhisperModel) -> some View {
        let isDownloaded = modelManager.downloadedModels.contains(model.name)
        let isActive = modelManager.currentModel == model.name
        let isDownloadingThisModel = modelManager.downloadingModel == model.name
        let canDownload = !modelManager.isDownloading || isDownloadingThisModel

        return VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Model info
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("Size: \(model.size) • Speed: \(model.speed)")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("Accuracy: \(model.accuracy)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Actions
                VStack(spacing: 4) {
                    if isActive {
                        Label("Active", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else if isDownloaded {
                        Button("Use") {
                            modelManager.saveCurrentModel(model.name)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Button(isDownloadingThisModel ? "Downloading..." : "Download") {
                            downloadModel(model.name)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(!canDownload)
                    }

                    if isDownloaded && !isActive {
                        Button("Delete") {
                            modelToDelete = model.name
                            showingDeleteAlert = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.red)
                    }
                }
            }

            // Progress bar for this specific model
            if isDownloadingThisModel {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: modelManager.downloadProgress, total: 1.0)
                        .progressViewStyle(.linear)

                    Text("Downloading \(model.displayName)... \(Int(modelManager.downloadProgress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(10)
    }

    private func downloadModel(_ modelName: String) {
        Task {
            do {
                try await modelManager.downloadModel(modelName)
            } catch {
                print("Error downloading model: \(error)")
            }
        }
    }
}
