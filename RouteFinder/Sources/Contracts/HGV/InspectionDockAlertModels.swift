import Foundation

/// DVSA-style walkaround inspection checklist item status.
public enum InspectionItemStatus: String, Sendable, Hashable, Codable, CaseIterable {
    case notChecked
    case pass
    case defect
    case notApplicable
}

/// A single walkaround checklist item.
public struct InspectionChecklistItem: Sendable, Hashable, Codable, Equatable, Identifiable {
    public let id: String
    public let label: String
    public var status: InspectionItemStatus
    public var note: String?

    /// Creates a checklist item.
    public init(
        id: String = UUID().uuidString,
        label: String,
        status: InspectionItemStatus = .notChecked,
        note: String? = nil
    ) {
        self.id = id
        self.label = label
        self.status = status
        self.note = note
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

    /// Default DVSA-style walkaround checklist labels.
    public static func defaultDVSAItems() -> [InspectionChecklistItem] {
        [
            "Lights / indicators",
            "Tyres / wheels / nuts",
            "Brakes",
            "Windscreen / wipers",
            "Mirrors",
            "Body / security / load",
            "Fuel / AdBlue / leaks",
            "Number plates",
            "Tachograph / speed limiter",
            "Seat belts / cab",
        ].map { InspectionChecklistItem(label: $0) }
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
