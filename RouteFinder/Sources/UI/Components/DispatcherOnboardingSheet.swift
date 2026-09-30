import Contracts
import DataLayer
import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// First-run guidance for Mac dispatchers: fleet server + web-dispatch desk (map app is for simulation).
struct DispatcherOnboardingSheet: View {
    var onOpenDispatch: () -> Void
    var onContinue: () -> Void

    @State private var sharedAPIKey: String = ""

    private let serverCommand =
        #"swift run RouteFinderFleetServer --port 8080 --ors-key "$ORS_API_KEY" --api-key "your-shared-secret""#

    private var shareableFleetURL: String { DeskLANAddress.shareableFleetServerURL() }
    private var didDetectLAN: Bool { DeskLANAddress.primaryIPv4() != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RFSpacing.lg) {
                    VStack(alignment: .leading, spacing: RFSpacing.sm) {
                        Text("Dispatcher setup")
                            .font(RFFont.sectionTitle)
                        Text("Desk UI is the browser console (web-dispatch). This Mac app is for map simulation and route rehearsal. Start the fleet server, then open web-dispatch to Bootstrap and push trips.")
                            .font(RFFont.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: RFSpacing.sm) {
                        Text("1. Terminal — fleet server")
                            .font(RFFont.summary.weight(.semibold))
                        Text("From the RouteFinder package directory:")
                            .font(RFFont.caption)
                            .foregroundStyle(.secondary)
                        Text(serverCommand)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(RFSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassPanel(cornerRadius: 12)

                        Button {
                            copyToPasteboard(serverCommand)
                        } label: {
                            Label("Copy server command", systemImage: "doc.on.doc")
                        }
                        .modifier(GlassButton())
                        .accessibilityIdentifier("dispatcherCopyServerCommand")

                        Text("Pilot: keep `--api-key` and paste the same secret into web-dispatch Bearer and the driver wizard.")
                            .font(RFFont.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        SecureField("Shared fleet API key (your-shared-secret)", text: $sharedAPIKey)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("dispatcherSharedAPIKey")

                        Text("Share with office PC / drivers")
                            .font(RFFont.caption.weight(.semibold))
                            .padding(.top, RFSpacing.xs)
                        Text(shareableFleetURL)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(RFSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassPanel(cornerRadius: 12)
                        Text(
                            didDetectLAN
                                ? "Paste this URL into web-dispatch or the driver wizard when Bonjour discover is unavailable (same Wi‑Fi)."
                                : "LAN IP not detected — use System Settings → Network, or Discover on LAN in the driver wizard."
                        )
                            .font(RFFont.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button {
                            copyToPasteboard(shareableFleetURL)
                        } label: {
                            Label("Copy LAN fleet URL", systemImage: "network")
                        }
                        .modifier(GlassButton())
                        .accessibilityIdentifier("dispatcherCopyLANURL")
                    }
                    .padding(RFSpacing.md)
                    .glassPanel(cornerRadius: 16)

                    VStack(alignment: .leading, spacing: RFSpacing.sm) {
                        Text("2. Open web-dispatch (desk)")
                            .font(RFFont.summary.weight(.semibold))
                        Text("In a second Terminal from the repo root: \(WebDispatchDesk.npmDevCommand) — then open \(WebDispatchDesk.localDevURLString), paste the API key as Bearer, Bootstrap, and push.")
                            .font(RFFont.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            copyToPasteboard(WebDispatchDesk.npmDevCommand)
                        } label: {
                            Label("Copy web-dispatch command", systemImage: "doc.on.doc")
                        }
                        .modifier(GlassButton())
                        .accessibilityIdentifier("dispatcherCopyWebDispatchCommand")

                        #if os(macOS)
                        Button {
                            applyDeskLANBootstrap()
                            WebDispatchDesk.openLocalDevInBrowser()
                        } label: {
                            Label("Open web dispatch", systemImage: "safari")
                        }
                        .modifier(GlassButton())
                        .accessibilityIdentifier("dispatcherOpenWebDispatch")
                        #else
                        Button {
                            applyDeskLANBootstrapAndOpen()
                        } label: {
                            Label("Open Dispatch Console", systemImage: "rectangle.split.2x1")
                        }
                        .modifier(GlassButton())
                        .accessibilityIdentifier("dispatcherOpenDispatch")
                        #endif
                    }
                    .padding(RFSpacing.md)
                    .glassPanel(cornerRadius: 16)

                    Button("Continue to map (simulation)") {
                        applyDeskLANBootstrap()
                        onContinue()
                    }
                        .buttonStyle(.borderless)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("dispatcherContinue")
                }
                .padding(RFSpacing.lg)
            }
            .navigationTitle("Dispatcher")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .interactiveDismissDisabled()
    }

    private func applyDeskLANBootstrapAndOpen() {
        applyDeskLANBootstrap()
        onOpenDispatch()
    }

    private func applyDeskLANBootstrap() {
        do {
            try DispatcherDeskLANBootstrap.apply(
                apiKey: sharedAPIKey,
                saveAPIKey: { try FleetServerCredentials.saveAPIKey($0) }
            )
        } catch {
            // Operator can finish wiring in Settings if Keychain fails.
        }
    }

    private func copyToPasteboard(_ string: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = string
        #endif
    }
}
