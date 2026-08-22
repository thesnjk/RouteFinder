import Contracts
import SwiftUI

/// Sheet for picking among multiple Nominatim matches (e.g. several "Topcroft" villages).
struct GeocodeDisambiguationSheet: View {
    let query: String
    let candidates: [GeocodeSuggestion]
    let onSelect: (GeocodeSuggestion) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RFSpacing.md) {
            Text("Which place did you mean?")
                .font(RFFont.sectionTitle)

            Text("Multiple matches for “\(query)”")
                .font(RFFont.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(candidates) { candidate in
                        Button {
                            onSelect(candidate)
                        } label: {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(candidate.title)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text(candidate.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if candidate.id != candidates.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .frame(maxHeight: 320)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .buttonStyle(.borderless)
            }
        }
        .padding(RFSpacing.lg)
        .frame(minWidth: 380)
    }
}
