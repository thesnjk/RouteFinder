import Foundation

/// Camera animation command for the MapLibre navigation viewport.
public struct MapCameraCommand: Sendable, Equatable {
    /// Longitude of the map center.
    public let longitude: Double
    /// Latitude of the map center.
    public let latitude: Double
    /// Optional zoom level.
    public let zoom: Double?
    /// Optional bearing in degrees clockwise from north.
    public let bearing: Double?
    /// Optional pitch in degrees.
    public let pitch: Double?
    /// Animation duration in milliseconds.
    public let durationMs: Int

    /// Creates a map camera command.
    public init(
        longitude: Double,
        latitude: Double,
        zoom: Double? = nil,
        bearing: Double? = nil,
        pitch: Double? = nil,
        durationMs: Int = 33
    ) {
        self.longitude = longitude
        self.latitude = latitude
        self.zoom = zoom
        self.bearing = bearing
        self.pitch = pitch
        self.durationMs = durationMs
    }
}
