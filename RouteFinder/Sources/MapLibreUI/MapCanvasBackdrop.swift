import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Shared map canvas backdrop matching OpenStreetMap parchment tiles.
public enum MapCanvasBackdrop {
    /// OSM-style parchment (#f2efe9).
    public static let red: Double = 0.949
    public static let green: Double = 0.937
    public static let blue: Double = 0.914

    /// SwiftUI backdrop fill for edge-to-edge map chrome.
    public static var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    #if canImport(UIKit)
    /// UIKit backdrop for WKWebView hosts.
    public static var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: 1)
    }
    #endif
}
