import Contracts
import Foundation

/// Result of traffic signal speed permission check.
public struct TrafficSignalPermission: Sendable, Hashable {
    /// Permitted speed in m/s (0 when must stop).
    public let permittedSpeedMps: Double
    /// Whether simulation should pause at the signal.
    public let mustStop: Bool
    /// Required deceleration to stop at signal in m/s².
    public let requiredDecelerationMps2: Double

    /// Creates a traffic signal permission result.
    public init(
        permittedSpeedMps: Double,
        mustStop: Bool,
        requiredDecelerationMps2: Double
    ) {
        self.permittedSpeedMps = permittedSpeedMps
        self.mustStop = mustStop
        self.requiredDecelerationMps2 = requiredDecelerationMps2
    }

    /// Unrestricted passage at current speed.
    public static let unrestricted = TrafficSignalPermission(
        permittedSpeedMps: .infinity,
        mustStop: false,
        requiredDecelerationMps2: 0
    )
}

/// Live environmental traffic signal ingestion and kinematic deceleration mapping.
public actor TrafficSignalController {
    /// Lookahead buffer beyond stopping distance (meters).
    public static let lookaheadBufferMeters = 50.0

    /// Default UK-style green phase duration (seconds).
    public static let defaultGreenDurationSeconds: TimeInterval = 25

    /// Default amber phase duration (seconds).
    public static let defaultAmberDurationSeconds: TimeInterval = 3

    /// Default red phase duration (seconds).
    public static let defaultRedDurationSeconds: TimeInterval = 27

    private var signals: [TrafficSignalRecord] = []
    private var phaseOffsets: [Int64: TimeInterval] = [:]
    private var cycleStartInstant: ContinuousClock.Instant?
    private let overpassClient: OverpassTrafficSignalClient
    private var routeCacheKey: String?

    /// Creates a traffic signal controller.
    public init(overpassClient: OverpassTrafficSignalClient = OverpassTrafficSignalClient()) {
        self.overpassClient = overpassClient
    }

    /// Ingests OSM traffic signals along the route polyline.
    public func configureRoute(
        coordinates: [RoutingCoordinate],
        cumulativeLengths: [Double]
    ) async {
        let cacheKey = routeCacheKey(for: coordinates)
        if cacheKey == routeCacheKey, !signals.isEmpty { return }
        routeCacheKey = cacheKey

        do {
            let nodes = try await overpassClient.fetchTrafficSignals(along: coordinates)
            signals = projectSignals(
                nodes: nodes,
                coordinates: coordinates,
                cumulativeLengths: cumulativeLengths
            ).sorted { $0.arcLengthMeters < $1.arcLengthMeters }
            cycleStartInstant = ContinuousClock.now
            for signal in signals {
                phaseOffsets[signal.id] = Double(signal.id % 7)
            }
        } catch {
            signals = []
        }
    }

    /// Returns permitted speed and stop state for the current simulation state.
    public func permittedSpeed(
        arcLength: Double,
        currentSpeedMps: Double,
        maxDecelMps2: Double,
        deltaTime: Double
    ) -> TrafficSignalPermission {
        guard !signals.isEmpty else { return .unrestricted }

        let stoppingDistance = currentSpeedMps > 0 && maxDecelMps2 > 0
            ? (currentSpeedMps * currentSpeedMps) / (2 * maxDecelMps2)
            : 0
        let lookahead = stoppingDistance + Self.lookaheadBufferMeters

        guard let upcoming = signals.first(where: { signal in
            signal.arcLengthMeters > arcLength
                && signal.arcLengthMeters - arcLength <= lookahead
        }) else {
            return .unrestricted
        }

        let distanceToStopBar = max(0.1, upcoming.arcLengthMeters - arcLength)
        let requiredDeceleration = (currentSpeedMps * currentSpeedMps) / (2.0 * distanceToStopBar)
        let phase = currentPhase(for: upcoming.id)

        switch phase {
        case .green:
            if requiredDeceleration > maxDecelMps2 * 1.1, currentSpeedMps > 0.5 {
                return TrafficSignalPermission(
                    permittedSpeedMps: 0,
                    mustStop: false,
                    requiredDecelerationMps2: min(requiredDeceleration, maxDecelMps2)
                )
            }
            return .unrestricted

        case .amber, .red:
            return TrafficSignalPermission(
                permittedSpeedMps: 0,
                mustStop: true,
                requiredDecelerationMps2: min(requiredDeceleration, maxDecelMps2)
            )
        }
    }

    /// All configured traffic signals.
    public func configuredSignals() -> [TrafficSignalRecord] {
        signals
    }

    private func currentPhase(for signalID: Int64) -> TrafficSignalPhase {
        guard let start = cycleStartInstant else { return .green }
        let offset = phaseOffsets[signalID] ?? 0
        let elapsed = Self.seconds(from: start.duration(to: ContinuousClock.now)) + offset
        let cycleDuration = Self.defaultGreenDurationSeconds
            + Self.defaultAmberDurationSeconds
            + Self.defaultRedDurationSeconds
        let position = elapsed.truncatingRemainder(dividingBy: cycleDuration)

        if position < Self.defaultGreenDurationSeconds {
            return .green
        }
        if position < Self.defaultGreenDurationSeconds + Self.defaultAmberDurationSeconds {
            return .amber
        }
        return .red
    }

    private func projectSignals(
        nodes: [OverpassTrafficSignalNode],
        coordinates: [RoutingCoordinate],
        cumulativeLengths: [Double]
    ) -> [TrafficSignalRecord] {
        guard coordinates.count >= 2, cumulativeLengths.count == coordinates.count else {
            return []
        }

        return nodes.compactMap { node in
            guard let projection = projectOntoPolyline(
                point: node.coordinate,
                coordinates: coordinates,
                cumulativeLengths: cumulativeLengths
            ) else { return nil }

            return TrafficSignalRecord(
                id: node.id,
                coordinate: node.coordinate,
                arcLengthMeters: projection.arcLength,
                bearingDegrees: projection.bearing,
                phase: .green
            )
        }
    }

    private struct PolylineProjection {
        let arcLength: Double
        let bearing: Double
    }

    private func projectOntoPolyline(
        point: RoutingCoordinate,
        coordinates: [RoutingCoordinate],
        cumulativeLengths: [Double]
    ) -> PolylineProjection? {
        var bestDistance = Double.greatestFiniteMagnitude
        var bestArcLength = 0.0
        var bestBearing = 0.0

        for index in 0..<(coordinates.count - 1) {
            let from = coordinates[index]
            let to = coordinates[index + 1]
            let segmentLength = haversineMeters(from, to)
            guard segmentLength > 0.5 else { continue }

            let t = clampProjectionParameter(point: point, from: from, to: to)
            let crossTrack = crossTrackDistanceMeters(point: point, from: from, to: to, t: t)
            if crossTrack < bestDistance {
                bestDistance = crossTrack
                bestArcLength = cumulativeLengths[index] + t * segmentLength
                bestBearing = bearingDegrees(from: from, to: to)
            }
        }

        guard bestDistance <= 45 else { return nil }
        return PolylineProjection(arcLength: bestArcLength, bearing: bestBearing)
    }

    private func clampProjectionParameter(
        point: RoutingCoordinate,
        from: RoutingCoordinate,
        to: RoutingCoordinate
    ) -> Double {
        let lat1 = from.latitude
        let lon1 = from.longitude
        let lat2 = to.latitude
        let lon2 = to.longitude
        let latP = point.latitude
        let lonP = point.longitude
        let dLat = lat2 - lat1
        let dLon = lon2 - lon1
        let lengthSquared = dLat * dLat + dLon * dLon
        guard lengthSquared > 1e-12 else { return 0 }
        return max(0, min(1, ((latP - lat1) * dLat + (lonP - lon1) * dLon) / lengthSquared))
    }

    private func crossTrackDistanceMeters(
        point: RoutingCoordinate,
        from: RoutingCoordinate,
        to: RoutingCoordinate,
        t: Double
    ) -> Double {
        let projLat = from.latitude + t * (to.latitude - from.latitude)
        let projLon = from.longitude + t * (to.longitude - from.longitude)
        return haversineMeters(point, RoutingCoordinate(latitude: projLat, longitude: projLon))
    }

    private func bearingDegrees(from: RoutingCoordinate, to: RoutingCoordinate) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        var bearing = atan2(y, x) * 180 / .pi
        if bearing < 0 { bearing += 360 }
        return bearing
    }

    private func haversineMeters(_ a: RoutingCoordinate, _ b: RoutingCoordinate) -> Double {
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

    private func routeCacheKey(for coordinates: [RoutingCoordinate]) -> String {
        coordinates.prefix(5).map { "\($0.latitude),\($0.longitude)" }.joined(separator: "|")
    }

    private static func seconds(from duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds)
            + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
