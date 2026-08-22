#if os(macOS)
import AppKit
import CoreGraphics

/// Sizes macOS sheets to fit inside the host window instead of the full screen.
@MainActor
enum MacSheetMetrics {
    /// Returns a size that fits within the main window with margin for title bar and centering.
    
    static func fittedSize(
        widthRatio: CGFloat = 0.36,
        minWidth: CGFloat = 440,
        maxWidth: CGFloat = 520,
        heightRatio: CGFloat = 0.72,
        minHeight: CGFloat = 420,
        verticalMargin: CGFloat = 56
    ) -> CGSize {
        let parent = NSApp.mainWindow?.contentLayoutRect
            ?? NSApp.windows.first(where: { $0.isMainWindow })?.contentLayoutRect
            ?? NSScreen.main?.visibleFrame
            ?? CGRect(x: 0, y: 0, width: 1200, height: 800)

        let width = min(maxWidth, max(minWidth, parent.width * widthRatio))
        let height = min(parent.height - verticalMargin, max(minHeight, parent.height * heightRatio))
        return CGSize(width: width, height: height)
    }
}
#endif
