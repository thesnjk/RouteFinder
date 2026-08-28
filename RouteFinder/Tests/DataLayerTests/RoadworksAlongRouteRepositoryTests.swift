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
}
