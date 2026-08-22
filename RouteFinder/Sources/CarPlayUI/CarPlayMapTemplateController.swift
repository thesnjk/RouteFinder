#if os(iOS)
import CarPlay
import Foundation

/// Manages the root `CPMapTemplate` canvas for CarPlay navigation.
@MainActor
public final class CarPlayMapTemplateController: NSObject, CPMapTemplateDelegate {
    /// Root map template for CarPlay rendering.
    public let rootTemplate: CPMapTemplate

    /// Creates a map template controller.
    public override init() {
        rootTemplate = CPMapTemplate()
        super.init()
        rootTemplate.mapDelegate = self
    }

    public func mapTemplate(_ mapTemplate: CPMapTemplate, panWith direction: CPMapTemplate.PanDirection) {
        // Pan events are handled by the system map; no custom MapLibre canvas on CarPlay.
    }

    public func mapTemplateDidShowPanningInterface(_ mapTemplate: CPMapTemplate) {}

    public func mapTemplateDidDismissPanningInterface(_ mapTemplate: CPMapTemplate) {}
}
#endif
