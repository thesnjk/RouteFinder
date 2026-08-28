import Foundation
import Observation

/// Observable load state for the embedded MapLibre WKWebView map.
@Observable
public final class MapWebViewLoadState {
    /// Whether the MapLibre map has posted `ready` to the native bridge.
    public var isReady = false
    /// Non-nil when the map or style failed to load.
    public var errorMessage: String?
    /// True while waiting for the first successful map load.
    public var isLoading = true

    public init() {}

    /// Clears error state and marks the map as loading again (e.g. before reload).
    public func resetForReload() {
        isReady = false
        errorMessage = nil
        isLoading = true
    }

    /// Marks the map as successfully loaded.
    public func markReady() {
        isReady = true
        errorMessage = nil
        isLoading = false
    }

    /// Records a load failure surfaced from JavaScript or WKWebView.
    public func markFailed(_ message: String) {
        isReady = false
        errorMessage = message
        isLoading = false
    }
}
