import Foundation

/// DVSA-style walkaround inspection checklist item status.
public enum InspectionItemStatus: String, Sendable, Hashable, Codable, CaseIterable {
    case notChecked
    case pass
    case defect
    case notApplicable
}

/// Vehicle area grouping for a DVSA daily walkaround checklist.
public enum InspectionZone: String, Sendable, Hashable, Codable, CaseIterable {
    case cabMirrors
    case lights
    case coupling
    case tractorExterior
    case trailer
    case fluidsLeaks
    case brakesTacho

    /// Driver-facing section title.
    public var displayTitle: String {
        switch self {
        case .cabMirrors: return "Cab and mirrors"
        case .lights: return "Lights and markers"
        case .coupling: return "Coupling and connections"
        case .tractorExterior: return "Tractor exterior"
        case .trailer: return "Trailer"
        case .fluidsLeaks: return "Fluids and leaks"
        case .brakesTacho: return "Brakes and tacho"
        }
    }
}

/// A single walkaround checklist item.
public struct InspectionChecklistItem: Sendable, Hashable, Codable, Equatable, Identifiable {
    public let id: String
    public let zone: InspectionZone
    public let label: String
    public var status: InspectionItemStatus
    public var note: String?
    /// Optional JPEG photo evidence as base64 (size-capped before encode).
    public var photoJPEGBase64: [String]

    /// Creates a checklist item.
    public init(
        id: String = UUID().uuidString,
        zone: InspectionZone,
        label: String,
        status: InspectionItemStatus = .notChecked,
        note: String? = nil,
        photoJPEGBase64: [String] = []
    ) {
        self.id = id
        self.zone = zone
        self.label = label
        self.status = status
        self.note = note
        self.photoJPEGBase64 = photoJPEGBase64
    }

    enum CodingKeys: String, CodingKey {
        case id, zone, label, status, note, photoJPEGBase64
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        zone = try container.decodeIfPresent(InspectionZone.self, forKey: .zone) ?? .cabMirrors
        label = try container.decode(String.self, forKey: .label)
        status = try container.decode(InspectionItemStatus.self, forKey: .status)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        photoJPEGBase64 = try container.decodeIfPresent([String].self, forKey: .photoJPEGBase64) ?? []
    }
}

/// Caps walkaround photo / PDF payloads for fleet snapshot upload.
public enum InspectionMediaBudget: Sendable {
    /// Max JPEG bytes per photo after compression.
    public static let maxPhotoBytes = 120_000
    /// Max photos per checklist item.
    public static let maxPhotosPerItem = 2
    /// Max base64 PDF characters on a fleet trip snapshot.
    public static let maxPDFBase64Characters = 900_000

    /// Truncates raw JPEG bytes when over budget (prefer compressing in UI before encode).
    public static func cappedJPEG(_ data: Data) -> Data {
        guard data.count > maxPhotoBytes else { return data }
        return Data(data.prefix(maxPhotoBytes))
    }

    /// Encodes a JPEG into a base64 string after size capping.
    public static func encodePhoto(_ data: Data) -> String {
        cappedJPEG(data).base64EncodedString()
    }

    /// Truncates a PDF base64 payload for fleet upload when over budget.
    public static func cappedPDFBase64(_ base64: String) -> String? {
        guard !base64.isEmpty else { return nil }
        if base64.count <= maxPDFBase64Characters { return base64 }
        return String(base64.prefix(maxPDFBase64Characters))
    }
}

/// A completed or in-progress vehicle inspection record.
public struct InspectionRecord: Sendable, Hashable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let vehicleLabel: String
    public let registrationPlate: String?
    public let createdAt: Date
    public var completedAt: Date?
    public var items: [InspectionChecklistItem]
    public var syncPending: Bool

    /// Creates an inspection record.
    public init(
        id: UUID = UUID(),
        vehicleLabel: String,
        registrationPlate: String? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        items: [InspectionChecklistItem] = InspectionRecord.defaultDVSAItems(),
        syncPending: Bool = false
    ) {
        self.id = id
        self.vehicleLabel = vehicleLabel
        self.registrationPlate = registrationPlate
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.items = items
        self.syncPending = syncPending
    }

    /// Fraction of checklist items that are no longer `notChecked`.
    public var completionFraction: Double {
        guard !items.isEmpty else { return 0 }
        let resolved = items.filter { $0.status != .notChecked }.count
        return Double(resolved) / Double(items.count)
    }

    /// Whether every item has been marked pass, defect, or N/A.
    public var isReadyToSave: Bool {
        !items.isEmpty && items.allSatisfy { $0.status != .notChecked }
    }

    /// Count of items marked defect.
    public var defectCount: Int {
        items.filter { $0.status == .defect }.count
    }

    /// Items grouped by zone in checklist order.
    public func itemsGroupedByZone() -> [(zone: InspectionZone, items: [InspectionChecklistItem])] {
        InspectionZone.allCases.compactMap { zone in
            let grouped = items.filter { $0.zone == zone }
            guard !grouped.isEmpty else { return nil }
            return (zone, grouped)
        }
    }

    /// Default DVSA-style walkaround checklist grouped by vehicle area.
    public static func defaultDVSAItems() -> [InspectionChecklistItem] {
        [
            (.cabMirrors, "Windscreen and washers"),
            (.cabMirrors, "Wipers and washers operate"),
            (.cabMirrors, "Mirrors — condition and adjustment"),
            (.cabMirrors, "Seat belts and cab security"),
            (.lights, "Headlights and sidelights"),
            (.lights, "Indicators and hazard warning"),
            (.lights, "Brake lights and markers"),
            (.coupling, "Fifth wheel / coupling security"),
            (.coupling, "Air lines and electrics"),
            (.coupling, "Kingpin / trailer coupling condition"),
            (.tractorExterior, "Tyres — tread, cuts, inflation"),
            (.tractorExterior, "Wheels and wheel nuts"),
            (.tractorExterior, "Bodywork and load security"),
            (.tractorExterior, "Number plates legible"),
            (.trailer, "Trailer tyres and wheels"),
            (.trailer, "Trailer doors, curtains, and seals"),
            (.trailer, "Trailer load security and strapping"),
            (.trailer, "Trailer number plate"),
            (.fluidsLeaks, "Fuel cap and fuel leaks"),
            (.fluidsLeaks, "AdBlue level and leaks"),
            (.fluidsLeaks, "Oil / coolant leaks under vehicle"),
            (.brakesTacho, "Brake lines and audible leaks"),
            (.brakesTacho, "Parking brake holds"),
            (.brakesTacho, "Tachograph and speed limiter"),
        ].map { zone, label in
            InspectionChecklistItem(zone: zone, label: label)
        }
    }
}

/// Last-metre dock / gate snap target for terminal approach.
public struct DockSnapTarget: Sendable, Hashable, Codable, Equatable {
    public let requestedNodeId: String
    public let snappedNodeId: String
    public let latitude: Double
    public let longitude: Double
    public let label: String
    public let gateHint: String?

    /// Creates a dock snap target.
    public init(
        requestedNodeId: String,
        snappedNodeId: String,
        latitude: Double,
        longitude: Double,
        label: String,
        gateHint: String? = nil
    ) {
        self.requestedNodeId = requestedNodeId
        self.snappedNodeId = snappedNodeId
        self.latitude = latitude
        self.longitude = longitude
        self.label = label
        self.gateHint = gateHint
    }
}

/// Driver-facing alert published on the alert bus.
public struct DriverAlert: Sendable, Hashable, Codable, Equatable, Identifiable {
    public enum Kind: String, Sendable, Hashable, Codable {
        case hos
        case kinetic
        case restriction
        case traffic
        case parking
        case inspection
        case general
    }

    public let id: String
    public let kind: Kind
    public let title: String
    public let message: String
    public let createdAt: Date
    public let speakable: Bool

    /// Creates a driver alert.
    public init(
        id: String = UUID().uuidString,
        kind: Kind,
        title: String,
        message: String,
        createdAt: Date = Date(),
        speakable: Bool = true
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.message = message
        self.createdAt = createdAt
        self.speakable = speakable
    }
}
