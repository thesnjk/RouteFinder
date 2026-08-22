import Contracts
import Foundation
import NavigationCore

/// Binds live navigation progress snapshots to SwiftUI presentation state.
@MainActor
@Observable
public final class NavigationMetricsViewModel {
    /// Latest live progress snapshot during active navigation.
    public private(set) var snapshot: NavigationProgressSnapshot?
    /// Whether live metrics should be shown instead of static route metrics.
    public var isLiveNavigationActive: Bool = false

    private let session: NavigationSession

    /// Creates a metrics view model observing a navigation session.
    public init(session: NavigationSession) {
        self.session = session
    }

    /// Updates live metrics from the navigation session.
    public func refreshFromSession() {
        snapshot = session.progressSnapshot
        isLiveNavigationActive = session.phase == .navigating && snapshot != nil
    }

    /// Applies a progress snapshot from the navigation session pipeline.
    public func apply(snapshot: NavigationProgressSnapshot?) {
        self.snapshot = snapshot
        isLiveNavigationActive = snapshot != nil
    }
}

/// Navigation session delegate that updates metrics presentation state.
@MainActor
public final class NavigationMetricsSessionAdapter: NavigationSessionDelegate {
    private let metricsViewModel: NavigationMetricsViewModel

    /// Creates an adapter for the given metrics view model.
    public init(metricsViewModel: NavigationMetricsViewModel) {
        self.metricsViewModel = metricsViewModel
    }

    public func navigationSession(_ session: NavigationSession, didUpdateProgress snapshot: NavigationProgressSnapshot) {
        metricsViewModel.apply(snapshot: snapshot)
    }

    public func navigationSession(_ session: NavigationSession, didChangePhase phase: NavigationPhase) {
        if phase != .navigating {
            metricsViewModel.isLiveNavigationActive = false
        }
        if phase == .idle || phase == .routeLoaded {
            metricsViewModel.apply(snapshot: nil)
        }
    }
}
