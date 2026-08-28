import Foundation

/// Resolved HTML and load strategy for the embedded MapLibre web map.
public struct MapLoadParameters: Sendable {
    /// Generated map page HTML.
    public let html: String
    /// Base URL for `loadHTMLString` fallback loads.
    public let baseURL: URL
    /// When true on iOS, load via loopback HTTP bootstrap server (bundled JS + HTTPS style).
    public let iosUsesBootstrapServer: Bool

    public init(html: String, baseURL: URL, iosUsesBootstrapServer: Bool = false) {
        self.html = html
        self.baseURL = baseURL
        self.iosUsesBootstrapServer = iosUsesBootstrapServer
    }
}

/// OpenFreeMap and attribution constants for MapLibre rendering.
public enum MapLibreConfiguration {
    /// OpenFreeMap vector style (OSM-based, free to use with attribution).
    public static let openFreeMapStyleURL = "https://tiles.openfreemap.org/styles/liberty"

    /// MapLibre GL JS version loaded by the embedded web map.
    ///
    /// To vendor offline: copy `maplibre-gl.js` and `maplibre-gl.css` from
    /// `maplibre-gl@4.7.1` into the app target bundle (see
    /// `VENDOR_MAPLIBRE.md`), then rebuild so `Bundle.main` resolves them.
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

    /// Directory containing bundled MapLibre assets, when present.
    public static var bundledMapHTMLBaseURL: URL? {
        guard hasBundledMapLibreAssets,
              let scriptURL = bundledResourceURL(named: "maplibre-gl", extension: "js") else {
            return nil
        }
        return scriptURL.deletingLastPathComponent()
    }

    /// Resolves HTML load parameters for the embedded map (bundled file refs vs CDN).
    public static func mapLoadParameters(styleURL: String) -> MapLoadParameters {
        let scriptURL = mapLibreScriptURL
        let cssURL = mapLibreStyleSheetURL
        if scriptURL.isFileURL, cssURL.isFileURL, let baseURL = bundledMapHTMLBaseURL {
            let html = MapLibreMapHTML.page(
                styleURL: styleURL,
                scriptURL: scriptURL.lastPathComponent,
                cssURL: cssURL.lastPathComponent
            )
            #if os(iOS)
            return MapLoadParameters(html: html, baseURL: baseURL, iosUsesBootstrapServer: true)
            #else
            return MapLoadParameters(html: html, baseURL: baseURL, iosUsesBootstrapServer: false)
            #endif
        }
        let html = MapLibreMapHTML.page(
            styleURL: styleURL,
            scriptURL: scriptURL.absoluteString,
            cssURL: cssURL.absoluteString
        )
        return MapLoadParameters(
            html: html,
            baseURL: URL(string: "http://127.0.0.1/")!,
            iosUsesBootstrapServer: false
        )
    }

    public static let osmCopyrightURL = URL(string: "https://www.openstreetmap.org/copyright")!
    public static let nominatimPolicyURL = URL(string: "https://operations.osmfoundation.org/policies/nominatim/")!

    private static func bundledResourceURL(named name: String, extension ext: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: ext)
    }
}
