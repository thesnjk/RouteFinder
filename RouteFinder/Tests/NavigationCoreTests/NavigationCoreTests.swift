import Contracts
import CoreLocation
import NavigationCore
import Testing

@Test("Route polyline projector finds closest segment")
func routePolylineProjectorFindsSegment() {
    let coordinates = [
        Coordinate(latitude: 51.0, longitude: -1.0),
        Coordinate(latitude: 51.001, longitude: -1.0),
        Coordinate(latitude: 51.002, longitude: -1.0),
    ]
    let geometry = RouteGeometryCanonicalizer.process(coordinates, simulationStepMeters: 50)
    let projector = RoutePolylineProjector()
    let point = Coordinate(latitude: 51.001, longitude: -1.0001)
    let result = projector.project(
        point: point,
        spine: geometry,
        crossTrackThresholdMeters: 100
    )
    #expect(result != nil)
    #expect(result!.arcLengthMeters > 0)
}

@Test("Route geometry splitter produces traversed and remaining paths")
func routeGeometrySplitterSplitsAtArcLength() {
    let coords = [
        CLLocationCoordinate2D(latitude: 51.0, longitude: -1.0),
        CLLocationCoordinate2D(latitude: 51.01, longitude: -1.0),
        CLLocationCoordinate2D(latitude: 51.02, longitude: -1.0),
    ]
    let cumulative: [Double] = [0, 1111, 2222]
    let split = RouteGeometrySplitter.split(
        displayCoordinates: coords,
        cumulativeLengths: cumulative,
        splitArcLengthMeters: 1111
    )
    #expect(split.traversedPath.count >= 2)
    #expect(split.remainingPath.count >= 2)
    #expect(split.splitArcLengthMeters == 1111)
}

@Test("Route progress calculator computes remaining distance and ETA")
func routeProgressCalculatorComputesRemaining() {
    let calculator = RouteProgressCalculator()
    let snapshot = calculator.compute(
        arcLengthMeters: 500,
        totalLengthMeters: 1000,
        currentSpeedMps: 10,
        staticTotalTimeSeconds: 100
    )
    #expect(snapshot.remainingDistanceMeters == 500)
    #expect(snapshot.progressFraction == 0.5)
    #expect(snapshot.remainingETASeconds == 50)
}
