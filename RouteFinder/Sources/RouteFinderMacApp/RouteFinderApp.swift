#if os(macOS)
import AppKit
import SwiftUI
import UI

@main
struct RouteFinderMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootAuthContainer()
        }
        .defaultSize(width: 1400, height: 900)
        .windowStyle(.titleBar)
        .windowResizability(.automatic)

        WindowGroup("Dispatch Console", id: "dispatch") {
            DispatchConsoleView()
        }
        .defaultSize(width: 1200, height: 800)
        .windowStyle(.titleBar)
        .windowResizability(.automatic)
    }
}
#endif
