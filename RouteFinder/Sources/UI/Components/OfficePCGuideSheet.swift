import Contracts
import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// First-run guidance for office PC operators using browser web-dispatch.
struct OfficePCGuideSheet: View {
    var onContinue: () -> Void

    private var fleetURL: String { DeskLANAddress.shareableFleetServerURL() }
    private var didDetectLAN: Bool { DeskLANAddress.primaryIPv4() != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RFSpacing.lg) {
                    VStack(alignment: .leading, spacing: RFSpacing.sm) {
                        Text("Office PC dispatch")
                            .font(RFFont.sectionTitle)
                        Text("Use Chrome or Edge on a Windows or Linux PC against the office Mac fleet server. Keep this device on the same Wi‑Fi.")
                            .font(RFFont.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: RFSpacing.sm) {
                        Text("Fleet server URL")
                            .font(RFFont.summary.weight(.semibold))
                        Text(fleetURL)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(RFSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassPanel(cornerRadius: 12)
                        Text(
                            didDetectLAN
                                ? "Detected this Mac’s LAN address. Paste into web-dispatch on the office PC (same Wi‑Fi)."
                                : "Could not detect a LAN address — replace <office-mac-ip> with the Mac’s Wi‑Fi IP (System Settings → Network)."
                        )
                            .font(RFFont.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            copyToPasteboard(fleetURL)
                        } label: {
                            Label(
                                didDetectLAN ? "Copy fleet URL" : "Copy URL template",
                                systemImage: "doc.on.doc"
                            )
                        }
                        .modifier(GlassButton())
                        .accessibilityIdentifier("officePCCopyURL")
                    }
                    .padding(RFSpacing.md)
                    .glassPanel(cornerRadius: 16)

                    VStack(alignment: .leading, spacing: RFSpacing.sm) {
                        Text("Quick steps")
                            .font(RFFont.summary.weight(.semibold))
                        bullet("Someone starts RouteFinderFleetServer on the office Mac with --ors-key and --api-key (same secret as web Bearer / driver wizard)")
                        bullet("On the office PC: open the web-dispatch console (Vite /fleet proxy or direct URL); paste the shared API key as Bearer")
                        bullet("Create organisation → register vehicle → show QR to drivers")
                        bullet("Push a trip — driver phones toast within ~5 seconds")
                        Text("Full detail: Docs/web-dispatch-operator-guide.md")
                            .font(RFFont.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, RFSpacing.xs)
                    }
                    .padding(RFSpacing.md)
                    .glassPanel(cornerRadius: 16)

                    Button("Got it", action: onContinue)
                        .modifier(GlassButton())
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("officePCContinue")
                }
                .padding(RFSpacing.lg)
            }
            .navigationTitle("Office PC")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .interactiveDismissDisabled()
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: RFSpacing.sm) {
            Text("•")
                .foregroundStyle(RFColor.route)
            Text(text)
                .font(RFFont.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
