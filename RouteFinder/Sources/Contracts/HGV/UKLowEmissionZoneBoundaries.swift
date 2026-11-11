import Foundation

/// Hand-authored / open-data-simplified UK LEZ / CAZ boundary rings for ORS `avoid_polygons`.
///
/// Rings are closed GeoJSON-style `[lon, lat]` envelopes — **not** legal cadastral boundaries.
/// Sheffield + Birmingham densified from OGL / OSM-published outlines (Douglas–Peucker ≈28 verts),
/// kept under HeiGIT ORS avoid-polygon area caps. London-wide ULEZ remains a coarse envelope
/// (full TfL polygon exceeds ORS ~200 km² avoid limit — announcement/`contains` only).
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

    /// Birmingham Clean Air Zone — densified Middleway (A4540) outline from published CAZ boundary
    /// (OSM Nominatim / council description: roads within the Middleway). OGL-compatible open outline;
    /// simplified to ~28 verts; area stays under ORS avoid soft cap.
    public static let birminghamCAZ: [[Double]] = closed([
        [-1.92649, 52.47859],
        [-1.92557, 52.47701],
        [-1.9213, 52.47451],
        [-1.91805, 52.4734],
        [-1.91754, 52.47264],
        [-1.91337, 52.47181],
        [-1.90438, 52.46805],
        [-1.89746, 52.46693],
        [-1.89398, 52.4654],
        [-1.88773, 52.46362],
        [-1.88641, 52.4639],
        [-1.88196, 52.46721],
        [-1.87785, 52.46952],
        [-1.87548, 52.47233],
        [-1.87513, 52.47486],
        [-1.87653, 52.47931],
        [-1.87778, 52.48112],
        [-1.88034, 52.48318],
        [-1.88752, 52.49153],
        [-1.8899, 52.49228],
        [-1.89497, 52.49215],
        [-1.90841, 52.49388],
        [-1.91467, 52.49238],
        [-1.91628, 52.49039],
        [-1.91745, 52.48723],
        [-1.91912, 52.48464],
        [-1.92247, 52.4828],
        [-1.92599, 52.47974],
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

    /// Sheffield Clean Air Zone — densified from Sheffield City Council open GeoJSON (UK OGL),
    /// Douglas–Peucker ≈30 verts; area ~2.4 km² (under ORS avoid soft cap).
    public static let sheffieldCAZ: [[Double]] = closed([
        [-1.44754, 53.38447],
        [-1.45413, 53.38541],
        [-1.45855, 53.38677],
        [-1.45821, 53.38766],
        [-1.46091, 53.38698],
        [-1.46105, 53.38827],
        [-1.46203, 53.38761],
        [-1.4636, 53.38908],
        [-1.46916, 53.38993],
        [-1.46833, 53.38915],
        [-1.4703, 53.38723],
        [-1.47456, 53.38753],
        [-1.47658, 53.38879],
        [-1.47987, 53.3874],
        [-1.48407, 53.38364],
        [-1.48341, 53.382],
        [-1.48433, 53.38169],
        [-1.48432, 53.37794],
        [-1.47981, 53.37432],
        [-1.47817, 53.37445],
        [-1.47877, 53.3737],
        [-1.47685, 53.37257],
        [-1.47315, 53.37365],
        [-1.46816, 53.3734],
        [-1.4627, 53.37454],
        [-1.46462, 53.37752],
        [-1.46052, 53.38216],
        [-1.45841, 53.38245],
        [-1.45871, 53.38385],
        [-1.45457, 53.38508],
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
