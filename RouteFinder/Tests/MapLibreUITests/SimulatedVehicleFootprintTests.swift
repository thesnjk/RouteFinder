import CoreLocation
import Foundation
import MapLibreUI
import Testing

struct SimulatedVehicleFootprintTests {
  private let rearAxle = CLLocationCoordinate2D(latitude: 51.5, longitude: -0.12)

  @Test func polygonClosesRing() {
    let ring = SimulatedVehicleFootprint.polygonCoordinates(
      rearAxle: rearAxle,
      bearingDegrees: 0,
      lengthMeters: 12,
      widthMeters: 2.55
    )
    #expect(ring.count == 5)
    #expect(ring.first?.latitude == ring.last?.latitude)
    #expect(ring.first?.longitude == ring.last?.longitude)
  }

  @Test func northBearingAlignsLongAxisNorthSouth() {
    let ring = SimulatedVehicleFootprint.polygonCoordinates(
      rearAxle: rearAxle,
      bearingDegrees: 0,
      lengthMeters: 100,
      widthMeters: 20
    )
    let frontLeft = ring[1]
    let frontRight = ring[0]
    let rearRight = ring[3]
    let rearLeft = ring[2]

    #expect(frontLeft.latitude > rearAxle.latitude)
    #expect(abs(rearLeft.latitude - rearAxle.latitude) < 0.0001)
    #expect(abs(frontLeft.longitude - rearAxle.longitude) < 0.0003)
    #expect(abs(rearRight.longitude - rearAxle.longitude) < 0.0003)
    #expect(abs(frontLeft.latitude - frontRight.latitude) < 0.0001)
  }

  @Test func cornerDistancesMatchRearAxleDimensions() {
    let length = 12.0
    let width = 2.55
    let ring = SimulatedVehicleFootprint.polygonCoordinates(
      rearAxle: rearAxle,
      bearingDegrees: 45,
      lengthMeters: length,
      widthMeters: width
    )

    let frontLeft = ring[1]
    let distance = SimulatedVehicleFootprint.distanceMeters(from: rearAxle, to: frontLeft)
    let expected = hypot(length, width / 2)
    #expect(abs(distance - expected) < 1.0)
  }

  @Test func defaultsMatchStandardHGVRigidPreset() {
    #expect(SimulatedVehicleFootprint.defaultLengthMeters == 12.0)
    #expect(SimulatedVehicleFootprint.defaultWidthMeters == 2.55)
  }
}
