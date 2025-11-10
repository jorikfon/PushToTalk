//
//  String+Extensions.swift
//  PushToTalk
//
//  Useful String extensions for PushToTalk application
//

import Foundation

// MARK: - String Extensions

extension String {
    /// Returns localized string using NSLocalizedString
    /// - Returns: Localized string
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }

    /// Returns localized string with format arguments
    /// - Parameter arguments: Format arguments
    /// - Returns: Formatted localized string
    func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }

    /// Trims whitespace and newlines from both ends
    /// - Returns: Trimmed string
    func trimmed() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Checks if string is empty after trimming
    /// - Returns: True if empty after trimming
    var isBlank: Bool {
        return self.trimmed().isEmpty
    }

    /// Checks if string is not empty after trimming
    /// - Returns: True if not empty after trimming
    var isNotBlank: Bool {
        return !self.isBlank
    }

    /// Truncates string to specified length with ellipsis
    /// - Parameters:
    ///   - length: Maximum length
    ///   - trailing: Trailing string (default "...")
    /// - Returns: Truncated string
    func truncated(to length: Int, trailing: String = "...") -> String {
        if self.count > length {
            let endIndex = self.index(self.startIndex, offsetBy: length)
            return String(self[..<endIndex]) + trailing
        }
        return self
    }

    /// Checks if string matches regex pattern
    /// - Parameter pattern: Regex pattern
    /// - Returns: True if matches
    func matches(pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return false
        }
        let range = NSRange(location: 0, length: self.utf16.count)
        return regex.firstMatch(in: self, options: [], range: range) != nil
    }

    /// Replaces all occurrences matching regex pattern
    /// - Parameters:
    ///   - pattern: Regex pattern
    ///   - replacement: Replacement string
    /// - Returns: String with replacements
    func replacingMatches(of pattern: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return self
        }
        let range = NSRange(location: 0, length: self.utf16.count)
        return regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: replacement)
    }

    /// Converts string to file size format (KB, MB, GB)
    /// - Returns: Formatted file size string
    func asFileSize() -> String {
        guard let bytes = Int(self) else { return self }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    /// Checks if string contains substring (case-insensitive)
    /// - Parameter substring: Substring to search
    /// - Returns: True if contains
    func containsIgnoringCase(_ substring: String) -> Bool {
        return self.lowercased().contains(substring.lowercased())
    }

    /// Returns first N characters
    /// - Parameter count: Number of characters
    /// - Returns: Substring with first N characters
    func prefix(_ count: Int) -> String {
        guard count > 0, count < self.count else { return self }
        let endIndex = self.index(self.startIndex, offsetBy: count)
        return String(self[..<endIndex])
    }

    /// Returns last N characters
    /// - Parameter count: Number of characters
    /// - Returns: Substring with last N characters
    func suffix(_ count: Int) -> String {
        guard count > 0, count < self.count else { return self }
        let startIndex = self.index(self.endIndex, offsetBy: -count)
        return String(self[startIndex...])
    }
}

// MARK: - Optional String Extensions

extension Optional where Wrapped == String {
    /// Checks if optional string is nil or empty
    /// - Returns: True if nil or empty
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }

    /// Returns string or default value if nil/empty
    /// - Parameter defaultValue: Default value
    /// - Returns: String or default
    func orDefault(_ defaultValue: String) -> String {
        return self?.isEmpty == false ? self! : defaultValue
    }
}
