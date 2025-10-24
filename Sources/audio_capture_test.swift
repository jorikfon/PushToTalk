import Foundation
import AVFoundation
import PushToTalkCore

/// Тест для проверки работы AudioCaptureService
/// Записывает 3 секунды аудио и сохраняет в WAV файл

@main
struct AudioCaptureTest {
    static func main() async {
        print("=== AudioCaptureService Test ===")
        print("Нажмите Ctrl+C для выхода\n")

        let service = AudioCaptureService()

        // Проверка разрешений
        print("1. Проверка разрешений на микрофон...")
        let hasPermission = await service.checkPermissions()

        if !hasPermission {
            print("❌ Разрешение на доступ к микрофону не получено")
            print("   Откройте System Settings > Privacy & Security > Microphone")
            print("   и разрешите доступ для Terminal или вашего IDE")
            exit(1)
        }

        print("✓ Разрешение получено\n")

        // Тест 1: Короткая запись (3 секунды)
        print("2. Тест короткой записи (3 секунды)...")
        print("   Говорите что-нибудь в микрофон...")

        do {
            try service.startRecording()
            print("   🔴 Запись началась...")

            // Ждём 3 секунды
            try await Task.sleep(nanoseconds: 3_000_000_000)

            let audioData = service.stopRecording()
            print("   ⏹️  Запись остановлена")

            // Проверка данных
            let expectedSamples = 48000 // 3 секунды * 16000 Hz
            let tolerance = 1000

            print("\nРезультаты:")
            print("   Записано сэмплов: \(audioData.count)")
            print("   Ожидалось: ~\(expectedSamples) (±\(tolerance))")
            print("   Длительность: \(Float(audioData.count) / 16000.0) секунд")

            if audioData.count > expectedSamples - tolerance &&
               audioData.count < expectedSamples + tolerance {
                print("   ✓ Количество сэмплов корректно")
            } else {
                print("   ⚠️  Количество сэмплов отличается от ожидаемого")
            }

            // Проверка уровня сигнала
            let amplitudes = audioData.map { abs($0) }
            let maxAmplitude = amplitudes.max() ?? 0
            let sum = amplitudes.reduce(0, +)
            let avgAmplitude = sum / Float(audioData.count)

            print("\nАнализ сигнала:")
            print("   Максимальная амплитуда: \(maxAmplitude)")
            print("   Средняя амплитуда: \(avgAmplitude)")

            if maxAmplitude > 0.01 {
                print("   ✓ Обнаружен аудио сигнал")
            } else {
                print("   ⚠️  Сигнал очень слабый, проверьте микрофон")
            }

            // Сохранение в WAV файл
            print("\n3. Сохранение в WAV файл...")
            let fileName = "audio_test_\(Int(Date().timeIntervalSince1970)).wav"
            let filePath = FileManager.default.currentDirectoryPath + "/" + fileName

            if saveToWAV(audioData: audioData, filePath: filePath) {
                print("   ✓ Файл сохранён: \(filePath)")
                print("   Вы можете прослушать его командой:")
                print("   afplay \(fileName)")
            } else {
                print("   ❌ Не удалось сохранить файл")
            }

        } catch {
            print("❌ Ошибка записи: \(error)")
            exit(1)
        }

        // Тест 2: Проверка повторной записи
        print("\n4. Тест повторной записи (1 секунда)...")

        do {
            try service.startRecording()
            try await Task.sleep(nanoseconds: 1_000_000_000)
            let audioData2 = service.stopRecording()

            print("   ✓ Повторная запись успешна (\(audioData2.count) сэмплов)")

        } catch {
            print("   ❌ Ошибка повторной записи: \(error)")
        }

        print("\n=== Тест завершён успешно ===")
    }

    /// Сохранить аудио данные в WAV файл
    static func saveToWAV(audioData: [Float], filePath: String) -> Bool {
        // Создаём AVAudioFormat для 16kHz mono
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            return false
        }

        // Создаём AVAudioPCMBuffer
        let frameCount = AVAudioFrameCount(audioData.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return false
        }

        buffer.frameLength = frameCount

        // Копируем данные в буфер
        guard let channelData = buffer.floatChannelData else {
            return false
        }

        for (index, sample) in audioData.enumerated() {
            channelData[0][index] = sample
        }

        // Сохраняем в файл
        let url = URL(fileURLWithPath: filePath)

        do {
            let audioFile = try AVAudioFile(
                forWriting: url,
                settings: format.settings,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )

            try audioFile.write(from: buffer)
            return true

        } catch {
            print("Ошибка записи WAV: \(error)")
            return false
        }
    }
}
