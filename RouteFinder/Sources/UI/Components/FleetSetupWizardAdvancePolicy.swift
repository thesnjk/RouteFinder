import Foundation

/// Pure advance rules for ``FleetSetupWizardView`` (unit-testable without View hosting).
public enum FleetSetupWizardAdvancePolicy: Sendable {
    /// Wizard steps in order.
    public enum Step: Int, Sendable, CaseIterable {
        case enableRemote
        case discover
        case test
        case vehicle
        case done
    }

    /// Whether Next is enabled for the given wizard step and inputs.
    ///
    /// The **test** step requires a successful connection status containing `"Connected"`
    /// (auth probe + health). A non-empty URL alone is not enough — that undoes the
    /// fleet API key gate for stranger LAN pilots.
    public static func canAdvance(
        step: Step,
        connectionStatus: String?,
        urlText: String,
        isHosted: Bool,
        vehicleIdText: String
    ) -> Bool {
        switch step {
        case .enableRemote, .done:
            return true
        case .discover:
            let text = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, let url = URL(string: text), let scheme = url.scheme?.lowercased() else {
                return false
            }
            if isHosted { return scheme == "https" }
            return scheme == "http" || scheme == "https"
        case .test:
            return (connectionStatus ?? "").contains("Connected")
        case .vehicle:
            return UUID(uuidString: vehicleIdText.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
        }
    }
}
