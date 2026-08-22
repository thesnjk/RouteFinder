import SwiftUI

/// Persistent OSM / Nominatim attribution overlay for the map canvas.
public struct MapAttributionOverlay: View {
    public init() {}

    public var body: some View {
        HStack(spacing: 8) {
            Link("© OSM", destination: MapLibreConfiguration.osmCopyrightURL)
            Text("·")
            Link("Nominatim", destination: MapLibreConfiguration.nominatimPolicyURL)
            Text("· OpenFreeMap")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
    }
}
