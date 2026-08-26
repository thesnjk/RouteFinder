import Contracts
import SwiftUI
import UniformTypeIdentifiers

/// PDF export payload for ShareLink.
struct TripBriefPDF: Transferable, Sendable {
    let context: TripBriefContext

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { item in
            let data = TripBriefPDFRenderer.pdfData(from: item.context)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("RouteFinder-Trip-Brief.pdf")
            try data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
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
                ShareLink(
                    item: TripBriefPDF(context: context),
                    preview: SharePreview(
                        "RouteFinder Trip Brief",
                        icon: Image(systemName: "doc.richtext")
                    )
                ) {
                    Label("PDF", systemImage: "doc.richtext")
                }
            }
        } label: {
            shareLabel
        }
        .accessibilityLabel("Share trip brief")
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
