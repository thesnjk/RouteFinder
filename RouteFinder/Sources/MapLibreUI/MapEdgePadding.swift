import Foundation

/// Edge insets for MapLibre `fitBounds` padding in screen points.
public struct MapEdgePadding: Sendable, Equatable {
    /// Padding from the top edge.
    public var top: Double
    /// Padding from the bottom edge.
    public var bottom: Double
    /// Padding from the leading edge.
    public var leading: Double
    /// Padding from the trailing edge.
    public var trailing: Double

    /// Creates map edge padding values.
    public init(top: Double, bottom: Double, leading: Double, trailing: Double) {
        self.top = top
        self.bottom = bottom
        self.leading = leading
        self.trailing = trailing
    }

    /// Default padding used when no platform chrome context is available.
    public static let defaultRouteFit = MapEdgePadding(top: 60, bottom: 60, leading: 40, trailing: 40)

    /// iOS route overview fit — leaves room for top search pill and bottom toolbar.
    public static let iosRouteOverviewFit = MapEdgePadding(top: 140, bottom: 160, leading: 40, trailing: 72)

    /// macOS map-detail fit padding. Leading/top leave room for the floating search chrome
    /// over the map; the NavigationSplitView sidebar is already outside the map view.
    public static let macOSRouteFit = MapEdgePadding(top: 120, bottom: 100, leading: 72, trailing: 64)
}
