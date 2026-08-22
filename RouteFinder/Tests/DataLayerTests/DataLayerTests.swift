import Contracts
import DataLayer
import Foundation
import GraphCore
import Testing

@Test func tileExportAndLoad() async throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TileTest_\(UUID().uuidString)")
    let graph = SyntheticGraphBuilder.makeGrid(rows: 5, cols: 5)
    try TileExporter.exportGraph(graph, to: tempDir)

    let tileFiles = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
    #expect(!tileFiles.isEmpty)
}

@Test func edgeDecodesWithMissingOptionalKeys() throws {
    let json = """
    {"from":"A","to":"B","distance":100,"speed":50}
    """
    let edge = try JSONDecoder().decode(Edge.self, from: Data(json.utf8))
    #expect(edge.from == "A")
    #expect(edge.to == "B")
    #expect(edge.hgvRestricted == false)
    #expect(edge.hasCamera == false)
    #expect(edge.roadType == .unknown)
}

@Test func geocodeSuggestionDecodesMissingIsLocal() throws {
    let json = """
    {"id":"1","title":"Main St","subtitle":"Norwich","coordinate":{"latitude":52.6,"longitude":1.3}}
    """
    let suggestion = try JSONDecoder().decode(GeocodeSuggestion.self, from: Data(json.utf8))
    #expect(suggestion.isLocal == false)
}

@Test func graphTileDecodesMissingEdgeFlags() throws {
    let json = """
    {"h3Index":{"value":123},"nodes":[],"edges":[{"from":"A","to":"B","distance":10,"speed":30}]}
    """
    let tile = try JSONDecoder().decode(GraphTile.self, from: Data(json.utf8))
    #expect(tile.edges.count == 1)
    #expect(tile.edges[0].isOneWay == false)
    #expect(tile.edges[0].hazmatRestricted == false)
}

@Test func geocoderCacheDeletesCorruptEntry() async throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("GeocodeCache_\(UUID().uuidString)")
    let cache = GeocoderCache(cacheDirectory: tempDir)
    let key = GeocoderCache.cacheKey(query: "test", near: Coordinate(latitude: 52.6, longitude: 1.3))
    let url = tempDir.appendingPathComponent("\(key).json")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    try Data("not-json".utf8).write(to: url)

    let result = await cache.suggestions(forKey: key)
    #expect(result == nil)
    #expect(FileManager.default.fileExists(atPath: url.path) == false)
}

@Test func orsAPIKeyPersistence() {
    let defaults = UserDefaults(suiteName: "RouteFinderTests-\(UUID().uuidString)")!
    VehicleProfileStore.saveORSAPIKey("test-key-abc", defaults: defaults)
    #expect(VehicleProfileStore.loadORSAPIKey(defaults: defaults) == "test-key-abc")
}
