import Foundation
import AVFoundation
import AppKit

/// Manager for audio feedback during transcription process
public class AudioFeedbackManager: ObservableObject {
    public static let shared = AudioFeedbackManager()

    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var processingTimer: Timer?

    @Published public var soundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: "audioFeedbackEnabled")
            if !soundEnabled {
                stopProcessingSound()
            }
        }
    }

    private init() {
        self.soundEnabled = UserDefaults.standard.object(forKey: "audioFeedbackEnabled") as? Bool ?? true
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()

        guard let engine = audioEngine, let player = playerNode else { return }

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)

        do {
            try engine.start()
            LogManager.audio.info("AudioFeedbackManager: Audio engine started")
        } catch {
            LogManager.audio.error("Failed to start audio engine: \(error.localizedDescription)")
        }
    }

    // MARK: - Sound Effects

    /// Play start recording sound (short beep)
    public func playStartSound() {
        guard soundEnabled else { return }
        NSSound(named: "Tink")?.play()
        LogManager.audio.debug("AudioFeedback: Start sound")
    }

    /// Play stop recording sound
    public func playStopSound() {
        guard soundEnabled else { return }
        NSSound(named: "Pop")?.play()
        LogManager.audio.debug("AudioFeedback: Stop sound")
    }

    /// Play success sound (transcription completed)
    public func playSuccessSound() {
        guard soundEnabled else { return }
        NSSound(named: "Glass")?.play()
        LogManager.audio.debug("AudioFeedback: Success sound")
    }

    /// Play error sound
    public func playErrorSound() {
        guard soundEnabled else { return }
        NSSound(named: "Basso")?.play()
        LogManager.audio.debug("AudioFeedback: Error sound")
    }

    /// Start playing processing sound (periodic clicks/crackles)
    public func startProcessingSound() {
        guard soundEnabled else { return }

        stopProcessingSound() // Stop any existing timer

        LogManager.audio.info("AudioFeedback: Starting processing sound")

        // Play click sound periodically to indicate processing
        var clickCount = 0
        processingTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            guard let self = self, self.soundEnabled else { return }

            // Alternate between different click sounds for variety
            let sounds = ["Tink", "Pop", "Morse"]
            let sound = sounds[clickCount % sounds.count]

            if let clickSound = NSSound(named: sound) {
                clickSound.volume = 0.3 // Quieter for background processing
                clickSound.play()
            }

            clickCount += 1
        }

        // Add to run loop
        if let timer = processingTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    /// Stop playing processing sound
    public func stopProcessingSound() {
        processingTimer?.invalidate()
        processingTimer = nil
        LogManager.audio.debug("AudioFeedback: Stopped processing sound")
    }

    // MARK: - Advanced Processing Sound (Synthesized)

    /// Generate and play a synthetic click sound
    private func generateClickSound() -> AVAudioPCMBuffer? {
        guard let engine = audioEngine else { return nil }

        let sampleRate = engine.mainMixerNode.outputFormat(forBus: 0).sampleRate
        let clickDuration: Double = 0.02 // 20ms
        let frameCount = AVAudioFrameCount(sampleRate * clickDuration)

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: AVAudioFormat(
                standardFormatWithSampleRate: sampleRate,
                channels: 1
            )!,
            frameCapacity: frameCount
        ) else { return nil }

        buffer.frameLength = frameCount

        guard let channelData = buffer.floatChannelData else { return nil }
        let samples = channelData[0]

        // Generate a short click/pop sound
        for i in 0..<Int(frameCount) {
            let t = Float(i) / Float(frameCount)
            // Exponential decay envelope
            let envelope = expf(-10.0 * t)
            // White noise with envelope
            let noise = Float.random(in: -1...1) * envelope * 0.3
            samples[i] = noise
        }

        return buffer
    }

    /// Start advanced processing sound with synthesized clicks
    public func startAdvancedProcessingSound() {
        guard soundEnabled else { return }
        guard let player = playerNode else { return }

        stopProcessingSound()

        LogManager.audio.info("AudioFeedback: Starting advanced processing sound")

        // Schedule periodic click sounds
        processingTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            guard let self = self, self.soundEnabled else { return }
            guard let clickBuffer = self.generateClickSound() else { return }

            if !player.isPlaying {
                player.play()
            }

            player.scheduleBuffer(clickBuffer, completionHandler: nil)
        }

        if let timer = processingTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    deinit {
        stopProcessingSound()
        audioEngine?.stop()
    }
}
