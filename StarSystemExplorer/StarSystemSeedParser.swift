import Foundation

/// Converts decimal or hexadecimal user input into one stable generator seed.
nonisolated struct StarSystemSeedParser: Sendable {
    /// Accepts decimal digits or a `0x`-prefixed hexadecimal value. Underscores and surrounding whitespace are ignored.
    func parse(_ input: String) -> StarSystemSeed? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let compact = trimmed.replacingOccurrences(of: "_", with: "")
        guard !compact.isEmpty, compact.first != "+", compact.first != "-" else {
            return nil
        }

        let radix: Int
        let digits: Substring
        if compact.hasPrefix("0x") || compact.hasPrefix("0X") {
            radix = 16
            digits = compact.dropFirst(2)
        } else {
            radix = 10
            digits = Substring(compact)
        }

        guard !digits.isEmpty, let rawValue = UInt64(digits, radix: radix) else {
            return nil
        }
        return StarSystemSeed(rawValue: rawValue)
    }
}
