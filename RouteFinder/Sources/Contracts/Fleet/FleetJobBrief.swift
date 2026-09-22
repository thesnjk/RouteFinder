import Foundation

/// Optional time window for a stop on a dispatched fleet job.
public struct StopTimeWindow: Sendable, Hashable, Codable, Equatable {
    /// Stop id this window applies to (matches ``FleetTripStop/id``).
    public let stopId: UUID
    /// Earliest acceptable arrival (UTC).
    public var earliestArrival: Date?
    /// Latest acceptable arrival (UTC).
    public var latestArrival: Date?

    /// Creates a stop time window.
    public init(
        stopId: UUID,
        earliestArrival: Date? = nil,
        latestArrival: Date? = nil
    ) {
        self.stopId = stopId
        self.earliestArrival = earliestArrival
        self.latestArrival = latestArrival
    }
}

/// Dispatch-authored job metadata carried on ``FleetTrip`` (optional fields for wire compatibility).
public struct FleetJobBrief: Sendable, Hashable, Codable, Equatable {
    /// Gross vehicle / load weight in kilograms when known.
    public var grossWeightKg: Double?
    /// ADR / hazmat class label (e.g. `"3"`, `"2.1"`) when applicable.
    public var adrClass: String?
    /// Per-stop time windows (planning aid).
    public var timeWindows: [StopTimeWindow]
    /// Preferred vehicle profile id when the desk selected a named profile.
    public var requestedVehicleProfileId: UUID?
    /// When true, driver clients should auto-run Find route after applying stops.
    public var autoFindRoute: Bool
    /// When true, driver clients may auto-run Rehearse after a successful route find.
    public var autoRehearse: Bool

    /// Empty brief with fleet-pilot defaults (auto-find on, auto-rehearse off).
    public static let fleetPilotDefault = FleetJobBrief(
        grossWeightKg: nil,
        adrClass: nil,
        timeWindows: [],
        requestedVehicleProfileId: nil,
        autoFindRoute: true,
        autoRehearse: false
    )

    /// Creates a job brief.
    public init(
        grossWeightKg: Double? = nil,
        adrClass: String? = nil,
        timeWindows: [StopTimeWindow] = [],
        requestedVehicleProfileId: UUID? = nil,
        autoFindRoute: Bool = true,
        autoRehearse: Bool = false
    ) {
        self.grossWeightKg = grossWeightKg
        self.adrClass = adrClass
        self.timeWindows = timeWindows
        self.requestedVehicleProfileId = requestedVehicleProfileId
        self.autoFindRoute = autoFindRoute
        self.autoRehearse = autoRehearse
    }

    /// Merges weight (and ADR when mappable) into a vehicle profile.
    public func applyingWeight(to profile: VehicleProfile?) -> VehicleProfile? {
        let tonnes: Double? = {
            guard let kg = grossWeightKg, kg > 0 else { return nil }
            return kg / 1_000
        }()
        let hazmat = Self.hazmatClass(fromADR: adrClass)
        guard tonnes != nil || hazmat != nil else { return profile }

        let base = profile ?? VehicleProfile(
            height: 4.0,
            weight: tonnes ?? 44,
            width: 2.55,
            length: 16.5,
            axleWeight: 11.5
        )
        return VehicleProfile(
            height: base.height,
            weight: tonnes ?? base.weight,
            width: base.width,
            length: base.length,
            axleWeight: base.axleWeight,
            groundClearance: base.groundClearance,
            turningRadius: base.turningRadius,
            hazmatClass: hazmat ?? base.hazmatClass,
            tunnelRestrictionCode: base.tunnelRestrictionCode,
            emissionClass: base.emissionClass,
            savedProfileName: base.savedProfileName
        )
    }

    /// Best-effort ADR string → ``HazmatClass``.
    public static func hazmatClass(fromADR raw: String?) -> HazmatClass? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        let key = trimmed.lowercased().replacingOccurrences(of: " ", with: "")
        if let exact = HazmatClass(rawValue: key) { return exact }
        if key.hasPrefix("class"), let exact = HazmatClass(rawValue: key) { return exact }
        let digit = key.filter(\.isNumber).prefix(1)
        switch digit {
        case "1": return .class1
        case "2": return .class2
        case "3": return .class3
        case "4": return .class4
        case "5": return .class5
        case "6": return .class6
        case "7": return .class7
        case "8": return .class8
        case "9": return .class9
        default: return nil
        }
    }
}

/// Policy knobs for applying a pushed fleet trip onto the driver navigation model.
public struct JobIntakePolicy: Sendable, Hashable, Codable, Equatable {
    /// Prefer brief.autoFindRoute when present; otherwise this default.
    public var defaultAutoFindRoute: Bool
    /// Prefer brief.autoRehearse when present; otherwise this default.
    public var defaultAutoRehearse: Bool

    /// Fleet-pilot defaults: auto-find on, auto-rehearse off.
    public static let fleetPilot = JobIntakePolicy(defaultAutoFindRoute: true, defaultAutoRehearse: false)

    /// Creates an intake policy.
    public init(defaultAutoFindRoute: Bool = true, defaultAutoRehearse: Bool = false) {
        self.defaultAutoFindRoute = defaultAutoFindRoute
        self.defaultAutoRehearse = defaultAutoRehearse
    }

    /// Resolves find-route flag from optional brief.
    public func shouldAutoFindRoute(brief: FleetJobBrief?) -> Bool {
        brief?.autoFindRoute ?? defaultAutoFindRoute
    }

    /// Resolves rehearse flag from optional brief.
    public func shouldAutoRehearse(brief: FleetJobBrief?) -> Bool {
        brief?.autoRehearse ?? defaultAutoRehearse
    }
}

/// Pure helpers that map a ``FleetTrip`` into driver waypoints and profile without UI.
public enum JobIntakeMapper: Sendable {
    /// Ordered stops from a trip.
    public static func orderedStops(from trip: FleetTrip) -> [FleetTripStop] {
        trip.stops.sorted { $0.sequence < $1.sequence }
    }

    /// Effective vehicle profile after applying ``FleetJobBrief`` weight.
    public static func effectiveProfile(from trip: FleetTrip) -> VehicleProfile? {
        let brief = trip.jobBrief ?? .fleetPilotDefault
        return brief.applyingWeight(to: trip.vehicleProfile)
    }

    /// True when intake should attempt RegCheck because dimensions are missing.
    public static func needsRegistrationLookup(from trip: FleetTrip) -> Bool {
        guard let profile = effectiveProfile(from: trip) else { return true }
        return profile.height == nil
            && profile.weight == nil
            && profile.width == nil
            && profile.length == nil
    }
}

/// Host surface for applying a dispatched trip onto the active navigation session.
@MainActor
public protocol JobIntakeHandling: AnyObject {
    /// Applies stops, profile, and optional auto find/rehearse for a pushed fleet trip.
    func applyJobIntake(trip: FleetTrip, policy: JobIntakePolicy) async
}
