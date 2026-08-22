import CoreLocation
import Foundation

/// Translates vehicle dimensions and tracking headings into geodetic coordinate bounding polygons.
public struct VehicleGeometryCalculator: Sendable {
    private static let metersPerDegreeLatitude = 111_320.0

    /// Generates a rotated four-corner bounding polygon footprint based on the vehicle's rear axle,
    /// heading, and true size specifications.
    ///
    /// - Parameters:
    ///   - rearAxle: Rear-axle coordinate on the route centerline.
    ///   - headingDegrees: Heading in degrees clockwise from north.
    ///   - lengthMeters: Vehicle length along the heading axis.
    ///   - widthMeters: Vehicle width perpendicular to heading.
    /// - Returns: Closed polygon ring (five points; first equals last) ordered
    ///   front-right, front-left, rear-left, rear-right, closing point.
    public static func generateFootprint(
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

    /// Offsets a coordinate backward along the heading by the given distance in meters.
    ///
    /// - Parameters:
    ///   - center: Starting coordinate (typically vehicle geometric center).
    ///   - bearingDegrees: Heading in degrees clockwise from north.
    ///   - backwardMeters: Distance to move opposite the heading.
    /// - Returns: Coordinate shifted toward the rear of the vehicle.
    public static func offsetBackward(
        from center: CLLocationCoordinate2D,
        bearingDegrees: Double,
        backwardMeters: Double
    ) -> CLLocationCoordinate2D {
        let bearingRadians = bearingDegrees * Double.pi / 180.0
        let east = -backwardMeters * sin(bearingRadians)
        let north = -backwardMeters * cos(bearingRadians)

        let latitudeRadians = center.latitude * Double.pi / 180.0
        let metersPerDegreeLongitude = Self.metersPerDegreeLatitude * cos(latitudeRadians)
        let deltaLatitude = north / Self.metersPerDegreeLatitude
        let deltaLongitude = east / metersPerDegreeLongitude

        return CLLocationCoordinate2D(
            latitude: center.latitude + deltaLatitude,
            longitude: center.longitude + deltaLongitude
        )
    }
}
