#if os(macOS)
import AppKit

/// Ensures the app and its frontmost sheet accept keyboard input when launched from Terminal.
@MainActor
enum MacAppActivation {
    /// Activates the app and promotes the frontmost sheet or window for text input.
    static func activateForTextInput() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let target = NSApp.windows.last(where: { $0.isSheet })
            ?? NSApp.windows.first(where: { $0.isKeyWindow })
            ?? NSApp.windows.last
        target?.makeKeyAndOrderFront(nil)
    }
}
#endif
