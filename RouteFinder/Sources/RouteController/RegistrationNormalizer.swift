import Foundation

/// Sanitizes and formats vehicle registration marks for cache keys, network queries, and UI display.
public struct RegistrationNormalizer: Sendable {
    private static let ukDisplayPattern = "^[A-Z]{2}[0-9]{2}[A-Z]{3}$"

    /// Cleans, upper-cases, and removes all spaces, hyphens, and non-alphanumeric punctuation for strict cache keys and network queries.
    public static func normalize(_ rawRegistration: String) -> String {
        let uppercased = rawRegistration.uppercased()
        let filteredCharacters = uppercased.filter { $0.isLetter || $0.isNumber }
        return String(filteredCharacters)
    }

    /// Formats a normalized plate into a clean UI display layout when it matches known patterns (e.g. standard UK plates).
    public static func formatForDisplay(_ rawRegistration: String) -> String {
        let clean = normalize(rawRegistration)

        if clean.range(of: ukDisplayPattern, options: .regularExpression) != nil {
            let index4 = clean.index(clean.startIndex, offsetBy: 4)
            let prefix = clean[..<index4]
            let suffix = clean[index4...]
            return "\(prefix) \(suffix)"
        }

        return clean
    }
}
