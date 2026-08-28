import Contracts
import Foundation
import Testing

@Test func hazardOverlayBuilderEmptyCollection() {
    let json = HazardOverlayBuilder.geoJSON(from: [])
    #expect(json == HazardOverlayBuilder.emptyFeatureCollection)
}

@Test func hazardOverlayBuilderProducesValidFeatureCollectionForTwoHazards() throws {
    let hazards = [
        HazardEvent(
            id: "h1",
            latitude: 52.1,
            longitude: -0.5,
            radiusMeters: 90,
            type: .closure,
            severity: .moderate,
            validFrom: Date(),
            validTo: Date().addingTimeInterval(3600),
            source: "crowd:test"
        ),
        HazardEvent(
            id: "h2",
            latitude: 52.2,
            longitude: -0.6,
            radiusMeters: 90,
            type: .traffic,
            severity: .moderate,
            validFrom: Date(),
            validTo: Date().addingTimeInterval(3600),
            source: "crowd:test"
        ),
    ]

    let json = HazardOverlayBuilder.geoJSON(from: hazards)
    #expect(json.contains("\"type\":\"FeatureCollection\""))
    #expect(json.contains("\"features\":["))
    let data = try #require(json.data(using: .utf8))
    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    let features = object?["features"] as? [[String: Any]]
    #expect(features?.count == 2)
}
