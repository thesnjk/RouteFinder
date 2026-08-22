import CoreLocation
import Foundation
import RouteController

/// Builds georeferenced vehicle footprint polygons for map rendering.
public enum SimulatedVehicleFootprint {
  /// Default vehicle length when profile dimensions are unavailable.
  public static let defaultLengthMeters = 12.0
  /// Default vehicle width when profile dimensions are unavailable.
  public static let defaultWidthMeters = 2.55

  /// Geometry authority contract for Swift/JS footprint alignment.
  public enum VehicleFootprintGeometry: Sendable {
    /// Rear-axle anchored rectangle; body extends forward along bearing.
    case rearAxleAnchored
  }

  /// Active footprint geometry model used by map rendering.
  public static let geometryModel: VehicleFootprintGeometry = .rearAxleAnchored

  /// Builds a closed polygon (5 points, first equals last) for an oriented vehicle rectangle in WGS84.
  ///
  /// - Parameters:
  ///   - rearAxle: Rear-axle coordinate on the route centerline.
  ///   - bearingDegrees: Heading in degrees clockwise from north.
  ///   - lengthMeters: Vehicle length along the heading axis.
  ///   - widthMeters: Vehicle width perpendicular to heading.
  /// - Returns: Corner coordinates ordered front-right, front-left, rear-left, rear-right, closing point.
  public static func polygonCoordinates(
    rearAxle: CLLocationCoordinate2D,
    bearingDegrees: Double,
    lengthMeters: Double,
    widthMeters: Double
  ) -> [CLLocationCoordinate2D] {
    VehicleGeometryCalculator.generateFootprint(
      rearAxle: rearAxle,
      headingDegrees: bearingDegrees,
      lengthMeters: lengthMeters,
      widthMeters: widthMeters
    )
  }

  /// Offsets a coordinate by forward/right distances in a local ENU frame aligned to bearing.
  public static func offsetMeters(
    from center: CLLocationCoordinate2D,
    bearingDegrees: Double,
    forwardMeters: Double,
    rightMeters: Double
  ) -> CLLocationCoordinate2D {
    let bearingRadians = bearingDegrees * Double.pi / 180.0
    let east = forwardMeters * sin(bearingRadians) + rightMeters * cos(bearingRadians)
    let north = forwardMeters * cos(bearingRadians) - rightMeters * sin(bearingRadians)

    let latitudeRadians = center.latitude * Double.pi / 180.0
    let metersPerDegreeLatitude = 111_320.0
    let metersPerDegreeLongitude = metersPerDegreeLatitude * cos(latitudeRadians)
    let deltaLatitude = north / metersPerDegreeLatitude
    let deltaLongitude = east / metersPerDegreeLongitude

    return CLLocationCoordinate2D(
      latitude: center.latitude + deltaLatitude,
      longitude: center.longitude + deltaLongitude
    )
  }

  /// Haversine distance between two coordinates in meters.
  public static func distanceMeters(
    from: CLLocationCoordinate2D,
    to: CLLocationCoordinate2D
  ) -> Double {
    let earthRadiusMeters = 6_378_137.0
    let lat1 = from.latitude * Double.pi / 180.0
    let lat2 = to.latitude * Double.pi / 180.0
    let deltaLat = (to.latitude - from.latitude) * Double.pi / 180.0
    let deltaLon = (to.longitude - from.longitude) * Double.pi / 180.0
    let sinDLat = sin(deltaLat / 2.0)
    let sinDLon = sin(deltaLon / 2.0)
    let h = sinDLat * sinDLat + cos(lat1) * cos(lat2) * sinDLon * sinDLon
    return 2.0 * earthRadiusMeters * atan2(sqrt(h), sqrt(max(0.0, 1.0 - h)))
  }
}
