import Contracts
import SwiftUI

/// Glass DVSA-style walkaround checklist sheet.
struct InspectionChecklistView: View {
    @Bindable var viewModel: RouteViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var sharePDFData: Data?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RFSpacing.lg) {
                    if let record = viewModel.activeInspection {
                        header(for: record)
                        completionBar(for: record)
                        checklist(for: record)
                        Text("Defects must also be recorded in the operator’s official defect system. This checklist is a local planning aid.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No active inspection.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(RFSpacing.lg)
            }
            .navigationTitle("Walkaround")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    if let record = viewModel.activeInspection, record.isReadyToSave {
                        ShareLink(
                            item: InspectionReportPDFRenderer.pdfData(from: record),
                            preview: SharePreview("Walkaround report", icon: Image(systemName: "doc.richtext"))
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    Button("Save") {
                        Task {
                            await viewModel.saveActiveInspection()
                            if let record = viewModel.activeInspection {
                                sharePDFData = InspectionReportPDFRenderer.pdfData(from: record)
                            }
                            dismiss()
                        }
                    }
                    .disabled(viewModel.activeInspection?.isReadyToSave != true)
                }
            }
        }
        .onAppear {
            if viewModel.activeInspection == nil {
                viewModel.startWalkaroundInspection()
            }
        }
    }

    private func header(for record: InspectionRecord) -> some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text(record.vehicleLabel)
                .font(RFFont.sectionTitle)
            if let plate = record.registrationPlate {
                Text(plate)
                    .font(RFFont.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Started \(record.createdAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(RFSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 14)
    }

    private func completionBar(for record: InspectionRecord) -> some View {
        VStack(alignment: .leading, spacing: RFSpacing.xs) {
            HStack {
                Text("Completion")
                    .font(RFFont.sectionTitle)
                Spacer()
                Text("\(Int(record.completionFraction * 100))%")
                    .font(RFFont.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: record.completionFraction)
            if record.defectCount > 0 {
                Text("\(record.defectCount) defect(s) recorded")
                    .font(RFFont.caption)
                    .foregroundStyle(RFColor.hazard)
            }
        }
        .padding(RFSpacing.md)
        .glassPanel(cornerRadius: 14)
    }

    private func checklist(for record: InspectionRecord) -> some View {
        VStack(alignment: .leading, spacing: RFSpacing.lg) {
            ForEach(record.itemsGroupedByZone(), id: \.zone) { group in
                VStack(alignment: .leading, spacing: RFSpacing.sm) {
                    Text(group.zone.displayTitle)
                        .font(RFFont.sectionTitle)

                    ForEach(group.items) { item in
                        checklistRow(item: item)
                    }
                }
                .padding(RFSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassPanel(cornerRadius: 14)
            }
        }
    }

    private func checklistRow(item: InspectionChecklistItem) -> some View {
        VStack(alignment: .leading, spacing: RFSpacing.xs) {
            Text(item.label)
                .font(RFFont.summary)
            Picker(
                "Status",
                selection: binding(for: item.id, keyPath: \.status)
            ) {
                ForEach(InspectionItemStatus.allCases, id: \.self) { status in
                    Text(statusLabel(status)).tag(status)
                }
            }
            .pickerStyle(.segmented)

            if binding(for: item.id, keyPath: \.status).wrappedValue == .defect {
                TextField("Defect note", text: noteBinding(for: item.id), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }
        }
        .padding(.vertical, RFSpacing.xs)
    }

    private func binding(for itemID: String, keyPath: WritableKeyPath<InspectionChecklistItem, InspectionItemStatus>) -> Binding<InspectionItemStatus> {
        Binding(
            get: {
                viewModel.activeInspection?.items.first(where: { $0.id == itemID })?[keyPath: keyPath] ?? .notChecked
            },
            set: { newValue in
                guard let index = viewModel.activeInspection?.items.firstIndex(where: { $0.id == itemID }) else { return }
                viewModel.activeInspection?.items[index][keyPath: keyPath] = newValue
            }
        )
    }

    private func noteBinding(for itemID: String) -> Binding<String> {
        Binding(
            get: {
                viewModel.activeInspection?.items.first(where: { $0.id == itemID })?.note ?? ""
            },
            set: { newValue in
                guard let index = viewModel.activeInspection?.items.firstIndex(where: { $0.id == itemID }) else { return }
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                viewModel.activeInspection?.items[index].note = trimmed.isEmpty ? nil : trimmed
            }
        )
    }

    private func statusLabel(_ status: InspectionItemStatus) -> String {
        switch status {
        case .notChecked: return "—"
        case .pass: return "Pass"
        case .defect: return "Defect"
        case .notApplicable: return "N/A"
        }
    }
}

/// Compatibility alias for the walkaround checklist sheet.
typealias InspectionWalkaroundSheet = InspectionChecklistView

#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers

extension Data: @retroactive Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { data in
            data
        }
    }
}
#endif
