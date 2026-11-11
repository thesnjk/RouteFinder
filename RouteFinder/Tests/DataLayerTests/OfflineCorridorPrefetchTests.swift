import Contracts
import DataLayer
import Foundation
import Testing

@Test func offlineCorridorPrefetchPaddedBoundingBoxPadsPolyline() {
    let coordinates = [
        Coordinate(latitude: 52.60, longitude: 1.20),
        Coordinate(latitude: 52.70, longitude: 1.40)
    ]
    let pad = OfflineCorridorPrefetch.corridorPadDegrees
    let box = OfflineCorridorPrefetch.paddedBoundingBox(from: coordinates, padDegrees: pad)
    #expect(box != nil)
    #expect(box?.minLat == 52.60 - pad)
    #expect(box?.maxLat == 52.70 + pad)
    #expect(box?.minLon == 1.20 - pad)
    #expect(box?.maxLon == 1.40 + pad)
}

@Test func offlineCorridorPrefetchEmptyCoordinatesReturnsNil() {
    #expect(OfflineCorridorPrefetch.paddedBoundingBox(from: []) == nil)
}

@Test func offlineCorridorPrefetchCapMatchesEastAnglia() {
    let east = OfflineDownloadRegion.eastAnglia.boundingBox
    let eastBox = GeographicBoundingBox(
        minLat: east.minLat,
        maxLat: east.maxLat,
        minLon: east.minLon,
        maxLon: east.maxLon
    )
    #expect(OfflineCorridorPrefetch.isWithinAutoPrefetchCap(eastBox))

    // Midlands is a larger manual pack — must stay outside auto-prefetch cap.
    let midlands = OfflineDownloadRegion.midlands.boundingBox
    let midlandsBox = GeographicBoundingBox(
        minLat: midlands.minLat,
        maxLat: midlands.maxLat,
        minLon: midlands.minLon,
        maxLon: midlands.maxLon
    )
    #expect(!OfflineCorridorPrefetch.isWithinAutoPrefetchCap(midlandsBox))

    let uk = OfflineDownloadRegion.ukCorridor.boundingBox
    let ukBox = GeographicBoundingBox(
        minLat: uk.minLat,
        maxLat: uk.maxLat,
        minLon: uk.minLon,
        maxLon: uk.maxLon
    )
    #expect(!OfflineCorridorPrefetch.isWithinAutoPrefetchCap(ukBox))
}

@Test func offlineCorridorPrefetchNorfolkDemoWithinCap() {
    let coords = [
        Coordinate(latitude: 52.55, longitude: 1.20),
        Coordinate(latitude: 52.70, longitude: 1.40)
    ]
    guard let box = OfflineCorridorPrefetch.paddedBoundingBox(from: coords) else {
        Issue.record("Expected bbox")
        return
    }
    #expect(OfflineCorridorPrefetch.isWithinAutoPrefetchCap(box))
}
