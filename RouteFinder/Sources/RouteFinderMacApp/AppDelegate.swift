#if os(macOS)
import AppKit

/// Brings the app to the foreground when launched via `swift run` or from a `.app` bundle.
/// A benign "Task policy set failed: 4 ((os/kern) invalid argument)" log may still appear
/// when the process inherits Terminal QoS; it has no functional impact. Prefer
/// `./Scripts/package-macos-app.sh open` for proper keyboard focus in sheets and text fields.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }
}
#endif
