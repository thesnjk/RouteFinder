import Contracts
import Foundation

/// Outcome of a traffic-aware ORS re-route evaluation.
public struct TrafficRerouteResult: Sendable {
    /// The original ORS route before traffic avoidance.
    public let original: ExternalRouteResponse
    /// Optional alternate that avoids jammed polygons, when strictly better.
    public let alternate: ExternalRouteResponse?
    /// `true` when heavy/severe congestion or a closure was detected on the original corridor.
    public let trafficDelayDetected: Bool
    /// Avoid polygons used for the alternate request (rings of `[lon, lat]`).
    public let avoidPolygons: [[[Double]]]

    /// Creates a traffic re-route result.
    public init(
        original: ExternalRouteResponse,
        alternate: ExternalRouteResponse?,
        trafficDelayDetected: Bool,
        avoidPolygons: [[[Double]]] = []
    ) {
        self.original = original
        self.alternate = alternate
        self.trafficDelayDetected = trafficDelayDetected
        self.avoidPolygons = avoidPolygons
    }
}

/// Builds ORS `avoid_polygons` rings around jammed route segments (pure, no network).
public enum TrafficAvoidPolygonBuilder: Sendable {
    /// Default half-width of the avoid corridor in meters.
    public static let defaultHalfWidthMeters: Double = 400
    /// Arc length buffered before/after a jammed sample in meters.
    public static let defaultSegmentHalfLengthMeters: Double = 2_500

    /// Builds closed `[lon, lat]` rings around each jammed sample along a polyline.
    ///
    /// - Parameters:
    ///   - route: Route polyline in geographic coordinates.
    ///   - jammedSamples: Sample points classified as congested or closed.
    ///   - halfWidthMeters: Lateral buffer from the spine.
    ///   - segmentHalfLengthMeters: Along-route buffer around each sample.
    /// - Returns: Polygon rings suitable for ``ExternalRouteRequest/avoidPolygons``.
    public static func polygons(
        along route: [Coordinate],
        jammedSamples: [Coordinate],
        halfWidthMeters: Double = defaultHalfWidthMeters,
        segmentHalfLengthMeters: Double = defaultSegmentHalfLengthMeters
    ) -> [[[Double]]] {
        guard route.count >= 2, !jammedSamples.isEmpty else { return [] }

        var rings: [[[Double]]] = []
        for sample in jammedSamples {
            guard let (index, _) = nearestSegment(to: sample, on: route) else { continue }
            let from = route[index]
            let to = route[min(index + 1, route.count - 1)]
            if let ring = corridorRing(
                from: from,
                to: to,
                halfWidthMeters: halfWidthMeters,
                extendMeters: segmentHalfLengthMeters
            ) {
                rings.append(ring)
            }
        }
        return rings
    }

    /// Builds a single closed rectangular corridor around a segment, as `[lon, lat]` points.
    public static func corridorRing(
        from: Coordinate,
        to: Coordinate,
        halfWidthMeters: Double,
        extendMeters: Double = 0
    ) -> [[Double]]? {
        let bearing = initialBearingDegrees(from: from, to: to)
        guard bearing.isFinite else { return nil }

        let start = extendMeters > 0
            ? destination(from: from, distanceMeters: extendMeters, bearingDegrees: bearing + 180)
            : from
        let end = extendMeters > 0
            ? destination(from: to, distanceMeters: extendMeters, bearingDegrees: bearing)
            : to

        let leftBearing = bearing - 90
        let rightBearing = bearing + 90
        let a = destination(from: start, distanceMeters: halfWidthMeters, bearingDegrees: leftBearing)
        let b = destination(from: end, distanceMeters: halfWidthMeters, bearingDegrees: leftBearing)
        let c = destination(from: end, distanceMeters: halfWidthMeters, bearingDegrees: rightBearing)
        let d = destination(from: start, distanceMeters: halfWidthMeters, bearingDegrees: rightBearing)

        return [
            [a.longitude, a.latitude],
            [b.longitude, b.latitude],
            [c.longitude, c.latitude],
            [d.longitude, d.latitude],
            [a.longitude, a.latitude],
        ]
    }

    private static func nearestSegment(
        to point: Coordinate,
        on route: [Coordinate]
    ) -> (index: Int, distanceMeters: Double)? {
        var bestIndex = 0
        var bestDistance = Double.greatestFiniteMagnitude
        for index in 0..<(route.count - 1) {
            let mid = Coordinate(
                latitude: (route[index].latitude + route[index + 1].latitude) / 2,
                longitude: (route[index].longitude + route[index + 1].longitude) / 2
            )
            let distance = haversineMeters(point, mid)
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        return (bestIndex, bestDistance)
    }

    private static func initialBearingDegrees(from: Coordinate, to: Coordinate) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radians = atan2(y, x)
        return (radians * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    private static func destination(
        from: Coordinate,
        distanceMeters: Double,
        bearingDegrees: Double
    ) -> Coordinate {
        let earthRadius = 6_371_000.0
        let angular = distanceMeters / earthRadius
        let bearing = bearingDegrees * .pi / 180
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = asin(sin(lat1) * cos(angular) + cos(lat1) * sin(angular) * cos(bearing))
        let lon2 = lon1 + atan2(
            sin(bearing) * sin(angular) * cos(lat1),
            cos(angular) - sin(lat1) * sin(lat2)
        )
        return Coordinate(latitude: lat2 * 180 / .pi, longitude: lon2 * 180 / .pi)
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

/// Samples TomTom traffic along an ORS route and optionally re-calls ORS with avoid polygons.
public struct TrafficRerouteCoordinator: Sendable {
    /// Default spacing between TomTom sample points along the route.
    public static let defaultSampleIntervalMeters: Double = 7_500

    private let trafficClient: TomTomTrafficFlowClient
    private let routingClient: any ExternalRoutingClient
    private let sampleIntervalMeters: Double

    /// Creates a coordinator that samples live traffic and re-routes via ORS when jammed.
    public init(
        trafficClient: TomTomTrafficFlowClient,
        routingClient: any ExternalRoutingClient,
        sampleIntervalMeters: Double = defaultSampleIntervalMeters
    ) {
        self.trafficClient = trafficClient
        self.routingClient = routingClient
        self.sampleIntervalMeters = max(1_000, sampleIntervalMeters)
    }

    /// Evaluates the original route for congestion and returns an optional better alternate.
    ///
    /// Keeps the original when the second ORS call fails or is not strictly faster.
    public func evaluate(
        request: ExternalRouteRequest,
        original: ExternalRouteResponse
    ) async -> TrafficRerouteResult {
        let samples = Self.sampleCoordinates(along: original.coordinates, intervalMeters: sampleIntervalMeters)
        var jammed: [Coordinate] = []

        for sample in samples {
            let routingPoint = RoutingCoordinate(latitude: sample.latitude, longitude: sample.longitude)
            do {
                let flow = try await trafficClient.fetchFlowSegment(at: routingPoint)
                if flow.roadClosed || isSevereCongestion(flow.congestionLevel) {
                    jammed.append(sample)
                }
            } catch {
                continue
            }
        }

        guard !jammed.isEmpty else {
            return TrafficRerouteResult(
                original: original,
                alternate: nil,
                trafficDelayDetected: false,
                avoidPolygons: []
            )
        }

        let polygons = TrafficAvoidPolygonBuilder.polygons(
            along: original.coordinates,
            jammedSamples: jammed
        )
        guard !polygons.isEmpty else {
            return TrafficRerouteResult(
                original: original,
                alternate: nil,
                trafficDelayDetected: true,
                avoidPolygons: []
            )
        }

        do {
            let alternateRequest = request.withAvoidPolygons(polygons)
            let alternate = try await routingClient.route(request: alternateRequest)
            let isBetter = alternate.durationSeconds + 30 < original.durationSeconds
                || (alternate.durationSeconds <= original.durationSeconds
                    && alternate.distanceMeters < original.distanceMeters * 1.15)
            return TrafficRerouteResult(
                original: original,
                alternate: isBetter ? alternate : nil,
                trafficDelayDetected: true,
                avoidPolygons: polygons
            )
        } catch {
            return TrafficRerouteResult(
                original: original,
                alternate: nil,
                trafficDelayDetected: true,
                avoidPolygons: polygons
            )
        }
    }

    /// Samples coordinates roughly every `intervalMeters` along a polyline.
    public static func sampleCoordinates(
        along route: [Coordinate],
        intervalMeters: Double
    ) -> [Coordinate] {
        guard route.count >= 2 else { return route }
        var samples: [Coordinate] = []
        var cumulative = 0.0
        var nextSampleAt = 0.0

        for index in 0..<(route.count - 1) {
            let from = route[index]
            let to = route[index + 1]
            let segment = haversineMeters(from, to)
            if segment <= 0 { continue }

            while nextSampleAt <= cumulative + segment {
                let t = (nextSampleAt - cumulative) / segment
                let lat = from.latitude + (to.latitude - from.latitude) * t
                let lon = from.longitude + (to.longitude - from.longitude) * t
                samples.append(Coordinate(latitude: lat, longitude: lon))
                nextSampleAt += intervalMeters
            }
            cumulative += segment
        }

        if samples.isEmpty, let first = route.first {
            samples.append(first)
        }
        return samples
    }

    private func isSevereCongestion(_ level: TrafficCongestionLevel) -> Bool {
        switch level {
        case .heavy, .standstill:
            return true
        case .freeFlow, .light:
            return false
        }
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
