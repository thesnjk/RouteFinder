#if os(macOS)
import AppKit
import Contracts
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
        .commands {
            DispatchWindowCommands()
        }

        WindowGroup("Dispatch Console", id: "dispatch") {
            DispatchConsoleView()
        }
        .defaultSize(width: 1200, height: 800)
        .windowStyle(.titleBar)
        .windowResizability(.automatic)
    }
}

/// Menu command to open the browser desk console (web-dispatch).
private struct DispatchWindowCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .windowList) {
            Button("Open web dispatch") {
                WebDispatchDesk.openLocalDevInBrowser()
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
        }
    }
}
#endif
