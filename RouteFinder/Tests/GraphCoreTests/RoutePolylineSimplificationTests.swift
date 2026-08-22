import Contracts
import CoreLocation
import Testing
@testable import UI

@Suite("RoutePolyline simplification")
struct RoutePolylineSimplificationTests {
    @Test("simplifyForDisplay reduces collinear points")
    func reducesCollinearPoints() {
        let coords = [
            Coordinate(latitude: 52.0, longitude: 1.0),
            Coordinate(latitude: 52.001, longitude: 1.001),
            Coordinate(latitude: 52.002, longitude: 1.002),
            Coordinate(latitude: 52.003, longitude: 1.003),
            Coordinate(latitude: 52.004, longitude: 1.004),
        ]

        let simplified = RoutePolyline.simplifyForDisplay(coords, tolerance: 0.0001)
        #expect(simplified.count <= 2)
        #expect(simplified.first == coords.first)
        #expect(simplified.last == coords.last)
    }

    @Test("simplifyForDisplay preserves short paths")
    func preservesShortPaths() {
        let coords = [
            Coordinate(latitude: 52.0, longitude: 1.0),
            Coordinate(latitude: 52.1, longitude: 1.1),
        ]
        let simplified = RoutePolyline.simplifyForDisplay(coords)
        #expect(simplified.count == 2)
    }

    @Test("simplifyForDisplay works on CLLocationCoordinate2D")
    func clLocationVariant() {
        let coords = [
            CLLocationCoordinate2D(latitude: 52.0, longitude: 1.0),
            CLLocationCoordinate2D(latitude: 52.001, longitude: 1.001),
            CLLocationCoordinate2D(latitude: 52.002, longitude: 1.002),
        ]
        let simplified = RoutePolyline.simplifyForDisplay(coords, tolerance: 0.0001)
        #expect(simplified.count <= 2)
    }
}
