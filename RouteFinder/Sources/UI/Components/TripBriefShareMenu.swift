import Contracts
import SwiftUI
import UniformTypeIdentifiers

/// Exported PDF file ready for the system share sheet.
private struct ExportedTripBriefPDF: Identifiable {
    let id = UUID()
    let url: URL
}

/// Label presentation for trip brief share controls.
enum TripBriefShareLabelStyle {
    case iconOnly
    case fullWidth
    case caption
}

/// Share menu offering plain-text and PDF trip brief export.
struct TripBriefShareMenu: View {
    let context: TripBriefContext
    var labelStyle: TripBriefShareLabelStyle = .iconOnly

    @State private var isGeneratingPDF = false
    @State private var exportedPDF: ExportedTripBriefPDF?

    private var plainText: String {
        TripBriefFormatter.plainText(from: context)
    }

    private var pdfAvailable: Bool {
        !TripBriefFormatter.sections(from: context).isEmpty
    }

    var body: some View {
        Menu {
            ShareLink(item: plainText) {
                Label("Plain text", systemImage: "doc.text")
            }
            if pdfAvailable {
                Button {
                    Task { await exportPDF() }
                } label: {
                    Label("PDF", systemImage: "doc.richtext")
                }
                .disabled(isGeneratingPDF)
            }
        } label: {
            shareLabel
        }
        .accessibilityLabel("Share trip brief")
        .overlay {
            if isGeneratingPDF {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .sheet(item: $exportedPDF) { export in
            NavigationStack {
                ShareLink(
                    item: export.url,
                    preview: SharePreview(
                        "RouteFinder Trip Brief",
                        icon: Image(systemName: "doc.richtext")
                    )
                ) {
                    Label("Share PDF", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .padding(RFSpacing.lg)
                .navigationTitle("Trip Brief PDF")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                .presentationDetents([.medium])
                #endif
            }
        }
    }

    private func exportPDF() async {
        isGeneratingPDF = true
        defer { isGeneratingPDF = false }

        let stopCoordinates = context.stops.compactMap(\.coordinate)
        let mapPNG = await RouteMapSnapshotRenderer.snapshot(
            routeCoordinates: context.routeCoordinates,
            stopCoordinates: stopCoordinates
        )
        let data = TripBriefPDFRenderer.pdfData(from: context, mapImagePNG: mapPNG)
        guard !data.isEmpty else { return }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("RouteFinder-Trip-Brief-\(UUID().uuidString).pdf")
        do {
            try data.write(to: url, options: .atomic)
            exportedPDF = ExportedTripBriefPDF(url: url)
        } catch {
            return
        }
    }

    @ViewBuilder
    private var shareLabel: some View {
        switch labelStyle {
        case .iconOnly:
            Image(systemName: "square.and.arrow.up")
                .font(.body.weight(.semibold))
        case .caption:
            Label("Share brief", systemImage: "square.and.arrow.up")
                .font(RFFont.caption)
        case .fullWidth:
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.up")
                Text("Share trip brief")
                    .font(RFFont.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
        }
    }
}
