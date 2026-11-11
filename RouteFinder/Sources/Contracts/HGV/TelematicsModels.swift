import Foundation

/// Telematics provider for read-only imports / ingest stubs.
public enum TelematicsProvider: String, Sendable, Codable, Hashable, CaseIterable {
    case geotab
    case samsara
    case unknown
}

/// A single read-only vehicle position from a partner export or webhook.
public struct TelematicsVehiclePing: Sendable, Hashable, Codable, Equatable, Identifiable {
    public var id: String { "\(vehicleLabel)-\(recordedAt.timeIntervalSince1970)" }
    public let provider: TelematicsProvider
    public let vehicleLabel: String
    public let latitude: Double
    public let longitude: Double
    public let recordedAt: Date
    public let speedKph: Double?

    public init(
        provider: TelematicsProvider,
        vehicleLabel: String,
        latitude: Double,
        longitude: Double,
        recordedAt: Date,
        speedKph: Double? = nil
    ) {
        self.provider = provider
        self.vehicleLabel = vehicleLabel
        self.latitude = latitude
        self.longitude = longitude
        self.recordedAt = recordedAt
        self.speedKph = speedKph
    }
}

/// Persisted batch from the last CSV import.
public struct TelematicsImportBatch: Sendable, Hashable, Codable, Equatable {
    public let importedAt: Date
    public let pings: [TelematicsVehiclePing]
    public let sourceFileName: String?

    public init(importedAt: Date = Date(), pings: [TelematicsVehiclePing], sourceFileName: String? = nil) {
        self.importedAt = importedAt
        self.pings = pings
        self.sourceFileName = sourceFileName
    }
}

/// Fleet server webhook body for telematics ingest (read-only stub).
public struct TelematicsIngestRequest: Sendable, Hashable, Codable, Equatable {
    public let vehicleId: UUID
    public let latitude: Double
    public let longitude: Double
    public let recordedAt: Date
    public let provider: String?
    public let vehicleLabel: String?

    public init(
        vehicleId: UUID,
        latitude: Double,
        longitude: Double,
        recordedAt: Date = Date(),
        provider: String? = nil,
        vehicleLabel: String? = nil
    ) {
        self.vehicleId = vehicleId
        self.latitude = latitude
        self.longitude = longitude
        self.recordedAt = recordedAt
        self.provider = provider
        self.vehicleLabel = vehicleLabel
    }
}

/// Offline graph download region presets for Settings UX.
public enum OfflineDownloadRegion: String, Sendable, Codable, CaseIterable, Identifiable {
    case demoNorfolk
    /// Mid-size East Anglia / A14–M11 band (Norwich–Cambridge–Ipswich pilots).
    case eastAnglia
    /// Mid-size Midlands / M1–M6 band (Birmingham–Leicester–Northampton–Coventry).
    case midlands
    case ukCorridor

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .demoNorfolk: return "Norfolk demo corridor"
        case .eastAnglia: return "East Anglia (A14–M11)"
        case .midlands: return "Midlands (M1–M6)"
        case .ukCorridor: return "UK mainland (large)"
        }
    }

    public var sizeWarning: String {
        switch self {
        case .demoNorfolk: return "Small — suitable for first install."
        case .eastAnglia: return "Medium — covers Norwich–Cambridge–Ipswich; larger than Norfolk demo, far smaller than UK mainland."
        case .midlands: return "Medium — covers Birmingham–Leicester–Northampton–Coventry (M1–M6); larger than East Anglia, far smaller than UK mainland."
        case .ukCorridor: return "Large download — prefer pre-placed *.graphjson when possible."
        }
    }

    public var boundingBox: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        switch self {
        case .demoNorfolk:
            return (minLat: 52.55, maxLat: 52.70, minLon: 1.20, maxLon: 1.40)
        case .eastAnglia:
            // Includes Norfolk demo bbox plus Cambridge / Ipswich approach (A14–M11 band).
            return (minLat: 51.70, maxLat: 52.90, minLon: 0.00, maxLon: 1.80)
        case .midlands:
            // Birmingham–Leicester–Nottingham–Northampton–Coventry approach (M1–M6 band).
            // Separate corridor from East Anglia (does not contain that bbox).
            return (minLat: 51.80, maxLat: 53.40, minLon: -2.80, maxLon: -0.40)
        case .ukCorridor:
            return (minLat: 49.8, maxLat: 58.7, minLon: -8.2, maxLon: 1.8)
        }
    }

    /// Approximate bbox area in square degrees (for tests / size honesty).
    public var approximateAreaSquareDegrees: Double {
        let box = boundingBox
        return max(0, box.maxLat - box.minLat) * max(0, box.maxLon - box.minLon)
    }

    /// Whether this region's bbox fully contains another region's bbox.
    public func contains(_ other: OfflineDownloadRegion) -> Bool {
        let a = boundingBox
        let b = other.boundingBox
        return a.minLat <= b.minLat
            && a.maxLat >= b.maxLat
            && a.minLon <= b.minLon
            && a.maxLon >= b.maxLon
    }
}

/// Provenance for structured lane guidance.
public enum LaneGuidanceSource: String, Sendable, Codable, Hashable {
    case osm
    case heuristic
    case unknown
}
