import DataLayer
import RouteController
import Testing

@Test func hybridRoutingPolicyPrefersOfflineWhenFlaggedAndTilesExist() {
    let policy = HybridRoutingPolicy(
        preferOfflineRouting: true,
        offlineRoutingEnabled: true,
        hasORSAPIKey: true,
        hasOfflineTilesAvailable: true
    )
    #expect(policy.preferredSource == .offlineTiles)
}

@Test func hybridRoutingPolicyUsesORSWhenKeyedEvenIfOfflineToggleOnWithoutTiles() {
    let policy = HybridRoutingPolicy(
        preferOfflineRouting: false,
        offlineRoutingEnabled: true,
        hasORSAPIKey: true,
        hasOfflineTilesAvailable: false
    )
    #expect(policy.preferredSource == .openRouteService)
    #expect(policy.shouldFallbackToOfflineOnORSFailure == false)
    #expect(policy.lacksAnyRoutingBackend == false)
}

@Test func hybridRoutingPolicyPreferOfflineWithoutTilesFallsBackToORS() {
    let policy = HybridRoutingPolicy(
        preferOfflineRouting: true,
        offlineRoutingEnabled: true,
        hasORSAPIKey: true,
        hasOfflineTilesAvailable: false
    )
    #expect(policy.preferredSource == .openRouteService)
}

@Test func hybridRoutingPolicyFallsBackToOfflineWithoutKeyWhenTilesExist() {
    let policy = HybridRoutingPolicy(
        preferOfflineRouting: false,
        offlineRoutingEnabled: true,
        hasORSAPIKey: false,
        hasOfflineTilesAvailable: true
    )
    #expect(policy.preferredSource == .offlineTiles)
}

@Test func hybridRoutingPolicyLacksBackendWithoutKeyOrTiles() {
    let policy = HybridRoutingPolicy(
        preferOfflineRouting: false,
        offlineRoutingEnabled: true,
        hasORSAPIKey: false,
        hasOfflineTilesAvailable: false
    )
    #expect(policy.lacksAnyRoutingBackend)
    #expect(policy.preferredSource == .openRouteService)
    #expect(policy.canUseOffline == false)
}

@Test func hybridRoutingPolicyOfflineDisabledIgnoresTiles() {
    let policy = HybridRoutingPolicy(
        preferOfflineRouting: true,
        offlineRoutingEnabled: false,
        hasORSAPIKey: false,
        hasOfflineTilesAvailable: true
    )
    #expect(policy.canUseOffline == false)
    #expect(policy.lacksAnyRoutingBackend)
}
