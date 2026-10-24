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
        "manchester-caz": manchesterCAZ,
        "glasgow-lez": glasgowLEZ,
        "bradford-caz": bradfordCAZ,
        "oxford-zez": oxfordZEZ,
        "portsmouth-caz": portsmouthCAZ,
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

    /// Greater Manchester CAZ — city-centre / inner ring envelope (not full GMCA).
    public static let manchesterCAZ: [[Double]] = closed([
        [-2.300, 53.460],
        [-2.200, 53.460],
        [-2.180, 53.470],
        [-2.180, 53.495],
        [-2.200, 53.505],
        [-2.300, 53.505],
        [-2.320, 53.492],
        [-2.320, 53.472],
    ])

    /// Glasgow LEZ — city-centre / M8 / river envelope.
    public static let glasgowLEZ: [[Double]] = closed([
        [-4.300, 55.845],
        [-4.200, 55.845],
        [-4.180, 55.855],
        [-4.180, 55.878],
        [-4.200, 55.888],
        [-4.300, 55.888],
        [-4.320, 55.875],
        [-4.320, 55.855],
    ])

    /// Bradford CAZ — city-centre envelope.
    public static let bradfordCAZ: [[Double]] = closed([
        [-1.800, 53.780],
        [-1.720, 53.780],
        [-1.700, 53.790],
        [-1.700, 53.812],
        [-1.720, 53.822],
        [-1.800, 53.822],
        [-1.820, 53.810],
        [-1.820, 53.790],
    ])

    /// Oxford Zero Emission Zone — compact historic centre envelope.
    public static let oxfordZEZ: [[Double]] = closed([
        [-1.280, 51.740],
        [-1.235, 51.740],
        [-1.225, 51.748],
        [-1.225, 51.760],
        [-1.235, 51.768],
        [-1.280, 51.768],
        [-1.290, 51.760],
        [-1.290, 51.748],
    ])

    /// Portsmouth CAZ — city-centre / harbour approaches envelope.
    public static let portsmouthCAZ: [[Double]] = closed([
        [-1.120, 50.800],
        [-1.050, 50.800],
        [-1.040, 50.810],
        [-1.040, 50.832],
        [-1.050, 50.842],
        [-1.120, 50.842],
        [-1.130, 50.830],
        [-1.130, 50.810],
    ])

    private static func closed(_ points: [[Double]]) -> [[Double]] {
        guard let first = points.first else { return points }
        if points.last == first { return points }
        return points + [first]
    }
}
