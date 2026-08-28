import Contracts
import DataLayer
import Foundation
import Testing

struct RoadworksDiskCacheTests {
    @Test func storeAndLoadRoundTrip() async {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RouteFinderRoadworksTests-\(UUID().uuidString)", isDirectory: true)
        let cache = RoadworksDiskCache(cacheDirectory: directory)
        let sites = [
            RoadworkSite(id: "node/1", label: "Test works", latitude: 51.5, longitude: -0.1),
        ]
        await cache.store(sites, forKey: "test-key")
        let loaded = await cache.load(key: "test-key")
        #expect(loaded?.count == 1)
        #expect(loaded?.first?.label == "Test works")
    }
}
