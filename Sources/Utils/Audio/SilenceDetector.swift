import Foundation
import Accelerate

/// Детектор тишины в аудио сэмплах
/// Анализирует RMS и определяет, содержит ли аудио значимый звук
public class SilenceDetector {
    public static let shared = SilenceDetector()

    // Пороговые значения
    /// Граница тишина/речь. Публичный — единый источник истины: тем же порогом
    /// reuse-логика проверяет хвост, чтобы быть не менее строгой, чем финальная
    /// детекция речи (иначе тихое последнее слово было бы отброшено).
    public let rmsThreshold: Float = 0.002  // Минимальный RMS для "не тишины"
    private let minSpeechDuration: Float = 0.3  // Минимальная длительность речи (секунды)

    private init() {
        LogManager.audio.info("SilenceDetector: Инициализация")
    }

    /// Проверка, является ли аудио тишиной
    /// - Parameter audioSamples: Массив Float32 аудио сэмплов (16kHz mono)
    /// - Returns: true если аудио - тишина, false если содержит звук
    public func isSilence(_ audioSamples: [Float]) -> Bool {
        guard !audioSamples.isEmpty else {
            LogManager.audio.debug("SilenceDetector: Пустой массив сэмплов")
            return true
        }

        let duration = Float(audioSamples.count) / 16000.0
        LogManager.audio.debug("SilenceDetector: Анализ \(audioSamples.count) сэмплов (\(String(format: "%.2f", duration))s)")

        // Вычисляем RMS (Root Mean Square) - мера энергии сигнала
        let rms = calculateRMS(audioSamples)

        LogManager.audio.debug("SilenceDetector: RMS = \(String(format: "%.4f", rms)), порог = \(String(format: "%.4f", self.rmsThreshold))")

        // Проверяем длительность
        if duration < self.minSpeechDuration {
            LogManager.audio.info("SilenceDetector: ❌ Слишком короткая запись (\(String(format: "%.2f", duration))s < \(self.minSpeechDuration)s)")
            return true
        }

        // Проверяем уровень звука
        if rms < self.rmsThreshold {
            LogManager.audio.info("SilenceDetector: ❌ Тишина (RMS \(String(format: "%.4f", rms)) < \(self.rmsThreshold))")
            return true
        }

        LogManager.audio.success("SilenceDetector: ✓ Обнаружен звук", details: "RMS=\(String(format: "%.4f", rms)), duration=\(String(format: "%.2f", duration))s")
        return false
    }

    /// Проверяет, что ВЕСЬ отрезок — тишина, по непересекающимся окнам.
    /// Одиночное усреднённое RMS прячет короткое слово в длинной тишине; оконная
    /// проверка ловит любое окно с энергией. Используется для анализа коротких
    /// хвостов (где `isSilence` из-за minSpeechDuration ложно вернул бы true).
    /// Пустой отрезок считается тишиной.
    public func isContinuousSilence(_ samples: [Float], windowSeconds: Float = 0.1, rmsThreshold: Float) -> Bool {
        guard !samples.isEmpty else { return true }
        let windowSize = max(1, Int(windowSeconds * 16000))
        var index = 0
        while index < samples.count {
            let end = min(index + windowSize, samples.count)
            if calculateRMS(Array(samples[index..<end])) >= rmsThreshold {
                return false
            }
            index = end
        }
        return true
    }

    /// Вычисление RMS (Root Mean Square) для аудио сигнала
    /// - Parameter samples: Массив аудио сэмплов
    /// - Returns: RMS значение
    private func calculateRMS(_ samples: [Float]) -> Float {
        var rms: Float = 0.0

        // Используем Accelerate framework для быстрого вычисления
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))

        return rms
    }

    /// Получить статистику аудио сигнала (для отладки)
    public func getAudioStats(_ audioSamples: [Float]) -> AudioStats {
        let rms = calculateRMS(audioSamples)
        let duration = Float(audioSamples.count) / 16000.0

        var maxValue: Float = 0.0
        var minValue: Float = 0.0
        vDSP_maxv(audioSamples, 1, &maxValue, vDSP_Length(audioSamples.count))
        vDSP_minv(audioSamples, 1, &minValue, vDSP_Length(audioSamples.count))

        return AudioStats(
            sampleCount: audioSamples.count,
            duration: duration,
            rms: rms,
            maxAmplitude: maxValue,
            minAmplitude: minValue,
            isSilence: isSilence(audioSamples)
        )
    }
}

/// Статистика аудио сигнала
public struct AudioStats {
    public let sampleCount: Int
    public let duration: Float
    public let rms: Float
    public let maxAmplitude: Float
    public let minAmplitude: Float
    public let isSilence: Bool

    public var description: String {
        """
        Audio Statistics:
        - Samples: \(sampleCount)
        - Duration: \(String(format: "%.2f", duration))s
        - RMS: \(String(format: "%.4f", rms))
        - Max amplitude: \(String(format: "%.4f", maxAmplitude))
        - Min amplitude: \(String(format: "%.4f", minAmplitude))
        - Is silence: \(isSilence ? "YES" : "NO")
        """
    }
}
