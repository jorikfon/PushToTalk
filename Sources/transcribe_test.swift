import Foundation
import WhisperKit

@main
struct TranscribeTest {
    static func main() async {
        print("🎤 WhisperKit Transcription Test")
        print("=================================\n")

        let audioPath = "/Users/nb/Developement/PushToTalk/mic_test.wav"

        print("📂 Audio file: \(audioPath)")

        // Check if file exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: audioPath) else {
            print("❌ Audio file not found!")
            return
        }

        print("✓ Audio file found\n")

        do {
            // Initialize WhisperKit with tiny model
            print("📦 Loading Whisper model (tiny)...")

            let config = WhisperKitConfig(
                model: "tiny",
                verbose: false,
                logLevel: .info
            )

            let whisperKit = try await WhisperKit(config)
            print("✓ WhisperKit initialized\n")

            // Transcribe the audio file
            print("🔄 Transcribing audio...")
            print("   This may take a few seconds...\n")

            let startTime = Date()

            let results = try await whisperKit.transcribe(audioPath: audioPath)

            let duration = Date().timeIntervalSince(startTime)

            // Display results
            print("✅ Transcription completed in \(String(format: "%.2f", duration)) seconds\n")

            if results.isEmpty {
                print("⚠️ No transcription results available")
            } else {
                // Combine all text from results
                let fullText = results.map { $0.text }.joined(separator: " ")

                print("📝 Transcription:")
                print("─────────────────────────────────────")
                print(fullText)
                print("─────────────────────────────────────")

                // Display segments from first result
                if let firstResult = results.first {
                    let segments = firstResult.segments
                    print("\n📊 Segments: \(segments.count)")

                    if !segments.isEmpty {
                        print("\n🔍 Detailed segments:")
                        for (index, segment) in segments.enumerated() {
                            let start = String(format: "%.2f", segment.start)
                            let end = String(format: "%.2f", segment.end)
                            print("   [\(index + 1)] [\(start)s - \(end)s] \(segment.text)")
                        }
                    }

                    // Language detection
                    print("\n🌍 Detected language: \(firstResult.language)")
                }
            }

        } catch {
            print("❌ Error during transcription: \(error)")
            print("   Error details: \(error.localizedDescription)")
        }

        print("\n🎉 Test completed!")
    }
}
