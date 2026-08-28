import Foundation

/// Builds map hazard overlay GeoJSON from structured hazard events.
public enum HazardOverlayBuilder {
    /// Empty FeatureCollection used when no hazards are active.
    public static let emptyFeatureCollection =
        "{\"type\":\"FeatureCollection\",\"features\":[]}"

    /// Serializes hazards as a GeoJSON FeatureCollection for MapLibre overlays.
    public static func geoJSON(from hazards: [HazardEvent]) -> String {
        guard !hazards.isEmpty else { return emptyFeatureCollection }
        let features = hazards.map(featureJSON(for:))
        return "{\"type\":\"FeatureCollection\",\"features\":[\(features.joined(separator: ","))]}"
    }

    private static func featureJSON(for hazard: HazardEvent) -> String {
        let title = hazard.type.rawValue
        return """
        {"type":"Feature","properties":{"id":"\(hazard.id)","color":"#ef4444","title":"\(title)"},"geometry":{"type":"Point","coordinates":[\(hazard.longitude),\(hazard.latitude)]}}
        """
    }
}
