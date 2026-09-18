import Foundation

/// Bundled legal document metadata for Settings → Legal.
///
/// Full drafts live under `Docs/legal/` for solicitor review. Static HTML for
/// hosting is under `Docs/legal/site/`. Replace ``legalURLBase`` with your
/// published HTTPS origin before App Store submission — URLs must match
/// App Store Connect Privacy Policy URL.
public enum ProductLegalDocuments {
    /// Privacy Policy draft path in the repository (developer / operator reference).
    public static let privacyPolicyRepoPath = "Docs/legal/privacy-policy.md"

    /// Terms of Service draft path in the repository (developer / operator reference).
    public static let termsOfServiceRepoPath = "Docs/legal/terms-of-service.md"

    /// Driver Terms draft path (solicitor packet; keep in sync with in-app copy).
    public static let driverTermsRepoPath = "Docs/legal/driver-terms.md"

    /// Published legal site origin. Replace `routefinder.app` after you host
    /// [`Docs/legal/site/`](Docs/legal/site/README.md). Must match App Store Connect.
    public static let legalURLBase = "https://routefinder.app/legal"

    /// Hosted Privacy Policy URL (placeholder until you publish HTML).
    public static let privacyPolicyURL: URL? = URL(string: "\(legalURLBase)/privacy")

    /// Hosted Terms of Service URL (placeholder until you publish HTML).
    public static let termsOfServiceURL: URL? = URL(string: "\(legalURLBase)/terms")

    /// Short in-app Privacy summary (not a substitute for the full policy).
    public static let privacyPolicySummary = """
    RouteFinder keeps fleet trip and inspection data on your devices and LAN by default. \
    Optional cloud APIs (OpenRouteService, TomTom, weather) and an optional hosted gateway \
    only run when you or your operator enable them. We do not sell your data. Open the full \
    Privacy Policy for details (solicitor review pending).
    """

    /// Short in-app Terms summary (not a substitute for the full ToS).
    public static let termsOfServiceSummary = """
    RouteFinder is licensed for your internal fleet use. Routing, toll hints, and physics \
    outputs are advisory only — road signs and regulations always win. See also in-app \
    Driver Terms. Open the full Terms of Service for licence, fees, and liability \
    (solicitor review pending).
    """
}
