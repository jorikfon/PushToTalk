import Foundation
import AVFoundation
import PushToTalkCore

/// Интеграционный тест: AudioCaptureService + WhisperService
/// Полный pipeline: микрофон → аудио буфер → транскрипция
@main
struct IntegrationTest {
    static func main() async {
        print("=== PushToTalk Integration Test ===")
        print("Testing: AudioCapture → Whisper Transcription")
        print("")

        // Инициализация сервисов
        let audioService = AudioCaptureService()
        let whisperService = WhisperService(modelSize: "tiny")

        print("Step 1/5: Checking microphone permissions...")
        let hasPermission = await audioService.checkPermissions()

        guard hasPermission else {
            print("❌ Microphone permission denied!")
            print("Please grant microphone access in System Settings > Privacy & Security")
            return
        }

        print("✅ Microphone permission granted")
        print("")

        print("Step 2/5: Loading Whisper model...")
        do {
            try await whisperService.loadModel()
            print("✅ Whisper model loaded successfully")
        } catch {
            print("❌ Failed to load Whisper model: \(error)")
            return
        }
        print("")

        print("Step 3/5: Recording audio for 3 seconds...")
        print("🎤 Please speak into your microphone...")
        print("")

        // Запись аудио
        do {
            try audioService.startRecording()
            print("⏺️  Recording started...")

            // Запись 3 секунды
            try await Task.sleep(nanoseconds: 3_000_000_000)

            let audioData = audioService.stopRecording()
            print("⏹️  Recording stopped")
            print("📊 Captured \(audioData.count) samples (\(Double(audioData.count) / 16000.0) seconds)")

            // Проверка наличия аудио сигнала
            let absValues = audioData.map { abs($0) }
            let maxAmplitude = absValues.max() ?? 0
            let sum = absValues.reduce(0, +)
            let avgAmplitude = sum / Float(audioData.count)

            print("   Max amplitude: \(String(format: "%.4f", maxAmplitude))")
            print("   Avg amplitude: \(String(format: "%.4f", avgAmplitude))")

            if maxAmplitude < 0.001 {
                print("⚠️  Warning: Very low audio signal detected!")
                print("   Please check your microphone input volume")
            }
            print("")

            print("Step 4/5: Transcribing audio with Whisper...")
            let startTime = Date()

            let transcription = try await whisperService.transcribe(audioSamples: audioData)

            let elapsed = Date().timeIntervalSince(startTime)
            print("✅ Transcription completed in \(String(format: "%.2f", elapsed)) seconds")
            print("")

            print("Step 5/5: Results")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            if transcription.isEmpty {
                print("⚠️  No speech detected or empty result")
                print("Possible reasons:")
                print("  - No speech in the recording")
                print("  - Audio level too low")
                print("  - Background noise only")
            } else {
                print("📝 Transcription: \"\(transcription)\"")
                print("")
                print("✅ SUCCESS! Full pipeline working correctly")
            }
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        } catch {
            print("❌ Error during recording or transcription: \(error)")
            return
        }

        print("")
        print("=== Test Completed ===")
    }
}
