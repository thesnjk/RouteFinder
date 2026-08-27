import Foundation

/// Hand-authored simplified UK LEZ / CAZ boundary rings for ORS `avoid_polygons`.
///
/// Rings are closed GeoJSON-style `[lon, lat]` envelopes — **not** legal cadastral boundaries.
/// They improve on circular approximations while staying static and $0.
public enum UKLowEmissionZoneBoundaries: Sendable {
    /// Closed rings keyed by catalog zone id.
    public static let ringsByZoneId: [String: [[Double]]] = [
        "london-ulez": londonULEZ,
        "birmingham-caz": birminghamCAZ,
        "bristol-caz": bristolCAZ,
        "sheffield-caz": sheffieldCAZ,
        "bath-caz": bathCAZ,
        "newcastle-caz": newcastleCAZ,
    ]

    /// Greater London ULEZ (expanded) — coarse envelope inside North/South Circular area.
    public static let londonULEZ: [[Double]] = closed([
        [-0.50, 51.48],
        [-0.42, 51.58],
        [-0.25, 51.65],
        [-0.05, 51.67],
        [0.12, 51.62],
        [0.22, 51.52],
        [0.18, 51.42],
        [0.05, 51.35],
        [-0.15, 51.32],
        [-0.35, 51.35],
        [-0.48, 51.42],
    ])

    /// Birmingham Clean Air Zone — city-centre / Ring Road envelope.
    public static let birminghamCAZ: [[Double]] = closed([
        [-1.93, 52.470],
        [-1.88, 52.470],
        [-1.86, 52.482],
        [-1.86, 52.498],
        [-1.88, 52.505],
        [-1.93, 52.505],
        [-1.95, 52.492],
        [-1.95, 52.478],
    ])

    /// Bristol Clean Air Zone — central / inner-city envelope.
    public static let bristolCAZ: [[Double]] = closed([
        [-2.62, 51.440],
        [-2.56, 51.440],
        [-2.54, 51.452],
        [-2.54, 51.468],
        [-2.56, 51.475],
        [-2.62, 51.475],
        [-2.64, 51.462],
        [-2.64, 51.448],
    ])

    /// Sheffield Clean Air Zone — inner urban envelope.
    public static let sheffieldCAZ: [[Double]] = closed([
        [-1.51, 53.365],
        [-1.44, 53.365],
        [-1.42, 53.378],
        [-1.42, 53.395],
        [-1.44, 53.402],
        [-1.51, 53.402],
        [-1.53, 53.390],
        [-1.53, 53.372],
    ])

    /// Bath Clean Air Zone — compact city-centre envelope.
    public static let bathCAZ: [[Double]] = closed([
        [-2.385, 51.372],
        [-2.340, 51.372],
        [-2.330, 51.380],
        [-2.330, 51.392],
        [-2.340, 51.398],
        [-2.385, 51.398],
        [-2.395, 51.390],
        [-2.395, 51.378],
    ])

    /// Newcastle Clean Air Zone — city-centre / Quayside envelope.
    public static let newcastleCAZ: [[Double]] = closed([
        [-1.650, 54.965],
        [-1.590, 54.965],
        [-1.575, 54.975],
        [-1.575, 54.990],
        [-1.590, 54.998],
        [-1.650, 54.998],
        [-1.665, 54.988],
        [-1.665, 54.972],
    ])

    private static func closed(_ points: [[Double]]) -> [[Double]] {
        guard let first = points.first else { return points }
        if points.last == first { return points }
        return points + [first]
    }
}
