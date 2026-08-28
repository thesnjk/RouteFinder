import Foundation

/// Supported search display languages for Pelias geocoding.
public struct SearchLanguageOption: Sendable, Hashable, Identifiable {
    /// BCP-47 language code passed to Pelias.
    public let code: String
    /// Human-readable label for Settings pickers.
    public let label: String

    /// Stable identifier for SwiftUI lists.
    public var id: String { code }

    /// Creates a search language option.
    public init(code: String, label: String) {
        self.code = code
        self.label = label
    }
}

/// Persists search language and English fallback preferences.
public enum LanguageWorkspaceSettings {
    private static let preferredSearchLanguageKey = "RouteFinder.preferredSearchLanguage"
    private static let searchEnglishFallbackKey = "RouteFinder.searchEnglishFallback"

    /// Common Pelias language options exposed in Settings.
    public static let supportedOptions: [SearchLanguageOption] = [
        SearchLanguageOption(code: "en", label: "English"),
        SearchLanguageOption(code: "nb", label: "Norwegian (Bokmål)"),
        SearchLanguageOption(code: "nn", label: "Norwegian (Nynorsk)"),
        SearchLanguageOption(code: "de", label: "German"),
        SearchLanguageOption(code: "fr", label: "French"),
        SearchLanguageOption(code: "pl", label: "Polish"),
        SearchLanguageOption(code: "es", label: "Spanish"),
        SearchLanguageOption(code: "nl", label: "Dutch"),
    ]

    /// Preferred Pelias `lang` code (default English).
    public static func loadPreferredSearchLanguage(defaults: UserDefaults = .standard) -> String {
        defaults.string(forKey: preferredSearchLanguageKey) ?? "en"
    }

    /// Persists the preferred search language code.
    public static func savePreferredSearchLanguage(_ code: String, defaults: UserDefaults = .standard) {
        defaults.set(code, forKey: preferredSearchLanguageKey)
    }

    /// Whether to run a secondary English Pelias pass when results are sparse.
    public static func loadSearchEnglishFallback(defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: searchEnglishFallbackKey) == nil {
            return true
        }
        return defaults.bool(forKey: searchEnglishFallbackKey)
    }

    /// Persists the English fallback preference.
    public static func saveSearchEnglishFallback(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: searchEnglishFallbackKey)
    }
}
