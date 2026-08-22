import Contracts
import CoreLocation
import Foundation
import Testing
@testable import RouteController

@Test func encodedPolylineDecoderEmptyString() {
    let result = EncodedPolylineDecoder.decode("", precision: 5)
    #expect(result.isEmpty)
}

@Test func encodedPolylineDecoderPrecision5KnownSample() {
    // Google polyline example: three points in California
    let encoded = "_p~iF~ps|U_ulLnnqC_mqNvxq`@"
    let result = EncodedPolylineDecoder.decode(encoded, precision: 5)

    #expect(result.count == 3)
    #expect(abs(result[0].latitude - 38.5) < 0.001)
    #expect(abs(result[0].longitude - (-120.2)) < 0.001)
    #expect(abs(result[1].latitude - 40.7) < 0.001)
    #expect(abs(result[1].longitude - (-120.95)) < 0.001)
    #expect(abs(result[2].latitude - 43.252) < 0.001)
    #expect(abs(result[2].longitude - (-126.453)) < 0.001)
}

@Test func encodedPolylineDecoderPrecision6Sample() {
    // Norwich city centre pair encoded at polyline6 precision
    let encoded = encodePolyline(
        coordinates: [
            Coordinate(latitude: 52.628, longitude: 1.296),
            Coordinate(latitude: 52.632, longitude: 1.301),
        ],
        precision: 6
    )
    let result = EncodedPolylineDecoder.decode(encoded, precision: 6)

    #expect(result.count == 2)
    #expect(abs(result[0].latitude - 52.628) < 1e-5)
    #expect(abs(result[0].longitude - 1.296) < 1e-5)
    #expect(abs(result[1].latitude - 52.632) < 1e-5)
    #expect(abs(result[1].longitude - 1.301) < 1e-5)
}

@Test func encodedPolylineDecoderPrecision5Vs6Differs() {
    let coordinate = Coordinate(latitude: 52.628, longitude: 1.296)
    let encoded5 = encodePolyline(coordinates: [coordinate], precision: 5)
    let encoded6 = encodePolyline(coordinates: [coordinate], precision: 6)

    #expect(encoded5 != encoded6)

    let decoded5 = EncodedPolylineDecoder.decode(encoded5, precision: 5)
    let decoded6 = EncodedPolylineDecoder.decode(encoded6, precision: 6)
    #expect(abs(decoded5[0].latitude - coordinate.latitude) < 1e-4)
    #expect(abs(decoded6[0].latitude - coordinate.latitude) < 1e-5)
}

@Test func externalRoutingErrorNoRouteFriendlyMessage() {
    let error = ExternalRoutingError.noRoute(reason: "No path could be found")
    #expect(error.errorDescription == ExternalRoutingError.hgvNoRouteMessage)
}

@Test func routingEngineDefaultsToOpenRouteService() {
    #expect(RoutingEngine.defaultEngine == .openRouteService)
    #expect(RoutingEngine.openRouteService.isAvailable)
    #expect(!RoutingEngine.valhalla.isAvailable)
}

@Test func encodedPolylineDecoderDecodeToMapCoordinatesPrecision5() {
    let encoded = "_p~iF~ps|U_ulLnnqC_mqNvxq`@"
    let result = EncodedPolylineDecoder.decodeToMapCoordinates(encoded, precision: 5)

    #expect(result.count == 3)
    #expect(abs(result[0].latitude - 38.5) < 0.001)
    #expect(abs(result[0].longitude - (-120.2)) < 0.001)
}

@Test func encodedPolylineDecoderDecodeToMapCoordinatesPrecision6RoundTrip() {
    let coordinates = [
        Coordinate(latitude: 52.628, longitude: 1.296),
        Coordinate(latitude: 52.632, longitude: 1.301),
    ]
    let encoded = encodePolyline(coordinates: coordinates, precision: 6)
    let decoded = EncodedPolylineDecoder.decodeToMapCoordinates(encoded, precision: 6)

    #expect(decoded.count == 2)
    #expect(abs(decoded[0].latitude - 52.628) < 1e-5)
    #expect(abs(decoded[0].longitude - 1.296) < 1e-5)
    #expect(abs(decoded[1].latitude - 52.632) < 1e-5)
    #expect(abs(decoded[1].longitude - 1.301) < 1e-5)
}

@Test func encodedPolylineDecoderDecodeToMapCoordinatesDoubleFactor() {
    let coordinate = Coordinate(latitude: 52.628, longitude: 1.296)
    let encoded5 = encodePolyline(coordinates: [coordinate], precision: 5)
    let encoded6 = encodePolyline(coordinates: [coordinate], precision: 6)

    let decoded5 = EncodedPolylineDecoder.decodeToMapCoordinates(encoded5, precision: 1e5)
    let decoded6 = EncodedPolylineDecoder.decodeToMapCoordinates(encoded6, precision: 1e6)

    #expect(abs(decoded5[0].latitude - coordinate.latitude) < 1e-4)
    #expect(abs(decoded6[0].latitude - coordinate.latitude) < 1e-5)
}

@Test func encodedPolylineDecoderLargePolylineSmokeTest() {
    var coordinates: [Coordinate] = []
    coordinates.reserveCapacity(2000)
    for index in 0..<2000 {
        coordinates.append(
            Coordinate(
                latitude: 52.0 + Double(index) * 0.0001,
                longitude: 1.0 + Double(index) * 0.0001
            )
        )
    }

    let encoded = encodePolyline(coordinates: coordinates, precision: 6)
    let decoded = EncodedPolylineDecoder.decode(encoded, precision: 6)

    #expect(decoded.count == coordinates.count)
    #expect(abs(decoded.last!.latitude - coordinates.last!.latitude) < 1e-5)
    #expect(abs(decoded.last!.longitude - coordinates.last!.longitude) < 1e-5)
}

// MARK: - Test helpers

private func encodePolyline(coordinates: [Coordinate], precision: Int) -> String {
    let factor = pow(10.0, Double(precision))
    var lastLat = 0
    var lastLon = 0
    var output = ""

    for coordinate in coordinates {
        let lat = Int(round(coordinate.latitude * factor))
        let lon = Int(round(coordinate.longitude * factor))
        output += encodeComponent(lat - lastLat)
        output += encodeComponent(lon - lastLon)
        lastLat = lat
        lastLon = lon
    }

    return output
}

private func encodeComponent(_ value: Int) -> String {
    var v = value < 0 ? ~(value << 1) : (value << 1)
    var result = ""
    while v >= 0x20 {
        result.append(Character(UnicodeScalar((0x20 | (v & 0x1F)) + 63)!))
        v >>= 5
    }
    result.append(Character(UnicodeScalar(v + 63)!))
    return result
}
