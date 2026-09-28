import Contracts
import DataLayer
import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// First-run guidance for Mac / iPad dispatchers: fleet server command + open Dispatch.
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
                        Text("Start the fleet server on this Mac (same Wi‑Fi as drivers), then open the Dispatch console to register vehicles and push trips.")
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

                        Text("Pilot: keep `--api-key` and paste the same secret below (and into web Bearer / driver wizard).")
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
                        Text("2. Open Dispatch console")
                            .font(RFFont.summary.weight(.semibold))
                        Text("Wires this Mac to the local fleet server (http://127.0.0.1:8080) if no URL is saved yet, then opens Dispatch so push reaches paired drivers.")
                            .font(RFFont.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            applyDeskLANBootstrapAndOpen()
                        } label: {
                            Label("Open Dispatch Console", systemImage: "rectangle.split.2x1")
                        }
                        .modifier(GlassButton())
                        .accessibilityIdentifier("dispatcherOpenDispatch")
                    }
                    .padding(RFSpacing.md)
                    .glassPanel(cornerRadius: 16)

                    Button("Continue to map") {
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
