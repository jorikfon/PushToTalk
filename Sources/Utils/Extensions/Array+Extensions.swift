//
//  Array+Extensions.swift
//  PushToTalk
//
//  Useful Array extensions for PushToTalk application
//

import Foundation

// MARK: - Array Extensions

extension Array {
    /// Safe subscript access (returns nil if out of bounds)
    /// - Parameter index: Index to access
    /// - Returns: Element or nil
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }

    /// Returns array chunked into arrays of specified size
    /// - Parameter size: Chunk size
    /// - Returns: Array of chunks
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }

    /// Removes duplicate elements (preserves order)
    /// - Returns: Array with unique elements
    func unique<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var seen = Set<T>()
        return filter { element in
            let key = element[keyPath: keyPath]
            if seen.contains(key) {
                return false
            } else {
                seen.insert(key)
                return true
            }
        }
    }
}

// MARK: - Array where Element is Equatable

extension Array where Element: Equatable {
    /// Removes all occurrences of element
    /// - Parameter element: Element to remove
    mutating func removeAll(_ element: Element) {
        self.removeAll { $0 == element }
    }

    /// Returns array with unique elements (preserves order)
    /// - Returns: Array with unique elements
    func uniqued() -> [Element] {
        var result: [Element] = []
        for element in self {
            if !result.contains(element) {
                result.append(element)
            }
        }
        return result
    }
}

// MARK: - Array of Floats (Audio Samples)

extension Array where Element == Float {
    /// Calculates RMS (Root Mean Square) of audio samples
    /// - Returns: RMS value
    func rms() -> Float {
        guard !isEmpty else { return 0.0 }
        let sumOfSquares = self.reduce(0.0) { $0 + $1 * $1 }
        return sqrt(sumOfSquares / Float(count))
    }

    /// Calculates peak amplitude
    /// - Returns: Peak value
    func peak() -> Float {
        return self.map { abs($0) }.max() ?? 0.0
    }

    /// Normalizes audio samples to peak amplitude
    /// - Parameter targetPeak: Target peak amplitude (default 1.0)
    /// - Returns: Normalized samples
    func normalized(to targetPeak: Float = 1.0) -> [Float] {
        let currentPeak = self.peak()
        guard currentPeak > 0 else { return self }
        let scale = targetPeak / currentPeak
        return self.map { $0 * scale }
    }

    /// Applies gain to audio samples
    /// - Parameter gain: Gain factor
    /// - Returns: Samples with applied gain
    func withGain(_ gain: Float) -> [Float] {
        return self.map { $0 * gain }
    }

    /// Detects silence in audio samples
    /// - Parameter threshold: Silence threshold (default 0.01)
    /// - Returns: True if silent
    func isSilent(threshold: Float = 0.01) -> Bool {
        return self.rms() < threshold
    }

    /// Calculates average of samples
    /// - Returns: Average value
    func average() -> Float {
        guard !isEmpty else { return 0.0 }
        return self.reduce(0.0, +) / Float(count)
    }

    /// Clips samples to range [-1.0, 1.0]
    /// - Returns: Clipped samples
    func clipped() -> [Float] {
        return self.map { Swift.max(-1.0, Swift.min(1.0, $0)) }
    }
}

// MARK: - Array of Strings

extension Array where Element == String {
    /// Joins array with comma separator
    /// - Returns: Comma-separated string
    func joinedWithComma() -> String {
        return self.joined(separator: ", ")
    }

    /// Filters empty strings
    /// - Returns: Array without empty strings
    func filterEmpty() -> [String] {
        return self.filter { !$0.isEmpty }
    }

    /// Trims all strings in array
    /// - Returns: Array of trimmed strings
    func trimmed() -> [String] {
        return self.map { $0.trimmed() }
    }
}

// MARK: - Collection Extensions

extension Collection {
    /// Checks if collection is not empty
    /// - Returns: True if not empty
    var isNotEmpty: Bool {
        return !isEmpty
    }
}
