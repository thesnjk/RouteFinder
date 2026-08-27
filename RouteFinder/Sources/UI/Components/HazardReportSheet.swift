import Contracts
import SwiftUI

/// Waze-style sheet for submitting a local crowd hazard report.
public struct HazardReportSheet: View {
    @Bindable var viewModel: RouteViewModel
    @State private var selectedType: HazardEventType = .traffic
    @State private var note: String = ""
    @Environment(\.dismiss) private var dismiss

    /// Reportable hazard kinds shown in the sheet (excludes internal crowd markers).
    private static let reportableTypes: [HazardEventType] = [
        .closure,
        .traffic,
        .camera,
        .weather,
        .other,
    ]

    /// Creates a hazard report sheet bound to the route view model.
    public init(viewModel: RouteViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: RFSpacing.md) {
                Text("What are you reporting?")
                    .font(RFFont.sectionTitle)
                    .vibrancyLabel()

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: RFSpacing.sm
                ) {
                    ForEach(Self.reportableTypes, id: \.self) { type in
                        Button {
                            selectedType = type
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: symbol(for: type))
                                    .font(.title3)
                                Text(label(for: type))
                                    .font(RFFont.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, RFSpacing.sm)
                            .foregroundStyle(selectedType == type ? Color.accentColor : .primary)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedType == type ? Color.accentColor.opacity(0.15) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        selectedType == type ? Color.accentColor.opacity(0.5) : Color.white.opacity(0.15),
                                        lineWidth: 0.5
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                TextField("Optional note", text: $note, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(GlassTextFieldStyle())

                Spacer(minLength: 0)

                HStack {
                    Button("Cancel") {
                        viewModel.presentHazardReportSheet = false
                        dismiss()
                    }
                    .modifier(GlassButton())

                    Spacer()

                    Button("Submit") {
                        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        viewModel.submitCrowdHazardReport(
                            type: selectedType,
                            note: trimmed.isEmpty ? nil : trimmed
                        )
                        dismiss()
                    }
                    .modifier(GlassButton())
                }
            }
            .padding(RFSpacing.lg)
            .controlSheetStyle()
            .padding(RFSpacing.md)
            .navigationTitle("Report Hazard")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .presentationDetents([.medium])
    }

    private func label(for type: HazardEventType) -> String {
        switch type {
        case .closure: return "Closure"
        case .traffic: return "Traffic"
        case .camera: return "Camera"
        case .weather: return "Weather"
        case .crowdReport: return "Crowd"
        case .laybyFull: return "Layby full"
        case .laybySpaces: return "Layby spaces"
        case .other: return "Other"
        }
    }

    private func symbol(for type: HazardEventType) -> String {
        switch type {
        case .closure: return "road.lanes"
        case .traffic: return "car.2.fill"
        case .camera: return "camera.fill"
        case .weather: return "cloud.rain.fill"
        case .crowdReport: return "person.3.fill"
        case .laybyFull: return "parkingsign.circle.fill"
        case .laybySpaces: return "parkingsign"
        case .other: return "exclamationmark.triangle.fill"
        }
    }
}
