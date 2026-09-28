import Foundation

/// When Mac Dispatch should show an inline fleet API key paste field.
///
/// Window → Dispatch bootstrap enables remote with no key; pilot `--api-key` servers then
/// show Auth failed. Paste on the desk (parity with web Bearer) recovers without Settings.
public enum DispatchFleetKeyPasteGate: Sendable {
    /// Remote fleet and health is not Connected (`healthOk != true`).
    public static func needsPaste(isRemoteFleet: Bool, healthOk: Bool?) -> Bool {
        isRemoteFleet && healthOk != true
    }
}
