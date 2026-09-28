import Contracts
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

    private let serverCommand =
        #"swift run RouteFinderFleetServer --port 8080 --ors-key "$ORS_API_KEY" --api-key "your-shared-secret""#

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

                        Text("Pilot: keep `--api-key` and paste the same secret into Mac Settings, web dispatch Bearer, and the driver fleet wizard.")
                            .font(RFFont.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(RFSpacing.md)
                    .glassPanel(cornerRadius: 16)

                    VStack(alignment: .leading, spacing: RFSpacing.sm) {
                        Text("2. Open Dispatch console")
                            .font(RFFont.summary.weight(.semibold))
                        Text("Create an organisation, register a vehicle, show the QR to the driver, then push a trip.")
                            .font(RFFont.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            onOpenDispatch()
                        } label: {
                            Label("Open Dispatch Console", systemImage: "rectangle.split.2x1")
                        }
                        .modifier(GlassButton())
                        .accessibilityIdentifier("dispatcherOpenDispatch")
                    }
                    .padding(RFSpacing.md)
                    .glassPanel(cornerRadius: 16)

                    Button("Continue to map", action: onContinue)
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

    private func copyToPasteboard(_ string: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = string
        #endif
    }
}
