import Contracts
import CoreLocation
import DataLayer
import Foundation

/// Vehicle-adjusted TomTom Traffic Flow snapshot for a route segment.
public struct TrafficCongestionSnapshot: Sendable, Hashable {
    /// Raw TomTom flow segment data.
    public let rawFlow: TomTomFlowSegmentData
    /// Vehicle-adjusted free-flow speed in km/h.
    public let effectiveFreeFlowSpeedKmh: Double
    /// Vehicle-adjusted current speed in km/h.
    public let effectiveCurrentSpeedKmh: Double
    /// Congestion classification after vehicle ceiling application.
    public let congestionLevel: TrafficCongestionLevel
    /// Velocity multiplier applied to target speed.
    public let velocityMultiplier: Double

    /// Creates a traffic congestion snapshot.
    public init(
        rawFlow: TomTomFlowSegmentData,
        effectiveFreeFlowSpeedKmh: Double,
        effectiveCurrentSpeedKmh: Double,
        congestionLevel: TrafficCongestionLevel,
        velocityMultiplier: Double
    ) {
        self.rawFlow = rawFlow
        self.effectiveFreeFlowSpeedKmh = effectiveFreeFlowSpeedKmh
        self.effectiveCurrentSpeedKmh = effectiveCurrentSpeedKmh
        self.congestionLevel = congestionLevel
        self.velocityMultiplier = velocityMultiplier
    }
}

/// Vehicle-aware TomTom Traffic Flow integration layer.
public actor TomTomTrafficFlowIntegration {
    private let client: TomTomTrafficFlowClient?
    private var vehicleProfile: VehicleSpecificationProfile
    private var measurementSystem: RegionalMeasurementSystem

    /// Creates a TomTom traffic flow integration layer.
    public init(
        apiKey: String?,
        vehicleProfile: VehicleSpecificationProfile,
        measurementSystem: RegionalMeasurementSystem = .imperial,
        session: URLSession = SecureURLSession.shared
    ) {
        self.vehicleProfile = vehicleProfile
        self.measurementSystem = measurementSystem
        if let key = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty {
            client = try? TomTomTrafficFlowClient(apiKey: key, session: session)
        } else {
            client = nil
        }
    }

    /// Updates the active vehicle profile used for speed ceiling calculations.
    public func configure(
        vehicleProfile: VehicleSpecificationProfile,
        measurementSystem: RegionalMeasurementSystem? = nil
    ) {
        self.vehicleProfile = vehicleProfile
        if let measurementSystem {
            self.measurementSystem = measurementSystem
        }
    }

    /// Updates the regional measurement system used for speed ceilings.
    public func configure(measurementSystem: RegionalMeasurementSystem) {
        self.measurementSystem = measurementSystem
    }

    /// Fetches congestion data adjusted for the active vehicle profile.
    public func fetchCongestion(at coordinate: RoutingCoordinate) async throws -> TrafficCongestionSnapshot {
        guard let client else {
            throw TomTomTrafficError.notConfigured
        }
        let flow = try await client.fetchFlowSegment(at: coordinate)
        return makeSnapshot(from: flow)
    }

    /// Applies the vehicle speed ceiling to TomTom free-flow speed.
    public func effectiveSpeedKmh(flow: TomTomFlowSegmentData) -> Double {
        let ceiling = speedCeilingKmh(for: vehicleProfile.vehicleClass)
        return min(flow.currentSpeedKmh, ceiling)
    }

    /// Returns a travel-time multiplier from vehicle-adjusted flow speeds.
    public func travelTimeMultiplier(flow: TomTomFlowSegmentData) -> Double {
        makeSnapshot(from: flow).velocityMultiplier
    }

    /// Scales great-circle distance by congestion-derived travel-time weighting.
    public func timeWeightedDistanceMeters(
        greatCircleMeters: Double,
        flow: TomTomFlowSegmentData?
    ) -> Double {
        guard let flow else { return greatCircleMeters }
        let multiplier = travelTimeMultiplier(flow: flow)
        guard multiplier > 0 else { return greatCircleMeters }
        return greatCircleMeters / multiplier
    }

    private func makeSnapshot(from flow: TomTomFlowSegmentData) -> TrafficCongestionSnapshot {
        let ceiling = speedCeilingKmh(for: vehicleProfile.vehicleClass)
        let adjustedFreeFlow = min(flow.freeFlowSpeedKmh, ceiling)
        let adjustedCurrent = min(flow.currentSpeedKmh, adjustedFreeFlow)
        let level = TrafficCongestionLevel.classify(
            currentSpeedKmh: adjustedCurrent,
            freeFlowSpeedKmh: max(adjustedFreeFlow, 1.0)
        )
        return TrafficCongestionSnapshot(
            rawFlow: flow,
            effectiveFreeFlowSpeedKmh: adjustedFreeFlow,
            effectiveCurrentSpeedKmh: adjustedCurrent,
            congestionLevel: level,
            velocityMultiplier: level.velocityMultiplier
        )
    }

    private func speedCeilingKmh(for vehicleClass: VehicleProfileClass) -> Double {
        let regionalLimits = VehicleSpeedLimits.limits(for: measurementSystem)
        switch vehicleClass {
        case .heavyGoodsVehicle, .lightCommercialVehicle:
            return regionalLimits.hgvMajorRoadSpeedKmh
        case .passengerCar:
            return regionalLimits.carMajorRoadSpeedKmh
        }
    }
}
