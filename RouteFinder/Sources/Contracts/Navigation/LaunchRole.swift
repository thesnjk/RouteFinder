import Foundation

/// First-launch role chosen after authentication.
public enum LaunchRole: String, Codable, Sendable, CaseIterable, Equatable {
    /// In-cab driver on iPhone (or Mac map for solo planning).
    case driver
    /// Fleet dispatcher on Mac (server + Dispatch console).
    case dispatcherMac
    /// Office PC operator using browser web-dispatch against the LAN fleet server.
    case officePC

    /// Short title for role cards and Settings.
    public var title: String {
        switch self {
        case .driver:
            return "Driver"
        case .dispatcherMac:
            return "Dispatcher (Mac)"
        case .officePC:
            return "Office PC"
        }
    }

    /// One-line subtitle for the role picker.
    public var subtitle: String {
        switch self {
        case .driver:
            return "iPhone navigation — route, rehearse, and receive fleet trips"
        case .dispatcherMac:
            return "Run the fleet server and push trips from the Dispatch console"
        case .officePC:
            return "Browser dispatch on a Windows or Linux PC against the office Mac"
        }
    }

    /// SF Symbol for the role card.
    public var systemImage: String {
        switch self {
        case .driver:
            return "steeringwheel"
        case .dispatcherMac:
            return "desktopcomputer"
        case .officePC:
            return "globe"
        }
    }
}
