import RouteController
import Testing

@Test func hybridRoutingPolicyPrefersOfflineWhenFlagged() {
    let policy = HybridRoutingPolicy(
        preferOfflineRouting: true,
        offlineRoutingEnabled: true,
        hasORSAPIKey: true
    )
    #expect(policy.preferredSource == .offlineTiles)
}

@Test func hybridRoutingPolicyUsesORSWhenKeyedOnline() {
    let policy = HybridRoutingPolicy(
        preferOfflineRouting: false,
        offlineRoutingEnabled: true,
        hasORSAPIKey: true
    )
    #expect(policy.preferredSource == .openRouteService)
    #expect(policy.shouldFallbackToOfflineOnORSFailure == true)
}

@Test func hybridRoutingPolicyFallsBackToOfflineWithoutKey() {
    let policy = HybridRoutingPolicy(
        preferOfflineRouting: false,
        offlineRoutingEnabled: true,
        hasORSAPIKey: false
    )
    #expect(policy.preferredSource == .offlineTiles)
}
