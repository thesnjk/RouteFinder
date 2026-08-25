import Foundation
import MapLibreUI
import Testing

@Test func mapLibreConfigurationFallsBackToCDN() {
    #expect(MapLibreConfiguration.mapLibreJSVersion == "4.7.1")
    #expect(MapLibreConfiguration.mapLibreScriptURL.absoluteString.contains("maplibre-gl"))
    #expect(MapLibreConfiguration.mapLibreStyleSheetURL.absoluteString.contains("maplibre-gl"))
    #expect(MapLibreConfiguration.localTilesURLScheme == "routefinder-tiles")
}

@Test func offlineMapPackStoreReportsMissingPack() async {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("MapPack_\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }
    try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

    let store = OfflineMapPackStore(packDirectory: tempDir)
    #expect(await store.isPackPresent() == false)
    let status = await store.status(useLocalWhenPresent: true)
    #expect(status.packPresent == false)
    #expect(status.message.contains("No pack"))
}

@Test func offlineMapPackStoreServesLocalStyle() async throws {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("MapPackReady_\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    let style = """
    {"version":8,"name":"test","sources":{},"layers":[]}
    """
    try Data(style.utf8).write(to: tempDir.appendingPathComponent("style.json"))

    let store = OfflineMapPackStore(packDirectory: tempDir)
    #expect(await store.isPackPresent() == true)
    let url = try await store.prepareLocalStyleIfAvailable(enabled: true)
    #expect(url != nil)
    #expect(url!.absoluteString.contains("127.0.0.1"))
    #expect(url!.path.hasSuffix("style.json"))
    await store.stopServer()
}
