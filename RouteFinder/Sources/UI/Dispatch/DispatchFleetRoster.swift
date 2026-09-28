import Contracts
import Foundation

/// Pure helpers for Mac/iOS dispatch fleet roster (parity with web `fleetRoster.ts`).
public enum DispatchFleetRoster {
    /// Max vehicles polled on the desk roster (ICP 5–15 + headroom).
    public static let vehicleCap = 20

    /// Filter fleet vehicles by label or registration plate (case-insensitive).
    /// Empty / whitespace query returns all vehicles (parity with web `filterVehicles`).
    public static func filterVehicles(_ vehicles: [FleetVehicle], query: String) -> [FleetVehicle] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return vehicles }
        return vehicles.filter { vehicle in
            let label = vehicle.label.lowercased()
            let plate = (vehicle.registrationPlate ?? "").lowercased()
            return label.contains(q) || plate.contains(q)
        }
    }

    /// Seconds since `driverLocationRecordedAt`, or nil when GPS is absent.
    public static func gpsAgeSeconds(trip: FleetTrip?, now: Date) -> Int? {
        guard let trip,
              trip.driverLatitude != nil,
              trip.driverLongitude != nil,
              let recorded = trip.driverLocationRecordedAt else {
            return nil
        }
        return max(0, Int(now.timeIntervalSince(recorded).rounded()))
    }

    /// Build roster rows from vehicles + active-trip map. Preserves vehicle list order.
    public static func buildRows(
        vehicles: [FleetVehicle],
        tripByVehicleId: [UUID: FleetTrip?],
        now: Date
    ) -> [DispatchRosterRow] {
        vehicles.map { vehicle in
            let trip: FleetTrip? = {
                if let boxed = tripByVehicleId[vehicle.id] {
                    return boxed
                }
                return nil
            }()
            return DispatchRosterRow(
                vehicleId: vehicle.id,
                label: vehicle.label,
                plate: vehicle.registrationPlate,
                trip: trip,
                gpsAgeSeconds: gpsAgeSeconds(trip: trip, now: now),
                hasDefects: (trip?.latestInspectionSummary?.defectCount ?? 0) > 0
            )
        }
    }

    /// Driver GPS pins from roster rows that have a published location.
    public static func driverPins(from rows: [DispatchRosterRow]) -> [DispatchRosterPin] {
        var pins: [DispatchRosterPin] = []
        for row in rows {
            guard let lat = row.trip?.driverLatitude,
                  let lon = row.trip?.driverLongitude,
                  lat.isFinite,
                  lon.isFinite else {
                continue
            }
            pins.append(
                DispatchRosterPin(
                    vehicleId: row.vehicleId,
                    label: row.label,
                    latitude: lat,
                    longitude: lon
                )
            )
        }
        return pins
    }

    /// Formats physics ETA for roster cells.
    public static func formatPhysicsEta(seconds: TimeInterval?) -> String {
        guard let seconds, seconds.isFinite else { return "—" }
        return "\(Int((seconds / 60).rounded())) min"
    }

    /// Formats GPS age for roster cells.
    public static func formatGpsAge(_ ageSeconds: Int?) -> String {
        guard let ageSeconds else { return "—" }
        if ageSeconds < 60 { return "\(ageSeconds)s" }
        let mins = ageSeconds / 60
        if mins < 60 { return "\(mins)m" }
        return "\(mins / 60)h"
    }

    /// Status label for a roster row.
    public static func statusLabel(for row: DispatchRosterRow) -> String {
        row.trip?.status.rawValue ?? "idle"
    }
}

/// One row in the Mac dispatch fleet roster.
public struct DispatchRosterRow: Sendable, Equatable, Identifiable {
    public var id: UUID { vehicleId }
    public let vehicleId: UUID
    public let label: String
    public let plate: String?
    public let trip: FleetTrip?
    public let gpsAgeSeconds: Int?
    public let hasDefects: Bool

    public init(
        vehicleId: UUID,
        label: String,
        plate: String?,
        trip: FleetTrip?,
        gpsAgeSeconds: Int?,
        hasDefects: Bool
    ) {
        self.vehicleId = vehicleId
        self.label = label
        self.plate = plate
        self.trip = trip
        self.gpsAgeSeconds = gpsAgeSeconds
        self.hasDefects = hasDefects
    }
}

/// Yard map pin for a cab with published GPS.
public struct DispatchRosterPin: Sendable, Equatable, Identifiable {
    public var id: UUID { vehicleId }
    public let vehicleId: UUID
    public let label: String
    public let latitude: Double
    public let longitude: Double

    public init(vehicleId: UUID, label: String, latitude: Double, longitude: Double) {
        self.vehicleId = vehicleId
        self.label = label
        self.latitude = latitude
        self.longitude = longitude
    }
}
