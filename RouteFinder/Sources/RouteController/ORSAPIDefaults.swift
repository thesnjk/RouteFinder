import Foundation

/// Shared constants for HeiGIT OpenRouteService v2 API endpoints.
public enum ORSAPIDefaults {
    /// Base URL for OpenRouteService v2 on HeiGIT infrastructure.
    public static let baseURL = "https://api.heigit.org/openrouteservice/v2"
    /// Base URL for Pelias v1 geocoding on HeiGIT infrastructure.
    public static let peliasBaseURL = "https://api.heigit.org/pelias/v1"
    /// Pelias geocode search path segment.
    public static let geocodeSearchPath = "search"
    /// HGV directions GeoJSON path segment.
    public static let hgvDirectionsPath = "directions/driving-hgv/geojson"
    /// Passenger car directions GeoJSON path segment.
    public static let carDirectionsPath = "directions/driving-car/geojson"
    /// Vroom optimization path segment.
    public static let optimizationPath = "optimization"
    /// HGV matrix path segment.
    public static let hgvMatrixPath = "matrix/driving-hgv"
    /// Passenger car matrix path segment.
    public static let carMatrixPath = "matrix/driving-car"
    /// User-Agent sent with routing requests.
    public static let userAgent = "RouteFinderLogisticsApp/1.0"
    /// HeiGIT hosted ORS does not support the `extra_info` request option.
    public static let supportsExtraInfo = false
}
