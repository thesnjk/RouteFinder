import Foundation

/// Builds straight-line dispatch map previews when ORS is unavailable.
public enum DispatchRoutePreviewBuilder: Sendable {
    /// Ordered coordinates from fleet trip stops.
    public static func straightLineCoordinates(from stops: [FleetTripStop]) -> [Coordinate] {
        stops
            .sorted { $0.sequence < $1.sequence }
            .map { Coordinate(latitude: $0.latitude, longitude: $0.longitude) }
    }

    /// Ordered coordinates from a dispatch draft with parseable lat/lon fields.
    public static func straightLineCoordinates(from draft: DispatchTripDraft) -> [Coordinate] {
        draft.stops.compactMap { stop in
            guard let lat = Double(stop.latitude.trimmingCharacters(in: .whitespaces)),
                  let lon = Double(stop.longitude.trimmingCharacters(in: .whitespaces)) else {
                return nil
            }
            return Coordinate(latitude: lat, longitude: lon)
        }
    }
}
