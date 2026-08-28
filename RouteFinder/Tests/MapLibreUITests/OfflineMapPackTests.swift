import DataLayer
import Foundation
@testable import MapLibreUI
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

@Test func useLocalMapStyleDefaultsToFalseWhenUnset() {
    let defaults = UserDefaults(suiteName: "MapLibreUI_\(UUID().uuidString)")!
    defer { defaults.removePersistentDomain(forName: defaults.description) }
    #expect(VehicleProfileStore.loadUseLocalMapStyleWhenPackPresent(defaults: defaults) == false)
}

@Test func offlineMapPackStoreRejectsInvalidStyleJSON() async throws {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("MapPackInvalid_\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    try Data("not-json".utf8).write(to: tempDir.appendingPathComponent("style.json"))

    let store = OfflineMapPackStore(packDirectory: tempDir)
    #expect(await store.isPackPresent() == true)
    let url = try await store.prepareLocalStyleIfAvailable(enabled: true)
    #expect(url == nil)
    await store.stopServer()
}

@Test func mapLibreHTMLIncludesBootMapAndStyleHotReload() {
    let html = MapLibreMapHTML.page(
        styleURL: MapLibreConfiguration.openFreeMapStyleURL,
        scriptURL: MapLibreConfiguration.mapLibreScriptURL.absoluteString,
        cssURL: MapLibreConfiguration.mapLibreStyleSheetURL.absoluteString
    )
    #expect(html.contains("window.bootMap"))
    #expect(html.contains("window.setMapStyle"))
    #expect(html.contains("post('error'"))
}

@Test func bundledMapHTMLUsesScriptSrcNotInlineBody() {
    let html = MapLibreMapHTML.page(
        styleURL: MapLibreConfiguration.openFreeMapStyleURL,
        scriptURL: "maplibre-gl.js",
        cssURL: "maplibre-gl.css"
    )
    #expect(html.contains("<script src=\"maplibre-gl.js\">"))
    #expect(html.contains("<link href=\"maplibre-gl.css\""))
    #expect(!html.contains("<script>\n/*!"))
    #expect(html.count < 50_000)
}

@Test func mapLoadParametersProducesSmallHTMLWithoutInliningLibrary() {
    let params = MapLibreConfiguration.mapLoadParameters(
        styleURL: MapLibreConfiguration.openFreeMapStyleURL
    )
    #expect(params.html.count < 50_000)
    #expect(params.html.contains("window.bootMap"))
    if MapLibreConfiguration.hasBundledMapLibreAssets {
        #expect(params.html.contains("<script src=\"maplibre-gl.js\">"))
        #expect(params.baseURL.isFileURL)
        #if os(iOS)
        #expect(params.iosUsesBootstrapServer)
        #else
        #expect(!params.iosUsesBootstrapServer)
        #endif
    } else {
        #expect(params.html.contains("unpkg.com"))
        #expect(params.baseURL.absoluteString.contains("127.0.0.1"))
        #expect(!params.iosUsesBootstrapServer)
    }
}
