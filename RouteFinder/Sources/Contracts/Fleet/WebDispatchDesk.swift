import Foundation

#if os(macOS)
import AppKit
#endif

/// Local Vite URL and helpers for the browser desk console (`web-dispatch`).
public enum WebDispatchDesk: Sendable {
    /// Default local Vite URL for Mac office desk (same machine as `npm run dev`).
    public static let localDevURLString = "http://127.0.0.1:5173"

    /// Parsed local Vite URL.
    public static var localDevURL: URL {
        URL(string: localDevURLString)!
    }

    /// Terminal command to start web-dispatch from the repo root.
    public static let npmDevCommand = "cd web-dispatch && npm run dev"

    /// Opens the local web-dispatch console in the default browser (macOS only).
    @MainActor
    public static func openLocalDevInBrowser() {
        #if os(macOS)
        NSWorkspace.shared.open(localDevURL)
        #endif
    }
}
