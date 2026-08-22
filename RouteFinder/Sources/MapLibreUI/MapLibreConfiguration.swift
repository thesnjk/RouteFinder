import Foundation

/// OpenFreeMap and attribution constants for MapLibre rendering.
public enum MapLibreConfiguration {
    /// OpenFreeMap vector style (OSM-based, free to use with attribution).
    public static let openFreeMapStyleURL = "https://tiles.openfreemap.org/styles/liberty"

    /// MapLibre GL JS version loaded by the embedded web map.
    public static let mapLibreJSVersion = "4.7.1"

    public static var mapLibreScriptURL: URL {
        URL(string: "https://unpkg.com/maplibre-gl@\(mapLibreJSVersion)/dist/maplibre-gl.js")!
    }

    public static var mapLibreStyleSheetURL: URL {
        URL(string: "https://unpkg.com/maplibre-gl@\(mapLibreJSVersion)/dist/maplibre-gl.css")!
    }

    public static let osmCopyrightURL = URL(string: "https://www.openstreetmap.org/copyright")!
    public static let nominatimPolicyURL = URL(string: "https://operations.osmfoundation.org/policies/nominatim/")!
}
