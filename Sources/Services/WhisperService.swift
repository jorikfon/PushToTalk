import Foundation
import WhisperKit

/// Сервис для транскрипции аудио через WhisperKit
/// Поддерживает модели: tiny, base, small
public class WhisperService {
    private var whisperKit: WhisperKit?
    private let modelSize: String

    public init(modelSize: String = "tiny") {
        self.modelSize = modelSize
        print("WhisperService: Инициализация с моделью \(modelSize)")
    }

    /// Загрузка модели Whisper
    public func loadModel() async throws {
        print("WhisperService: Загрузка модели \(modelSize)...")

        do {
            // Инициализация WhisperKit с указанной моделью
            // Модель будет загружена автоматически с Hugging Face
            whisperKit = try await WhisperKit(
                model: modelSize,
                verbose: true,
                logLevel: .debug
            )

            print("WhisperService: ✓ Модель \(modelSize) успешно загружена")
        } catch {
            print("WhisperService: ✗ Ошибка загрузки модели: \(error)")
            throw WhisperError.modelLoadFailed(error)
        }
    }

    /// Транскрипция аудио данных
    /// - Parameter audioSamples: Массив Float32 аудио сэмплов (16kHz mono)
    /// - Returns: Распознанный текст
    public func transcribe(audioSamples: [Float]) async throws -> String {
        guard let whisperKit = whisperKit else {
            throw WhisperError.modelNotLoaded
        }

        print("WhisperService: Начало транскрипции (\(audioSamples.count) сэмплов)")

        do {
            // WhisperKit ожидает аудио массив
            let results = try await whisperKit.transcribe(audioArray: audioSamples)

            // Получаем финальный текст из массива результатов
            guard let firstResult = results.first else {
                print("WhisperService: Пустой результат транскрипции")
                return ""
            }

            let transcription = firstResult.text
            let cleanedText = transcription.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            print("WhisperService: ✓ Транскрипция завершена: \"\(cleanedText)\"")

            return cleanedText
        } catch {
            print("WhisperService: ✗ Ошибка транскрипции: \(error)")
            throw WhisperError.transcriptionFailed(error)
        }
    }

    /// Проверка готовности модели
    public var isReady: Bool {
        return whisperKit != nil
    }
}

/// Ошибки WhisperService
enum WhisperError: Error {
    case modelNotLoaded
    case modelLoadFailed(Error)
    case transcriptionFailed(Error)
    case invalidAudioFormat

    var localizedDescription: String {
        switch self {
        case .modelNotLoaded:
            return "Модель Whisper не загружена"
        case .modelLoadFailed(let error):
            return "Не удалось загрузить модель: \(error.localizedDescription)"
        case .transcriptionFailed(let error):
            return "Ошибка транскрипции: \(error.localizedDescription)"
        case .invalidAudioFormat:
            return "Неверный формат аудио данных"
        }
    }
}
