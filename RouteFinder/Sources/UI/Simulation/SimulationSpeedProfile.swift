import Contracts
import CoreLocation
import Foundation
import NavigationCore
import RouteController

/// Maps arc length along a route to legal speed limits for simulation playback.
public struct SimulationSpeedProfile: Sendable, RouteSpeedLimitResolver {
    private let samples: [SpeedLimitSample]
    private let totalLength: Double
    private let defaultSpeedKmh: Double
    private let measurementSystem: RegionalMeasurementSystem

    /// Creates a speed profile from ORS step distance/duration and turn instruction road names.
    public init(
        maneuvers: [ExternalManeuver] = [],
        turnInstructions: [TurnInstruction] = [],
        isPassengerCar: Bool = false,
        routeCoordinate: CLLocationCoordinate2D? = nil
    ) {
        let measurementSystem: RegionalMeasurementSystem
        if let routeCoordinate {
            measurementSystem = TelemetryUnitConverter.measurementSystem(for: routeCoordinate)
        } else {
            measurementSystem = .metric
        }
        self.measurementSystem = measurementSystem

        let regionalLimits = VehicleSpeedLimits.limits(for: measurementSystem)
        defaultSpeedKmh = regionalLimits.defaultSpeedKmh
        let hgvMajorRoadSpeedKmh = regionalLimits.hgvMajorRoadSpeedKmh
        let carMajorRoadSpeedKmh = regionalLimits.carMajorRoadSpeedKmh

        let vehicleCeiling = isPassengerCar ? carMajorRoadSpeedKmh : hgvMajorRoadSpeedKmh
        var mapped: [SpeedLimitSample] = []
        var cumulativeArc = 0.0

        let stepCount = max(maneuvers.count, turnInstructions.count)
        for index in 0..<stepCount {
            let maneuver = index < maneuvers.count ? maneuvers[index] : nil
            let instruction = index < turnInstructions.count ? turnInstructions[index] : nil

            let distance = maneuver?.distanceMeters ?? instruction?.distance ?? 0
            let duration = maneuver?.durationSeconds ?? 0
            let roadLabel = instruction?.roadName ?? maneuver?.instruction
            let explicitLimitKmh = maneuver?.speedLimitKmh

            let resolved = Self.resolveLimit(
                roadLabel: roadLabel,
                distanceMeters: distance,
                durationSeconds: duration,
                explicitLimitKmh: explicitLimitKmh,
                vehicleCeiling: vehicleCeiling,
                defaultSpeedKmh: defaultSpeedKmh,
                measurementSystem: measurementSystem,
                routeCoordinate: routeCoordinate
            )

            if distance > 0 {
                if mapped.isEmpty {
                    mapped.append(SpeedLimitSample(arcLength: 0, speedKmh: resolved.speedKmh, source: resolved.source))
                }
                cumulativeArc += distance
                mapped.append(
                    SpeedLimitSample(
                        arcLength: cumulativeArc,
                        speedKmh: resolved.speedKmh,
                        source: resolved.source
                    )
                )
            } else if mapped.isEmpty {
                mapped.append(SpeedLimitSample(arcLength: 0, speedKmh: resolved.speedKmh, source: resolved.source))
            }
        }

        totalLength = cumulativeArc
        if mapped.isEmpty {
            mapped.append(
                SpeedLimitSample(arcLength: 0, speedKmh: defaultSpeedKmh, source: .regionalDefault)
            )
        } else if totalLength > 0, mapped.last?.arcLength != totalLength {
            let last = mapped.last!
            mapped.append(
                SpeedLimitSample(arcLength: totalLength, speedKmh: last.speedKmh, source: last.source)
            )
        }

        var deduped: [SpeedLimitSample] = []
        for sample in mapped.sorted(by: { $0.arcLength < $1.arcLength }) {
            if let last = deduped.last, abs(last.arcLength - sample.arcLength) < 0.01 {
                deduped[deduped.count - 1] = sample
            } else {
                deduped.append(sample)
            }
        }
        samples = deduped.isEmpty
            ? [SpeedLimitSample(arcLength: 0, speedKmh: defaultSpeedKmh, source: .regionalDefault)]
            : deduped
    }

    /// Regional measurement system used when this profile was built.
    public var regionalMeasurementSystem: RegionalMeasurementSystem {
        measurementSystem
    }

    /// Legal speed limit in m/s at the given arc length along the route.
    public func legalLimitMps(at arcLength: Double) -> Double {
        legalLimitKmh(at: arcLength) / 3.6
    }

    /// Legal speed limit in km/h at the given arc length along the route.
    public func legalLimitKmh(at arcLength: Double) -> Double {
        limitDetails(at: arcLength).speedKmh
    }

    /// Returns speed limit and provenance at the given arc length.
    public func limitDetails(at arcLength: Double) -> SpeedLimitSample {
        guard !samples.isEmpty else {
            return SpeedLimitSample(
                arcLength: arcLength,
                speedKmh: defaultSpeedKmh,
                source: .regionalDefault
            )
        }

        let clamped = min(max(arcLength, 0), max(totalLength, 0))
        var match = SpeedLimitSample(
            arcLength: clamped,
            speedKmh: defaultSpeedKmh,
            source: .regionalDefault
        )

        for sample in samples {
            if sample.arcLength <= clamped {
                match = SpeedLimitSample(
                    arcLength: clamped,
                    speedKmh: sample.speedKmh,
                    source: sample.source
                )
            } else {
                break
            }
        }

        return match
    }

    /// Resolves a segment speed limit from road keywords, explicit payload, design speed, or default.
    static func resolveLimit(
        roadLabel: String?,
        distanceMeters: Double,
        durationSeconds: TimeInterval,
        explicitLimitKmh: Double?,
        vehicleCeiling: Double,
        defaultSpeedKmh: Double = VehicleSpeedLimits.defaultSpeedKmh,
        measurementSystem: RegionalMeasurementSystem = .metric,
        routeCoordinate: CLLocationCoordinate2D? = nil
    ) -> SpeedLimitSample {
        if let explicitLimitKmh, explicitLimitKmh > 0 {
            let normalized: Double
            if let routeCoordinate {
                normalized = SpeedLimitNormalizer.normalizeToKmh(
                    rawValue: explicitLimitKmh,
                    coordinate: routeCoordinate
                )
            } else {
                normalized = explicitLimitKmh
            }
            let capped = min(normalized, vehicleCeiling)
            return SpeedLimitSample(arcLength: 0, speedKmh: capped, source: .orsExplicit)
        }

        if isMajorRoad(roadLabel) {
            return SpeedLimitSample(arcLength: 0, speedKmh: vehicleCeiling, source: .majorRoadCeiling)
        }

        if durationSeconds > 0, distanceMeters > 0 {
            let rawDesignKmh = (distanceMeters / durationSeconds) * 3.6
            let corrected = SpeedLimitNormalizer.correctDesignSpeedKmh(
                designKmh: rawDesignKmh,
                measurementSystem: measurementSystem,
                roadLabel: roadLabel
            )
            let source: SpeedLimitSource = corrected != rawDesignKmh ? .correctedImperial : .designSpeed
            let capped = max(defaultSpeedKmh, min(corrected, vehicleCeiling))
            return SpeedLimitSample(arcLength: 0, speedKmh: capped, source: source)
        }

        return SpeedLimitSample(arcLength: 0, speedKmh: defaultSpeedKmh, source: .regionalDefault)
    }

    /// Resolves a segment speed limit from road keywords, design speed, or default.
    static func resolveLimitKmh(
        roadLabel: String?,
        distanceMeters: Double,
        durationSeconds: TimeInterval,
        vehicleCeiling: Double,
        defaultSpeedKmh: Double = VehicleSpeedLimits.defaultSpeedKmh
    ) -> Double {
        resolveLimit(
            roadLabel: roadLabel,
            distanceMeters: distanceMeters,
            durationSeconds: durationSeconds,
            explicitLimitKmh: nil,
            vehicleCeiling: vehicleCeiling,
            defaultSpeedKmh: defaultSpeedKmh
        ).speedKmh
    }

    /// Returns true when the road label matches motorway, M-road, or numbered A-road patterns.
    static func isMajorRoad(_ roadLabel: String?) -> Bool {
        guard let roadLabel else { return false }
        let lower = roadLabel.lowercased()

        if lower.contains("motorway") { return true }
        if lower.contains("dual carriageway") || lower.contains("trunk road") || lower.contains("trunk") {
            return true
        }
        if lower.contains("expressway") { return true }
        if lower.contains("national speed limit") || lower.contains("nsl") { return true }
        if lower.contains("a47") || lower.contains("a11") { return true }
        if lower.contains("a-road") || lower.contains("a road") { return true }

        if roadLabel.range(
            of: #"\bM\d+\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil {
            return true
        }

        return roadLabel.range(
            of: #"\bA\d+\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }
}
