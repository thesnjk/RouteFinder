import Contracts
import Foundation
import Testing
@testable import NavigationCore

@Test func speedLimitSpineBinderPropagatesHoldLastValue() {
    let limits: [Double?] = [48, nil, nil, 60]
    let filled = SpeedLimitSpineBinder.fillGaps(in: limits, coordinateCount: 4)
    #expect(filled == [48, 48, 48, 60])
}

@Test func spineResolverPrefersExplicitGeometryLimit() {
    let coordinates = [
        Coordinate(latitude: 52.0, longitude: 1.0),
        Coordinate(latitude: 52.001, longitude: 1.0),
        Coordinate(latitude: 52.002, longitude: 1.0),
    ]
    let geometry = RouteGeometryCanonicalizer.process(
        coordinates,
        simulationStepMeters: 100,
        speedLimitSource: SegmentSpeedLimitSource(
            rawGeometrySpeedLimitsKmh: [96, 96, 96],
            stepSpeedRanges: []
        )
    )
    let fallback = SimulationSpeedProfileFallback(
        defaultSpeedKmh: 48,
        measurementSystem: .metric
    )
    let resolver = SpineSpeedLimitResolver(
        cumulativeLengths: geometry.cumulativeLengths,
        legalSpeedLimitMps: geometry.legalSpeedLimitMps,
        fallbackResolver: fallback,
        vehicleCeilingKmh: 112
    )
    let details = resolver.limitDetails(at: 0)
    #expect(details.source == .orsExplicit)
    #expect(details.speedKmh == 96)
}

@Test func canonicalizerInterpolatesMixedSpeedLimitsToMps() {
    let coordinates = [
        Coordinate(latitude: 52.628, longitude: 1.296),
        Coordinate(latitude: 52.628, longitude: 1.30),
        Coordinate(latitude: 52.628, longitude: 1.32),
        Coordinate(latitude: 52.628, longitude: 1.34),
    ]
    let geometry = RouteGeometryCanonicalizer.process(
        coordinates,
        simulationStepMeters: 100,
        speedLimitSource: SegmentSpeedLimitSource(
            rawGeometrySpeedLimitsKmh: [48, 48, 112, 112],
            stepSpeedRanges: []
        )
    )

    #expect(!geometry.legalSpeedLimitMps.isEmpty)
    let firstLimit = geometry.legalSpeedLimitMps.first ?? nil
    #expect(abs((firstLimit ?? 0) - (48 / 3.6)) < 0.01)

    let lastLimit = geometry.legalSpeedLimitMps.last ?? nil
    #expect(abs((lastLimit ?? 0) - (112 / 3.6)) < 0.01)

    let fallback = SimulationSpeedProfileFallback(
        defaultSpeedKmh: 48,
        measurementSystem: .metric
    )
    let resolver = SpineSpeedLimitResolver(
        cumulativeLengths: geometry.cumulativeLengths,
        legalSpeedLimitMps: geometry.legalSpeedLimitMps,
        fallbackResolver: fallback,
        vehicleCeilingKmh: 112
    )
    let motorwayArc = geometry.totalLengthMeters - 1
    let details = resolver.limitDetails(at: motorwayArc)
    #expect(details.source == .orsExplicit)
    #expect(abs(details.speedKmh - 112) < 1.0)
}

@Test func spineResolverCapsExplicitLimitToVehicleCeiling() {
    let coordinates = [
        Coordinate(latitude: 52.0, longitude: 1.0),
        Coordinate(latitude: 52.001, longitude: 1.0),
    ]
    let geometry = RouteGeometryCanonicalizer.process(
        coordinates,
        simulationStepMeters: 100,
        speedLimitSource: SegmentSpeedLimitSource(
            rawGeometrySpeedLimitsKmh: [130, 130],
            stepSpeedRanges: []
        )
    )
    let fallback = SimulationSpeedProfileFallback(
        defaultSpeedKmh: 48,
        measurementSystem: .metric
    )
    let resolver = SpineSpeedLimitResolver(
        cumulativeLengths: geometry.cumulativeLengths,
        legalSpeedLimitMps: geometry.legalSpeedLimitMps,
        fallbackResolver: fallback,
        vehicleCeilingKmh: 112
    )
    let details = resolver.limitDetails(at: 0)
    #expect(details.speedKmh == 112)
}

/// Minimal maneuver fallback for NavigationCore resolver tests.
private struct SimulationSpeedProfileFallback: RouteSpeedLimitResolver, Sendable {
    let defaultSpeedKmh: Double
    let measurementSystem: RegionalMeasurementSystem

    var regionalMeasurementSystem: RegionalMeasurementSystem { measurementSystem }

    func legalLimitMps(at arcLength: Double) -> Double {
        defaultSpeedKmh / 3.6
    }

    func limitDetails(at arcLength: Double) -> SpeedLimitSample {
        SpeedLimitSample(arcLength: arcLength, speedKmh: defaultSpeedKmh, source: .regionalDefault)
    }
}
