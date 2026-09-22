import Contracts
import DataLayer
import RouteController
import Testing
@testable import UI

@Test func routeFailureMapperMapsMissingOfflineTilesToActionableCoverage() {
    let presentation = RouteFailureMapper.map(
        OfflineGraphStoreError.noTilesAvailable,
        vehicle: .ukArtic,
        isHGVMode: true
    )
    #expect(presentation.kind == .coverage)
    #expect(presentation.title == "Routing Unavailable")
    #expect(presentation.message == OfflineGraphStoreError.missingBackendUserMessage)
}

@Test func routeFailureMapperMapsGraphNotLoadedToActionableCoverage() {
    let presentation = RouteFailureMapper.map(
        RoutingError.graphNotLoaded,
        vehicle: .ukArtic,
        isHGVMode: false
    )
    #expect(presentation.kind == .coverage)
    #expect(presentation.message == OfflineGraphStoreError.missingBackendUserMessage)
}

@Test func routeFailureMapperMapsFleetProxy429ToCapCopy() {
    let presentation = RouteFailureMapper.map(
        ExternalRoutingError.serverError(status: 429, body: "Fleet ORS route daily cap reached."),
        vehicle: .ukArtic,
        isHGVMode: true
    )
    #expect(presentation.title == "Routing Cap Reached")
    #expect(presentation.message.contains("daily cap"))
}
