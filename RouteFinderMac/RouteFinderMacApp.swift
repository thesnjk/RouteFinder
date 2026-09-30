import AppKit
import Contracts
import SwiftUI
import UI

/// Signed macOS app entry (Xcode `RouteFinderMac` target). Prefer this over SPM `RouteFinderMacApp`.
@main
struct RouteFinderMacAppEntry: App {
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate

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

@MainActor
final class MacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }
}
