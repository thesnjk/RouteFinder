import CoreLocation
import Foundation

/// Anchor point for vehicle footprint generation.
public enum VehicleFootprintAnchor: Sendable {
    /// Footprint extends forward from the rear axle.
    case rearAxle
    /// Footprint is centered on the vehicle geometric midpoint.
    case geometricCenter
}

/// Translates vehicle dimensions and tracking headings into geodetic coordinate bounding polygons.
public struct VehicleGeometryCalculator: Sendable {
    private static let metersPerDegreeLatitude = 111_320.0
    private static let cabLengthFraction = 0.35

    /// Generates a rotated four-corner bounding polygon footprint.
    ///
    /// - Parameters:
    ///   - anchor: Whether ``anchorCoordinate`` is the rear axle or geometric center.
    ///   - anchorCoordinate: Anchor coordinate on the route centerline.
    ///   - headingDegrees: Heading in degrees clockwise from north.
    ///   - lengthMeters: Vehicle length along the heading axis.
    ///   - widthMeters: Vehicle width perpendicular to heading.
    /// - Returns: Closed polygon ring (five points; first equals last).
    public static func generateFootprint(
        anchor: VehicleFootprintAnchor = .rearAxle,
        anchorCoordinate: CLLocationCoordinate2D,
        headingDegrees: Double,
        lengthMeters: Double,
        widthMeters: Double
    ) -> [CLLocationCoordinate2D] {
        let rearOffset: Double
        switch anchor {
        case .rearAxle:
            rearOffset = 0
        case .geometricCenter:
            rearOffset = -lengthMeters * 0.5
        }
        return generateFootprintRing(
            rearAxle: offsetForward(
                from: anchorCoordinate,
                bearingDegrees: headingDegrees,
                forwardMeters: -rearOffset
            ),
            headingDegrees: headingDegrees,
            lengthMeters: lengthMeters,
            widthMeters: widthMeters
        )
    }

    /// Generates a rotated four-corner bounding polygon footprint based on the vehicle's rear axle,
    /// heading, and true size specifications.
    public static func generateFootprint(
        rearAxle: CLLocationCoordinate2D,
        headingDegrees: Double,
        lengthMeters: Double,
        widthMeters: Double
    ) -> [CLLocationCoordinate2D] {
        generateFootprint(
            anchor: .rearAxle,
            anchorCoordinate: rearAxle,
            headingDegrees: headingDegrees,
            lengthMeters: lengthMeters,
            widthMeters: widthMeters
        )
    }

    /// Generates cab and trailer/body footprint parts for map rendering.
    public static func generateFootprintParts(
        rearAxle: CLLocationCoordinate2D,
        headingDegrees: Double,
        lengthMeters: Double,
        widthMeters: Double,
        isPassengerCar: Bool
    ) -> [[CLLocationCoordinate2D]] {
        if isPassengerCar || lengthMeters < 6 {
            return [
                generateFootprint(
                    rearAxle: rearAxle,
                    headingDegrees: headingDegrees,
                    lengthMeters: lengthMeters,
                    widthMeters: widthMeters
                )
            ]
        }

        let cabLength = max(lengthMeters * Self.cabLengthFraction, 2.5)
        let trailerLength = max(lengthMeters - cabLength, 3.0)
        let cabRear = offsetForward(
            from: rearAxle,
            bearingDegrees: headingDegrees,
            forwardMeters: trailerLength
        )
        return [
            generateFootprintRing(
                rearAxle: cabRear,
                headingDegrees: headingDegrees,
                lengthMeters: cabLength,
                widthMeters: widthMeters
            ),
            generateFootprintRing(
                rearAxle: rearAxle,
                headingDegrees: headingDegrees,
                lengthMeters: trailerLength,
                widthMeters: widthMeters
            ),
        ]
    }

    /// Offsets a coordinate backward along the heading by the given distance in meters.
    public static func offsetBackward(
        from center: CLLocationCoordinate2D,
        bearingDegrees: Double,
        backwardMeters: Double
    ) -> CLLocationCoordinate2D {
        offsetForward(from: center, bearingDegrees: bearingDegrees, forwardMeters: -backwardMeters)
    }

    /// Offsets a coordinate forward along the heading by the given distance in meters.
    public static func offsetForward(
        from coordinate: CLLocationCoordinate2D,
        bearingDegrees: Double,
        forwardMeters: Double
    ) -> CLLocationCoordinate2D {
        let bearingRadians = bearingDegrees * Double.pi / 180.0
        let east = forwardMeters * sin(bearingRadians)
        let north = forwardMeters * cos(bearingRadians)

        let latitudeRadians = coordinate.latitude * Double.pi / 180.0
        let metersPerDegreeLongitude = Self.metersPerDegreeLatitude * cos(latitudeRadians)
        let deltaLatitude = north / Self.metersPerDegreeLatitude
        let deltaLongitude = east / metersPerDegreeLongitude

        return CLLocationCoordinate2D(
            latitude: coordinate.latitude + deltaLatitude,
            longitude: coordinate.longitude + deltaLongitude
        )
    }

    private static func generateFootprintRing(
        rearAxle: CLLocationCoordinate2D,
        headingDegrees: Double,
        lengthMeters: Double,
        widthMeters: Double
    ) -> [CLLocationCoordinate2D] {
        let headingRadians = headingDegrees * Double.pi / 180.0
        let cosineHeading = cos(headingRadians)
        let sineHeading = sin(headingRadians)

        let latitudeRadians = rearAxle.latitude * Double.pi / 180.0
        let metersPerDegreeLongitude = Self.metersPerDegreeLatitude * cos(latitudeRadians)

        let halfWidth = widthMeters / 2.0

        let localCorners: [(x: Double, y: Double)] = [
            (x: halfWidth, y: lengthMeters),
            (x: -halfWidth, y: lengthMeters),
            (x: -halfWidth, y: 0.0),
            (x: halfWidth, y: 0.0),
        ]

        let globalCoordinates = localCorners.map { corner -> CLLocationCoordinate2D in
            let rotatedX = corner.x * cosineHeading + corner.y * sineHeading
            let rotatedY = -corner.x * sineHeading + corner.y * cosineHeading

            let deltaLatitude = rotatedY / Self.metersPerDegreeLatitude
            let deltaLongitude = rotatedX / metersPerDegreeLongitude

            return CLLocationCoordinate2D(
                latitude: rearAxle.latitude + deltaLatitude,
                longitude: rearAxle.longitude + deltaLongitude
            )
        }

        guard let first = globalCoordinates.first else { return [] }
        return globalCoordinates + [first]
    }
}
