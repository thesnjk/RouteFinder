import Foundation

/// Builds validated fleet trips for dispatch push.
public enum FleetTripBuilder: Sendable {
    /// Assigns origin/via/destination roles and sequence indices to ordered stops.
    public static func normalizedStops(_ stops: [FleetTripStop]) throws -> [FleetTripStop] {
        guard stops.count >= 2 else {
            throw FleetStoreError.invalidTrip("At least two stops are required.")
        }
        return stops.enumerated().map { index, stop in
            let role: FleetTripStop.Role = switch index {
            case 0: .origin
            case stops.count - 1: .destination
            default: .via
            }
            return FleetTripStop(
                id: stop.id,
                sequence: index,
                label: stop.label,
                latitude: stop.latitude,
                longitude: stop.longitude,
                role: role
            )
        }
    }

    /// Creates a trip ready for `pushTrip`.
    public static func makeTrip(
        orgId: UUID,
        vehicleId: UUID,
        stops: [FleetTripStop],
        companyBreaks: [CompanyBreakAllocation] = [],
        vehicleProfile: VehicleProfile? = nil,
        jobBrief: FleetJobBrief? = nil
    ) throws -> FleetTrip {
        FleetTrip(
            orgId: orgId,
            vehicleId: vehicleId,
            stops: try normalizedStops(stops),
            vehicleProfile: vehicleProfile,
            jobBrief: jobBrief,
            companyBreaks: companyBreaks
        )
    }
}
