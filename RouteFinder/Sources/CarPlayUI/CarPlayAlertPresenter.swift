#if os(iOS)
import CarPlay
import Contracts
import Foundation

/// Presents CarPlay alert dialogs for invalid vehicle registry lookups.
@MainActor
public final class CarPlayAlertPresenter {
    private weak var interfaceController: CPInterfaceController?

    /// Creates an alert presenter bound to a CarPlay interface controller.
    public init(interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
    }

    /// Presents an invalid vehicle profile alert with retry and fallback actions.
    public func presentInvalidVehicleProfile(
        message: String,
        onRetry: @escaping () -> Void,
        onUseDefault: @escaping () -> Void
    ) {
        let retry = CPAlertAction(title: "Retry Lookup", style: .default) { _ in onRetry() }
        let fallback = CPAlertAction(title: "Use Default Profile", style: .default) { _ in onUseDefault() }
        let titleVariants = message.isEmpty
            ? ["Vehicle Not Found"]
            : ["Vehicle Not Found", message]
        let template = CPAlertTemplate(
            titleVariants: titleVariants,
            actions: [retry, fallback]
        )
        interfaceController?.presentTemplate(template, animated: true) { _, _ in }
    }

    /// Presents an advisory hours-of-service / rest alert (tachograph remains legal record).
    public func presentHosAdvisory(title: String, message: String) {
        let dismiss = CPAlertAction(title: "OK", style: .default) { _ in }
        let template = CPAlertTemplate(
            titleVariants: [title, message],
            actions: [dismiss]
        )
        interfaceController?.presentTemplate(template, animated: true) { _, _ in }
    }
}
#endif
