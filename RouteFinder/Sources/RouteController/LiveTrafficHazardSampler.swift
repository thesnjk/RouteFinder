import Contracts
import Foundation

/// Samples TomTom flow segments ahead of the vehicle during live navigation.
public enum LiveTrafficHazardSampler: Sendable {
    /// Default arc-length offsets ahead of the vehicle to probe (meters).
    public static let aheadSampleOffsetsMeters: [Double] = [2_000, 5_000, 8_000]

    /// Minimum interval between live TomTom hazard polls (seconds).
    public static let pollIntervalSeconds: TimeInterval = 30

    /// Returns whether another TomTom hazard poll is allowed.
    public static func shouldPoll(lastSampleDate: Date?, now: Date = Date()) -> Bool {
        guard let lastSampleDate else { return true }
        return now.timeIntervalSince(lastSampleDate) >= pollIntervalSeconds
    }

    /// Returns coordinates to sample ahead of the current arc length on the route spine.
    public static func samplePointsAhead(
        route: [Coordinate],
        currentArcLengthMeters: Double,
        offsetsMeters: [Double] = aheadSampleOffsetsMeters
    ) -> [(coordinate: Coordinate, arcLengthMeters: Double)] {
        guard route.count >= 2 else { return [] }
        return offsetsMeters.compactMap { offset in
            let target = currentArcLengthMeters + offset
            guard let coordinate = coordinate(atArcLength: target, on: route) else { return nil }
            return (coordinate, target)
        }
    }

    /// Builds a TomTom hazard hit when flow data indicates standstill or closure.
    public static func hazardHit(
        flow: TomTomFlowSegmentData,
        snapshot: TrafficCongestionSnapshot,
        sample: Coordinate,
        arcLengthMeters: Double
    ) -> TomTomTrafficHazardHit? {
        guard VehicleAdjustedTrafficClassifier.isRerouteWorthy(flow: flow, snapshot: snapshot) else {
            return nil
        }
        let id = "tomtom-\(sample.latitude)-\(sample.longitude)-\(Int(arcLengthMeters))"
        return TomTomTrafficHazardHit(
            id: id,
            latitude: sample.latitude,
            longitude: sample.longitude,
            arcLengthAlongRouteMeters: arcLengthMeters,
            isRoadClosed: flow.roadClosed
        )
    }

    /// Polls TomTom at ahead sample points and returns the nearest worthy hit.
    public static func sampleAhead(
        route: [Coordinate],
        currentArcLengthMeters: Double,
        trafficClient: TomTomTrafficFlowClient,
        vehicleClass: VehicleProfileClass,
        measurementSystem: RegionalMeasurementSystem = .imperial,
        offsetsMeters: [Double] = aheadSampleOffsetsMeters
    ) async -> TomTomTrafficHazardHit? {
        let points = samplePointsAhead(
            route: route,
            currentArcLengthMeters: currentArcLengthMeters,
            offsetsMeters: offsetsMeters
        )
        guard !points.isEmpty else { return nil }

        var nearest: TomTomTrafficHazardHit?
        var nearestDistance = Double.greatestFiniteMagnitude

        for point in points {
            let routingPoint = RoutingCoordinate(
                latitude: point.coordinate.latitude,
                longitude: point.coordinate.longitude
            )
            do {
                let flow = try await trafficClient.fetchFlowSegment(at: routingPoint)
                let snapshot = VehicleAdjustedTrafficClassifier.snapshot(
                    from: flow,
                    vehicleClass: vehicleClass,
                    measurementSystem: measurementSystem
                )
                guard let hit = hazardHit(
                    flow: flow,
                    snapshot: snapshot,
                    sample: point.coordinate,
                    arcLengthMeters: point.arcLengthMeters
                ) else { continue }
                let remaining = hit.arcLengthAlongRouteMeters - currentArcLengthMeters
                if remaining < nearestDistance {
                    nearestDistance = remaining
                    nearest = hit
                }
            } catch {
                continue
            }
        }

        return nearest
    }

    private static func coordinate(atArcLength target: Double, on route: [Coordinate]) -> Coordinate? {
        guard route.count >= 2, target >= 0 else { return nil }
        var cumulative = 0.0
        for index in 0..<(route.count - 1) {
            let from = route[index]
            let to = route[index + 1]
            let segmentLength = haversineMeters(from, to)
            guard segmentLength > 0 else { continue }
            if target <= cumulative + segmentLength {
                let t = (target - cumulative) / segmentLength
                return Coordinate(
                    latitude: from.latitude + t * (to.latitude - from.latitude),
                    longitude: from.longitude + t * (to.longitude - from.longitude)
                )
            }
            cumulative += segmentLength
        }
        return route.last
    }

    private static func haversineMeters(_ a: Coordinate, _ b: Coordinate) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let deltaLat = (b.latitude - a.latitude) * .pi / 180
        let deltaLon = (b.longitude - a.longitude) * .pi / 180
        let sinDLat = sin(deltaLat / 2)
        let sinDLon = sin(deltaLon / 2)
        let h = sinDLat * sinDLat + cos(lat1) * cos(lat2) * sinDLon * sinDLon
        return 2 * earthRadius * atan2(sqrt(h), sqrt(max(0, 1 - h)))
    }
}
