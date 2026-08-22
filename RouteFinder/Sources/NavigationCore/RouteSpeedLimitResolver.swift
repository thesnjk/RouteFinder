import Contracts
import Foundation

/// Resolves legal speed limits along a route arc length for simulation playback.
public protocol RouteSpeedLimitResolver: Sendable {
    /// Returns the legal speed limit in meters per second at the given arc length.
    func legalLimitMps(at arcLength: Double) -> Double
    /// Returns detailed limit metadata at the given arc length.
    func limitDetails(at arcLength: Double) -> SpeedLimitSample
    /// Regional measurement system used for fallback limits.
    var regionalMeasurementSystem: RegionalMeasurementSystem { get }
}

/// Reads explicit speed limits from a canonical route geometry spine.
public struct SpineSpeedLimitResolver: RouteSpeedLimitResolver, Sendable {
    private let cumulativeLengths: [Double]
    private let legalSpeedLimitMps: [Double?]
    private let fallbackResolver: BoxedRouteSpeedLimitResolver
    private let vehicleCeilingKmh: Double

    /// Creates a spine resolver with maneuver-based fallback.
    public init(
        cumulativeLengths: [Double],
        legalSpeedLimitMps: [Double?],
        fallbackResolver: some RouteSpeedLimitResolver & Sendable,
        vehicleCeilingKmh: Double
    ) {
        self.cumulativeLengths = cumulativeLengths
        self.legalSpeedLimitMps = legalSpeedLimitMps
        self.fallbackResolver = BoxedRouteSpeedLimitResolver(fallbackResolver)
        self.vehicleCeilingKmh = vehicleCeilingKmh
    }

    public var regionalMeasurementSystem: RegionalMeasurementSystem {
        fallbackResolver.regionalMeasurementSystem
    }

    public func legalLimitMps(at arcLength: Double) -> Double {
        limitDetails(at: arcLength).speedKmh / 3.6
    }

    public func limitDetails(at arcLength: Double) -> SpeedLimitSample {
        if let spineLimit = spineLimitMps(at: arcLength) {
            let cappedKmh = min(spineLimit * 3.6, vehicleCeilingKmh)
            return SpeedLimitSample(
                arcLength: arcLength,
                speedKmh: cappedKmh,
                source: .orsExplicit
            )
        }
        return fallbackResolver.limitDetails(at: arcLength)
    }

    private func spineLimitMps(at arcLength: Double) -> Double? {
        guard !legalSpeedLimitMps.isEmpty, cumulativeLengths.count == legalSpeedLimitMps.count else {
            return nil
        }
        let index = segmentIndex(for: arcLength)
        guard legalSpeedLimitMps.indices.contains(index) else { return nil }
        return legalSpeedLimitMps[index]
    }

    private func segmentIndex(for arcLength: Double) -> Int {
        guard cumulativeLengths.count > 1 else { return 0 }
        var low = 0
        var high = cumulativeLengths.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if cumulativeLengths[mid] <= arcLength {
                low = mid
            } else {
                high = mid - 1
            }
        }
        return min(low, legalSpeedLimitMps.count - 1)
    }
}

/// Combines spine-aligned and maneuver-based speed limit resolution.
public struct CompositeSpeedLimitResolver: RouteSpeedLimitResolver, Sendable {
    private let primary: BoxedRouteSpeedLimitResolver

    /// Creates a composite resolver.
    public init(primary: some RouteSpeedLimitResolver & Sendable) {
        self.primary = BoxedRouteSpeedLimitResolver(primary)
    }

    public var regionalMeasurementSystem: RegionalMeasurementSystem {
        primary.regionalMeasurementSystem
    }

    public func legalLimitMps(at arcLength: Double) -> Double {
        primary.legalLimitMps(at: arcLength)
    }

    public func limitDetails(at arcLength: Double) -> SpeedLimitSample {
        primary.limitDetails(at: arcLength)
    }
}

/// Type-erased speed limit resolver for Sendable physics configuration storage.
public struct BoxedRouteSpeedLimitResolver: RouteSpeedLimitResolver, Sendable {
    private let limitDetailsHandler: @Sendable (Double) -> SpeedLimitSample
    private let measurementSystem: RegionalMeasurementSystem

    /// Boxes a concrete resolver for storage in physics configuration.
    public init<R: RouteSpeedLimitResolver & Sendable>(_ resolver: R) {
        limitDetailsHandler = { arcLength in
            resolver.limitDetails(at: arcLength)
        }
        measurementSystem = resolver.regionalMeasurementSystem
    }

    public var regionalMeasurementSystem: RegionalMeasurementSystem {
        measurementSystem
    }

    public func legalLimitMps(at arcLength: Double) -> Double {
        limitDetails(at: arcLength).speedKmh / 3.6
    }

    public func limitDetails(at arcLength: Double) -> SpeedLimitSample {
        limitDetailsHandler(arcLength)
    }
}
