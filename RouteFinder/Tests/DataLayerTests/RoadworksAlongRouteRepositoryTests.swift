import Contracts
import DataLayer
import Foundation
import Testing

struct RoadworksAlongRouteRepositoryTests {
    @Test func parseFixtureExtractsConstructionNodes() throws {
        let json = """
        {
          "elements": [
            {
              "type": "node",
              "id": 42,
              "lat": 51.51,
              "lon": -0.12,
              "tags": { "name": "A1 roadworks" }
            }
          ]
        }
        """
        let sites = try RoadworksAlongRouteRepository.parseFixture(data: Data(json.utf8))
        #expect(sites.count == 1)
        #expect(sites.first?.label == "A1 roadworks")
        #expect(sites.first?.id == "node/42")
    }

    @Test func routeCacheKeyIsStableForSampledCoordinates() {
        let route = [
            Coordinate(latitude: 51.5, longitude: -0.1),
            Coordinate(latitude: 51.6, longitude: -0.05),
        ]
        let key1 = RoadworksAlongRouteRepository.routeCacheKey(route)
        let key2 = RoadworksAlongRouteRepository.routeCacheKey(route)
        #expect(key1 == key2)
        #expect(key1.hasSuffix("|roadworks"))
    }
}
