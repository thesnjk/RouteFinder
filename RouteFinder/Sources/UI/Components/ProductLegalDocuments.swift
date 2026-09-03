import Foundation

/// Bundled legal document metadata for Settings → Legal.
///
/// Full drafts live under `Docs/legal/` for solicitor review. Replace
/// ``privacyPolicyURL`` / ``termsOfServiceURL`` with hosted HTTPS URLs before
/// App Store submission.
public enum ProductLegalDocuments {
    /// Privacy Policy draft path in the repository (developer / operator reference).
    public static let privacyPolicyRepoPath = "Docs/legal/privacy-policy.md"

    /// Terms of Service draft path in the repository (developer / operator reference).
    public static let termsOfServiceRepoPath = "Docs/legal/terms-of-service.md"

    /// Hosted Privacy Policy URL when published; `nil` until you host a copy.
    public static let privacyPolicyURL: URL? = nil

    /// Hosted Terms of Service URL when published; `nil` until you host a copy.
    public static let termsOfServiceURL: URL? = nil

    /// Short in-app Privacy summary (not a substitute for the full policy).
    public static let privacyPolicySummary = """
    RouteFinder keeps fleet trip and inspection data on your devices and LAN by default. \
    Optional cloud APIs (OpenRouteService, TomTom, weather) only run when you add keys. \
    We do not sell your data. Full draft: Docs/legal/privacy-policy.md (solicitor review pending).
    """

    /// Short in-app Terms summary (not a substitute for the full ToS).
    public static let termsOfServiceSummary = """
    RouteFinder is licensed for your internal fleet use. Routing and physics outputs are \
    advisory only — road signs and regulations always win. See also in-app Driver Terms. \
    Full draft: Docs/legal/terms-of-service.md (solicitor review pending).
    """
}
