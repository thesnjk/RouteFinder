#if os(macOS)
import Contracts
import Foundation
import PathfindingEngine
import Testing

struct LocalWaypointOptimizerTests {
    @Test func twoOptImprovesNaiveStopOrder() {
        let origin = RoutingCoordinate(latitude: 51.50, longitude: -0.12)
        let destination = RoutingCoordinate(latitude: 51.52, longitude: -0.10)
        let stops = [
            RoutingCoordinate(latitude: 51.505, longitude: -0.08),
            RoutingCoordinate(latitude: 51.515, longitude: -0.11),
            RoutingCoordinate(latitude: 51.508, longitude: -0.105),
        ]

        let request = WaypointOptimizationRequest(
            origin: origin,
            destination: destination,
            intermediateStops: stops,
            tier: .localOnly
        )

        let result = LocalWaypointOptimizer.optimize(request: request)
        #expect(result.optimizedStopIndices.count == 3)
        #expect(Set(result.optimizedStopIndices) == Set([0, 1, 2]))
        #expect(result.usedLocalTier)
    }

    @Test func singleStopReturnsIdentityPermutation() {
        let request = WaypointOptimizationRequest(
            origin: RoutingCoordinate(latitude: 51.50, longitude: -0.12),
            destination: RoutingCoordinate(latitude: 51.52, longitude: -0.10),
            intermediateStops: [RoutingCoordinate(latitude: 51.51, longitude: -0.11)],
            tier: .localOnly
        )

        let result = LocalWaypointOptimizer.optimize(request: request)
        #expect(result.optimizedStopIndices == [0])
    }
}
#endif
