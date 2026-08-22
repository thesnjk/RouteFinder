import Contracts
import CoreLocation
import CostModel
import Foundation

/// Unified post-ORS geometry processing for map display and simulation playback.
public enum RouteGeometryCanonicalizer: Sendable {
    /// Maximum point count before display path applies light RDP simplification.
    public static let displaySimplificationThreshold = 10_000
    /// RDP tolerance for display when point count exceeds threshold (~1.1 m).
    public static let displayRDPTolerance = 0.00001
    /// Default densification step for simulation spine (meters).
    public static let simulationStepMeters = 5.0

    /// Canonicalized route geometry derived from raw routing coordinates.
    public struct CanonicalRouteGeometry: Sendable {
        /// High-density coordinates for physics and arc-length sampling.
        public let simulationCoordinates: [Coordinate]
        /// Map display coordinates aligned to the simulation spine.
        public let displayCoordinates: [CLLocationCoordinate2D]
        /// Per-segment lengths along the simulation spine.
        public let segmentLengths: [Double]
        /// Cumulative arc lengths including zero at the origin.
        public let cumulativeLengths: [Double]
        /// Total route length in meters.
        public let totalLengthMeters: Double
        /// Optional legal speed limit in m/s for each simulation spine vertex.
        public let legalSpeedLimitMps: [Double?]

        /// Creates canonical route geometry.
        public init(
            simulationCoordinates: [Coordinate],
            displayCoordinates: [CLLocationCoordinate2D],
            segmentLengths: [Double],
            cumulativeLengths: [Double],
            totalLengthMeters: Double,
            legalSpeedLimitMps: [Double?] = []
        ) {
            self.simulationCoordinates = simulationCoordinates
            self.displayCoordinates = displayCoordinates
            self.segmentLengths = segmentLengths
            self.cumulativeLengths = cumulativeLengths
            self.totalLengthMeters = totalLengthMeters
            self.legalSpeedLimitMps = legalSpeedLimitMps
        }
    }

    /// Processes raw ORS coordinates into display and simulation geometry products.
    public static func process(
        _ rawCoordinates: [Coordinate],
        simulationStepMeters: Double = simulationStepMeters,
        speedLimitSource: SegmentSpeedLimitSource? = nil
    ) -> CanonicalRouteGeometry {
        let gapFilled = ElevationGapFiller.fillGaps(in: rawCoordinates)
        var rawLimits = speedLimitSource?.rawGeometrySpeedLimitsKmh ?? []
        if rawLimits.count != gapFilled.count {
            rawLimits = SpeedLimitSpineBinder.fillGaps(in: rawLimits, coordinateCount: gapFilled.count)
        }
        if let speedLimitSource {
            SpeedLimitSpineBinder.applyStepRanges(to: &rawLimits, ranges: speedLimitSource.stepSpeedRanges)
        }
        let gapFilledLimits = SpeedLimitSpineBinder.fillGaps(in: rawLimits, coordinateCount: gapFilled.count)
        let densifyResult = densifyCoordinatesWithLimits(
            gapFilled,
            rawSpeedLimitsKmh: gapFilledLimits,
            stepMeters: simulationStepMeters
        )
        let simulationCoordinates = densifyResult.coordinates
        let legalSpeedLimitMps = densifyResult.speedLimitsMps
        let segmentLengths = buildSegmentLengths(for: simulationCoordinates)
        let cumulativeLengths = buildCumulativeLengths(from: segmentLengths)
        let totalLengthMeters = segmentLengths.reduce(0, +)

        let displayCoordinates = displayCoordinates(
            from: simulationCoordinates,
            pointCount: simulationCoordinates.count
        )

        return CanonicalRouteGeometry(
            simulationCoordinates: simulationCoordinates,
            displayCoordinates: displayCoordinates,
            segmentLengths: segmentLengths,
            cumulativeLengths: cumulativeLengths,
            totalLengthMeters: totalLengthMeters,
            legalSpeedLimitMps: legalSpeedLimitMps
        )
    }

    /// Processes CoreLocation coordinates (optional parallel elevations).
    public static func process(
        route: [CLLocationCoordinate2D],
        elevations: [Double?] = [],
        simulationStepMeters: Double = simulationStepMeters,
        speedLimitSource: SegmentSpeedLimitSource? = nil
    ) -> CanonicalRouteGeometry {
        let coordinates = route.enumerated().map { index, coordinate in
            let elevation = elevations.indices.contains(index) ? elevations[index] : nil
            return Coordinate(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                elevationMeters: elevation
            )
        }
        return process(coordinates, simulationStepMeters: simulationStepMeters, speedLimitSource: speedLimitSource)
    }

    private static func displayCoordinates(
        from simulationCoordinates: [Coordinate],
        pointCount: Int
    ) -> [CLLocationCoordinate2D] {
        let mapCoords = simulationCoordinates.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        guard pointCount > displaySimplificationThreshold else {
            return mapCoords
        }
        return PolylineSimplifier.simplifyForDisplay(mapCoords, tolerance: displayRDPTolerance)
    }

    private struct DensifyWithLimitsResult {
        let coordinates: [Coordinate]
        let speedLimitsMps: [Double?]
    }

    private static func densifyCoordinatesWithLimits(
        _ coordinates: [Coordinate],
        rawSpeedLimitsKmh: [Double?],
        stepMeters: Double
    ) -> DensifyWithLimitsResult {
        guard coordinates.count >= 2 else {
            let limits = rawSpeedLimitsKmh.map { $0.map { $0 / 3.6 } }
            return DensifyWithLimitsResult(coordinates: coordinates, speedLimitsMps: limits)
        }

        var resultCoords: [Coordinate] = [coordinates[0]]
        var resultLimits: [Double?] = [SpeedLimitSpineBinder.limitMps(at: 0, from: rawSpeedLimitsKmh)]

        for index in 0..<(coordinates.count - 1) {
            let from = coordinates[index]
            let to = coordinates[index + 1]
            let fromLimit = SpeedLimitSpineBinder.limitMps(at: index, from: rawSpeedLimitsKmh)
            let toLimit = SpeedLimitSpineBinder.limitMps(at: index + 1, from: rawSpeedLimitsKmh)
            let distance = segmentDistance(from, to)
            let adaptiveStep = min(stepMeters, max(1.0, distance / 2.0))
            let steps = max(1, Int(distance / adaptiveStep))
            for step in 1...steps {
                let t = Double(step) / Double(steps)
                let elevation: Double?
                if let fromElevation = from.elevationMeters, let toElevation = to.elevationMeters {
                    elevation = fromElevation + (toElevation - fromElevation) * t
                } else {
                    elevation = from.elevationMeters ?? to.elevationMeters
                }
                resultCoords.append(Coordinate(
                    latitude: from.latitude + (to.latitude - from.latitude) * t,
                    longitude: from.longitude + (to.longitude - from.longitude) * t,
                    elevationMeters: elevation
                ))
                let interpolatedLimit: Double?
                switch (fromLimit, toLimit) {
                case let (from?, to?):
                    interpolatedLimit = from + (to - from) * t
                case let (from?, nil):
                    interpolatedLimit = from
                case let (nil, to?):
                    interpolatedLimit = to
                default:
                    interpolatedLimit = nil
                }
                resultLimits.append(interpolatedLimit)
            }
        }
        return DensifyWithLimitsResult(coordinates: resultCoords, speedLimitsMps: resultLimits)
    }

    private static func buildSegmentLengths(for coordinates: [Coordinate]) -> [Double] {
        guard coordinates.count >= 2 else { return [] }
        return zip(coordinates, coordinates.dropFirst()).map { segmentDistance($0, $1) }
    }

    private static func buildCumulativeLengths(from segments: [Double]) -> [Double] {
        var cumulative: [Double] = [0]
        for length in segments {
            cumulative.append(cumulative.last! + length)
        }
        return cumulative
    }

    private static func segmentDistance(_ a: Coordinate, _ b: Coordinate) -> Double {
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
