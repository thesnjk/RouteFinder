import Contracts
import CoreLocation
import Foundation
import GraphCore

/// Thread-safe live traffic telemetry ingestion and segment velocity scaling.
public actor TrafficDataService {
    /// Cross-track distance threshold for matching coordinates to route segments (meters).
    public static let crossTrackThresholdMeters = 80.0

    /// Bounding box eviction radius from vehicle position (meters).
    public static let evictionRadiusMeters = 50_000.0

    /// Minimum interval between TomTom polls for the same segment (seconds).
    public static let pollIntervalSeconds: TimeInterval = 30

    private var segments: [TrafficSegmentSnapshot] = []
    private var cumulativeLengths: [Double] = []
    private var routeCoordinates: [RoutingCoordinate] = []
    private var lastPollInstant: [UUID: ContinuousClock.Instant] = [:]
    private var integration: TomTomTrafficFlowIntegration?

    /// Creates a traffic data service with an optional TomTom API key.
    public init(tomTomAPIKey: String? = nil, vehicleProfile: VehicleSpecificationProfile? = nil) {
        let profile = vehicleProfile ?? VehicleSpecificationProfile.routingDefault(
            vehicleClass: .heavyGoodsVehicle
        )
        if let key = tomTomAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty {
            integration = TomTomTrafficFlowIntegration(apiKey: key, vehicleProfile: profile)
        }
    }

    /// Configures the active vehicle profile for traffic interpretation.
    public func configure(vehicleProfile: VehicleSpecificationProfile) async {
        await integration?.configure(vehicleProfile: vehicleProfile)
    }

    /// Configures the service with route polyline arc-length data.
    public func configureRoute(
        coordinates: [RoutingCoordinate],
        cumulativeLengths: [Double]
    ) {
        routeCoordinates = coordinates
        self.cumulativeLengths = cumulativeLengths
        segments.removeAll()
        lastPollInstant.removeAll()

        if let first = coordinates.first {
            let coordinate = CLLocationCoordinate2D(
                latitude: first.latitude,
                longitude: first.longitude
            )
            let measurementSystem = TelemetryUnitConverter.measurementSystem(for: coordinate)
            Task {
                await integration?.configure(measurementSystem: measurementSystem)
            }
        }
    }

    /// Returns velocity multiplier at the given arc length (1.0 when no traffic data).
    public func velocityMultiplier(atArcLength arcLength: Double) -> Double {
        guard !segments.isEmpty else { return 1.0 }
        for segment in segments {
            if arcLength >= segment.startArcLengthMeters,
               arcLength <= segment.endArcLengthMeters {
                return segment.congestionLevel.velocityMultiplier
            }
        }
        return 1.0
    }

    /// Polls TomTom for traffic at the vehicle position and updates segment cache.
    public func refreshTraffic(at coordinate: RoutingCoordinate, arcLength: Double) async {
        guard let integration else { return }

        let segmentIndex = nearestSegmentIndex(to: coordinate)
        guard segmentIndex >= 0, segmentIndex < routeCoordinates.count - 1 else { return }

        let segmentID = segmentUUID(for: segmentIndex)
        let now = ContinuousClock.now
        if let lastPoll = lastPollInstant[segmentID] {
            let elapsed = Self.seconds(from: lastPoll.duration(to: now))
            if elapsed < Self.pollIntervalSeconds { return }
        }

        do {
            let snapshot = try await integration.fetchCongestion(at: coordinate)
            let startArc = cumulativeLengths[segmentIndex]
            let endArc = cumulativeLengths[min(segmentIndex + 1, cumulativeLengths.count - 1)]
            let trafficSnapshot = TrafficSegmentSnapshot(
                id: segmentID,
                startArcLengthMeters: startArc,
                endArcLengthMeters: endArc,
                congestionLevel: snapshot.congestionLevel,
                currentSpeedKmh: snapshot.effectiveCurrentSpeedKmh,
                freeFlowSpeedKmh: snapshot.effectiveFreeFlowSpeedKmh,
                sampleCoordinate: coordinate
            )
            upsertSegment(trafficSnapshot)
            lastPollInstant[segmentID] = now
        } catch {
            // Silently retain stale data on network failure.
        }
    }

    /// Evicts traffic segments outside the bounding box from the vehicle position.
    public func evictStaleSegments(vehicleCoordinate: RoutingCoordinate) {
        segments.removeAll { segment in
            let a = segment.sampleCoordinate.coordinate
            let b = vehicleCoordinate.coordinate
            return Haversine.distance(from: a, to: b) > Self.evictionRadiusMeters
        }
        let validIDs = Set(segments.map(\.id))
        lastPollInstant = lastPollInstant.filter { validIDs.contains($0.key) }
    }

    /// All active traffic segments.
    public func activeSegments() -> [TrafficSegmentSnapshot] {
        segments
    }

    private func upsertSegment(_ snapshot: TrafficSegmentSnapshot) {
        if let index = segments.firstIndex(where: { $0.id == snapshot.id }) {
            segments[index] = snapshot
        } else {
            segments.append(snapshot)
        }
        segments.sort { $0.startArcLengthMeters < $1.startArcLengthMeters }
    }

    private func segmentUUID(for index: Int) -> UUID {
        var hasher = Hasher()
        hasher.combine(index)
        hasher.combine(routeCoordinates[index].latitude)
        hasher.combine(routeCoordinates[index].longitude)
        let hash = hasher.finalize()
        var bytes = [UInt8](repeating: 0, count: 16)
        withUnsafeBytes(of: hash) { raw in
            for i in 0..<min(16, raw.count) {
                bytes[i] = raw[i]
            }
        }
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private func nearestSegmentIndex(to coordinate: RoutingCoordinate) -> Int {
        guard routeCoordinates.count >= 2 else { return -1 }
        var bestIndex = 0
        var bestDistance = Double.greatestFiniteMagnitude
        for index in 0..<(routeCoordinates.count - 1) {
            let from = routeCoordinates[index]
            let to = routeCoordinates[index + 1]
            let distance = crossTrackDistanceMeters(point: coordinate, from: from, to: to)
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        return bestDistance <= Self.crossTrackThresholdMeters ? bestIndex : -1
    }

    private func crossTrackDistanceMeters(
        point: RoutingCoordinate,
        from: RoutingCoordinate,
        to: RoutingCoordinate
    ) -> Double {
        let earthRadius = Haversine.earthRadiusMeters
        let lat1 = from.latitude * .pi / 180.0
        let lon1 = from.longitude * .pi / 180.0
        let lat2 = to.latitude * .pi / 180.0
        let lon2 = to.longitude * .pi / 180.0
        let latP = point.latitude * .pi / 180.0
        let lonP = point.longitude * .pi / 180.0

        let dLat = lat2 - lat1
        let dLon = lon2 - lon1
        let segmentLength = sqrt(dLat * dLat + dLon * dLon)
        guard segmentLength > 1e-12 else {
            return Haversine.distance(from: point.coordinate, to: from.coordinate)
        }

        let t = max(0.0, min(1.0, ((latP - lat1) * dLat + (lonP - lon1) * dLon) / (segmentLength * segmentLength)))
        let projLat = lat1 + t * dLat
        let projLon = lon1 + t * dLon
        let dLatP = latP - projLat
        let dLonP = lonP - projLon
        return earthRadius * sqrt(dLatP * dLatP + dLonP * dLonP)
    }

    private static func seconds(from duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds)
            + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
