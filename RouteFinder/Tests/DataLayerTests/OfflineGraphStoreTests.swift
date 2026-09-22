import Contracts
import DataLayer
import Foundation
import GraphCore
import Testing

@Test func offlineGraphStoreLoadsSyntheticTilesWithoutNetwork() async throws {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("OfflineGraph_\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let graph = SyntheticGraphBuilder.makeGrid(rows: 4, cols: 4, spacingMeters: 400)
    try TileExporter.exportGraph(graph, to: tempDir, resolution: H3Grid.defaultResolution)

    let store = DiskOfflineGraphStore(
        tilesDirectory: tempDir,
        tileBaseURL: nil,
        session: URLSession(configuration: .ephemeral)
    )

    try await store.loadLocalTiles()
    #expect(await store.loadedTileCount() > 0)
    #expect(await store.currentGraph()?.nodeCount ?? 0 > 0)

    let matched = try await store.match(latitude: 52.6, longitude: 1.3)
    #expect(matched != nil)

    try await store.ensureCorridor(
        minLat: 52.55,
        maxLat: 52.70,
        minLon: 1.20,
        maxLon: 1.40
    )
    #expect(await store.currentGraph()?.edgeCount ?? 0 > 0)
}

@Test func offlineGraphStoreEnsureCorridorReportsMonotonicProgress() async throws {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("OfflineProgress_\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let graph = SyntheticGraphBuilder.makeGrid(rows: 4, cols: 4, spacingMeters: 400)
    try TileExporter.exportGraph(graph, to: tempDir, resolution: H3Grid.defaultResolution)

    let store = DiskOfflineGraphStore(
        tilesDirectory: tempDir,
        tileBaseURL: nil,
        session: URLSession(configuration: .ephemeral)
    )

    let expectedCells = H3Grid.cellsCovering(
        minLat: 52.55,
        maxLat: 52.70,
        minLon: 1.20,
        maxLon: 1.40,
        resolution: H3Grid.defaultResolution
    )
    #expect(!expectedCells.isEmpty)

    final class ProgressBox: @unchecked Sendable {
        var events: [(completed: Int, total: Int)] = []
    }
    let box = ProgressBox()

    try await store.ensureCorridor(
        minLat: 52.55,
        maxLat: 52.70,
        minLon: 1.20,
        maxLon: 1.40,
        onProgress: { completed, total in
            box.events.append((completed, total))
        }
    )

    #expect(box.events.count == expectedCells.count)
    #expect(box.events.first?.total == expectedCells.count)
    #expect(box.events.allSatisfy { $0.total == expectedCells.count })
    for index in 1..<box.events.count {
        #expect(box.events[index].completed >= box.events[index - 1].completed)
    }
    #expect(box.events.last?.completed == expectedCells.count)
}

@Test func offlineGraphStoreMatchDetailedSnapsNearNode() async throws {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("OfflineMatch_\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let graph = SyntheticGraphBuilder.makeGrid(rows: 3, cols: 3, spacingMeters: 250)
    try TileExporter.exportGraph(graph, to: tempDir)

    let store = DiskOfflineGraphStore(tilesDirectory: tempDir, tileBaseURL: nil)
    try await store.loadLocalTiles()

    let detailed = try await store.matchDetailed(latitude: 52.601, longitude: 1.301)
    #expect(detailed != nil)
    #expect(detailed!.snapDistanceMeters < 500)
}

@Test func diskGeocodeCacheRetainsLastNHits() async throws {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("GeocodeHits_\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let cache = DiskGeocodeCache(cacheDirectory: tempDir, capacity: 2)
    let a = GeocodeSuggestion(
        id: "1",
        title: "Norwich",
        subtitle: "UK",
        coordinate: Coordinate(latitude: 52.63, longitude: 1.30)
    )
    let b = GeocodeSuggestion(
        id: "2",
        title: "Cambridge",
        subtitle: "UK",
        coordinate: Coordinate(latitude: 52.20, longitude: 0.12)
    )
    let c = GeocodeSuggestion(
        id: "3",
        title: "Ipswich",
        subtitle: "UK",
        coordinate: Coordinate(latitude: 52.05, longitude: 1.15)
    )

    await cache.store(query: "Norwich", suggestions: [a])
    await cache.store(query: "Cambridge", suggestions: [b])
    await cache.store(query: "Ipswich", suggestions: [c])

    #expect(await cache.count() == 2)
    #expect(await cache.suggestions(matching: "Ipswich")?.first?.title == "Ipswich")
    #expect(await cache.suggestions(matching: "Cambridge")?.first?.title == "Cambridge")
    #expect(await cache.suggestions(matching: "Norwich") == nil)
}

@Test func h3GridCellsCoveringIncludesCorners() {
    let cells = H3Grid.cellsCovering(
        minLat: 52.55,
        maxLat: 52.70,
        minLon: 1.20,
        maxLon: 1.40,
        resolution: 7
    )
    #expect(!cells.isEmpty)
    let corner = H3Grid.cell(for: Coordinate(latitude: 52.55, longitude: 1.20), resolution: 7)
    #expect(cells.contains(corner))
}

@Test func tileServerURLPersistence() {
    let defaults = UserDefaults(suiteName: "RouteFinderOfflineTests-\(UUID().uuidString)")!
    VehicleProfileStore.saveTileServerURL("https://cdn.example.com/tiles/", defaults: defaults)
    #expect(VehicleProfileStore.loadTileServerURL(defaults: defaults) == "https://cdn.example.com/tiles/")
    VehicleProfileStore.saveOfflineRoutingEnabled(true, defaults: defaults)
    VehicleProfileStore.savePreferOfflineRouting(true, defaults: defaults)
    #expect(VehicleProfileStore.loadOfflineRoutingEnabled(defaults: defaults) == true)
    #expect(VehicleProfileStore.loadPreferOfflineRouting(defaults: defaults) == true)
}
