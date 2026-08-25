import Contracts
import SwiftUI
import UniformTypeIdentifiers

/// Settings glass panel for advisory tachograph import and “Can I drive now?”.
struct TachoAdvisorySettingsSection: View {
    @Bindable var viewModel: RouteViewModel
    @State private var isImporterPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Tachograph (advisory)")
                .font(RFFont.sectionTitle)

            if let status = viewModel.canIDriveStatus {
                HStack(alignment: .top, spacing: RFSpacing.sm) {
                    Image(systemName: status.canDrive ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .foregroundStyle(status.canDrive ? RFColor.start : RFColor.hazard)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(status.canDrive ? "Can I drive now? Yes" : "Can I drive now? No")
                            .font(RFFont.summary)
                        Text(status.reason)
                            .font(RFFont.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                Text("Enable the advisory hours clock or import a card to evaluate drive eligibility.")
                    .font(RFFont.caption)
                    .foregroundStyle(.secondary)
            }

            if let summary = viewModel.tachoSummary {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Imported · \(summary.sourceFileName)")
                        .font(RFFont.caption.weight(.semibold))
                    if let card = summary.cardNumber {
                        Text("Card \(card)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(
                        "Continuous \(format(summary.remainingContinuousDriveSeconds)) · day \(format(summary.remainingDailyDriveSeconds)) · week \(format(summary.remainingWeeklyDriveSeconds))"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                Button("Clear imported card", role: .destructive) {
                    viewModel.clearImportedTachoSummary()
                }
                .buttonStyle(.borderless)
            }

            Button {
                isImporterPresented = true
            } label: {
                Label("Import JSON / DDD", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderless)

            if let error = viewModel.tachoImportError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(HosRestInsertionResult.legalDisclaimer)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(RFSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 14)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: Self.allowedImportTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await viewModel.importTachoFile(url: url) }
            case .failure(let error):
                viewModel.tachoImportError = error.localizedDescription
            }
        }
    }

    private static var allowedImportTypes: [UTType] {
        var types: [UTType] = [.json, .plainText, .data]
        if let ddd = UTType(filenameExtension: "ddd") {
            types.insert(ddd, at: 0)
        }
        return types
    }

    private func format(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
