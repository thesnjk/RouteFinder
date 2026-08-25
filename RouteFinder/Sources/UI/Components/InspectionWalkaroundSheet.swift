import Contracts
import SwiftUI

/// Glass DVSA-style walkaround checklist sheet.
struct InspectionChecklistView: View {
    @Bindable var viewModel: RouteViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RFSpacing.lg) {
                    if let record = viewModel.activeInspection {
                        header(for: record)
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.saveActiveInspection()
                            dismiss()
                        }
                    }
                    .disabled(viewModel.activeInspection == nil)
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

    private func checklist(for record: InspectionRecord) -> some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Checklist")
                .font(RFFont.sectionTitle)

            ForEach(Array(record.items.enumerated()), id: \.element.id) { index, item in
                VStack(alignment: .leading, spacing: RFSpacing.xs) {
                    Text(item.label)
                        .font(RFFont.summary)
                    Picker(
                        "Status",
                        selection: Binding(
                            get: { viewModel.activeInspection?.items[index].status ?? .notChecked },
                            set: { newValue in
                                guard viewModel.activeInspection != nil else { return }
                                viewModel.activeInspection?.items[index].status = newValue
                            }
                        )
                    ) {
                        ForEach(InspectionItemStatus.allCases, id: \.self) { status in
                            Text(statusLabel(status)).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.vertical, RFSpacing.xs)
            }
        }
        .padding(RFSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 14)
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
