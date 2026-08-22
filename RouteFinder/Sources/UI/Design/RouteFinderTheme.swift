import SwiftUI

/// Spacing constants for consistent layout.
enum RFSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

/// Typography styles.
enum RFFont {
    static let sectionTitle = Font.headline.weight(.semibold)
    static let body = Font.body
    static let caption = Font.caption
    static let summary = Font.subheadline.weight(.medium)
}

/// Semantic colors for routing UI.
enum RFColor {
    static let hazard = Color.orange
    static let route = Color.blue
    static let start = Color.green
    static let end = Color.red
    static let waypoint = Color.orange
}
