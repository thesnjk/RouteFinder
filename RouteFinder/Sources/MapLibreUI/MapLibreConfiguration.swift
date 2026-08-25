import Foundation

/// OpenFreeMap and attribution constants for MapLibre rendering.
public enum MapLibreConfiguration {
    /// OpenFreeMap vector style (OSM-based, free to use with attribution).
    public static let openFreeMapStyleURL = "https://tiles.openfreemap.org/styles/liberty"

    /// MapLibre GL JS version loaded by the embedded web map.
    ///
    /// To vendor offline: copy `maplibre-gl.js` and `maplibre-gl.css` from
    /// `maplibre-gl@4.7.1` into `Sources/MapLibreUI/Resources/` (see
    /// `Resources/VENDOR_MAPLIBRE.md`), then rebuild so `Bundle.module` resolves them.
    public static let mapLibreJSVersion = "4.7.1"

    /// Custom URL scheme reserved for future WKURLSchemeHandler tile serving.
    public static let localTilesURLScheme = "routefinder-tiles"

    /// Preferred MapLibre JS URL — bundled resource when present, otherwise CDN.
    public static var mapLibreScriptURL: URL {
        if let bundled = bundledResourceURL(named: "maplibre-gl", extension: "js") {
            return bundled
        }
        return URL(string: "https://unpkg.com/maplibre-gl@\(mapLibreJSVersion)/dist/maplibre-gl.js")!
    }

    /// Preferred MapLibre CSS URL — bundled resource when present, otherwise CDN.
    public static var mapLibreStyleSheetURL: URL {
        if let bundled = bundledResourceURL(named: "maplibre-gl", extension: "css") {
            return bundled
        }
        return URL(string: "https://unpkg.com/maplibre-gl@\(mapLibreJSVersion)/dist/maplibre-gl.css")!
    }

    /// Whether MapLibre JS/CSS are available from the app bundle (no CDN required).
    public static var hasBundledMapLibreAssets: Bool {
        bundledResourceURL(named: "maplibre-gl", extension: "js") != nil
            && bundledResourceURL(named: "maplibre-gl", extension: "css") != nil
    }

    public static let osmCopyrightURL = URL(string: "https://www.openstreetmap.org/copyright")!
    public static let nominatimPolicyURL = URL(string: "https://operations.osmfoundation.org/policies/nominatim/")!

    private static func bundledResourceURL(named name: String, extension ext: String) -> URL? {
        #if SWIFT_PACKAGE
        if let url = Bundle.module.url(forResource: name, withExtension: ext) {
            return url
        }
        #endif
        return Bundle.main.url(forResource: name, withExtension: ext)
    }
}
