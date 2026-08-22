#if os(macOS)
import AppKit
import SwiftUI

/// Configures the hosting `NSWindow` for standard title-bar zoom and edge-to-edge content.
struct MacWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        configureWindow(from: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configureWindow(from: nsView)
    }

    private func configureWindow(from view: NSView) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }

            window.title = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "RouteFinder"
            window.isOpaque = true
            window.backgroundColor = .windowBackgroundColor
            window.isMovableByWindowBackground = false
            window.collectionBehavior = [.fullScreenPrimary, .managed]
        }
    }
}
#endif
