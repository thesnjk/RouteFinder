import Contracts
import CoreLocation
import Foundation

/// Pre-computed kinetic stress profile indexed by arc length along a route.
public struct KineticStressProfile: Sendable, Equatable {
    private let segments: [SegmentKineticStress]
    private let segmentStartArcLengths: [Double]

    /// Creates a kinetic stress profile from per-segment samples and cumulative arc lengths.
    public init(segments: [SegmentKineticStress], segmentStartArcLengths: [Double]) {
        self.segments = segments
        self.segmentStartArcLengths = segmentStartArcLengths
    }

    /// Returns the kinetic stress at the given arc length along the route.
    public func stress(atArcLength arcLength: Double) -> SegmentKineticStress {
        guard !segments.isEmpty else { return .neutral }

        let clamped = max(0, arcLength)
        var index = 0
        for start in segmentStartArcLengths {
            if start > clamped { break }
            index += 1
        }
        let resolvedIndex = min(max(0, index - 1), segments.count - 1)
        return segments[resolvedIndex]
    }
}

/// Synchronous kinetic stress analysis from 3D route geometry.
public enum KineticGradientAnalyzer: Sendable {
    /// Analyzes route topology and returns per-segment kinetic stress samples.
    public static func analyzeTopology(path: [GeoCoordinate3D], weightTons: Double) -> [SegmentKineticStress] {
        guard path.count > 1 else { return [] }

        var stressArray: [SegmentKineticStress] = []
        let massKg = weightTons * 1000.0

        for index in 0..<(path.count - 1) {
            let current = path[index]
            let next = path[index + 1]
            let locationA = CLLocation(
                latitude: current.latitude,
                longitude: current.longitude
            )
            let locationB = CLLocation(
                latitude: next.latitude,
                longitude: next.longitude
            )
            let distance = locationA.distance(from: locationB)

            guard distance > 0.5 else {
                stressArray.append(.neutral)
                continue
            }

            let currentElevation = current.elevationMeters ?? 0
            let nextElevation = next.elevationMeters ?? 0
            let deltaElevation = nextElevation - currentElevation
            let grade = (deltaElevation / distance) * 100.0

            var thermal = 0.0
            var load = 1.0

            if grade < -2.0 {
                thermal = min(1.0, (massKg / 44_000.0) * (abs(grade) / 15.0))
            } else if grade > 2.0 {
                load = min(3.5, 1.0 + ((grade / 15.0) * (massKg / 10_000.0)))
            }

            stressArray.append(
                SegmentKineticStress(
                    gradePercentage: grade,
                    thermalStressScore: thermal,
                    loadMultiplier: load
                )
            )
        }

        return stressArray
    }

    /// Builds an arc-length-indexed profile from route coordinates and vehicle weight.
    public static func buildProfile(path: [GeoCoordinate3D], weightTons: Double) -> KineticStressProfile {
        let segments = analyzeTopology(path: path, weightTons: weightTons)
        guard !path.isEmpty else {
            return KineticStressProfile(segments: [], segmentStartArcLengths: [])
        }

        var startArcLengths: [Double] = [0]
        var accumulated = 0.0
        for index in 0..<(path.count - 1) {
            let locationA = CLLocation(latitude: path[index].latitude, longitude: path[index].longitude)
            let locationB = CLLocation(latitude: path[index + 1].latitude, longitude: path[index + 1].longitude)
            accumulated += locationA.distance(from: locationB)
            startArcLengths.append(accumulated)
        }

        return KineticStressProfile(segments: segments, segmentStartArcLengths: startArcLengths)
    }
}

/// Evaluates 3D topographical stress curves from elevation and vehicle mass.
public actor KineticGradientEngine {
    /// Creates a kinetic gradient engine.
    public init() {}

    /// Analyzes route topology and returns per-segment kinetic stress samples.
    public func analyzeTopology(path: [GeoCoordinate3D], weightTons: Double) -> [SegmentKineticStress] {
        KineticGradientAnalyzer.analyzeTopology(path: path, weightTons: weightTons)
    }

    /// Builds an arc-length-indexed profile from route coordinates and vehicle weight.
    public func buildProfile(path: [GeoCoordinate3D], weightTons: Double) -> KineticStressProfile {
        KineticGradientAnalyzer.buildProfile(path: path, weightTons: weightTons)
    }
}
