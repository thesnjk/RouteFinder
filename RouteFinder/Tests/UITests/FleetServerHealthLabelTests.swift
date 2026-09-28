import DataLayer
import Foundation
import Testing
@testable import UI

@Suite("FleetServerHealthLabel")
struct FleetServerHealthLabelTests {
    @Test func authFailureIsNotOffline() {
        let label = FleetServerHealthLabel.status(
            healthOk: true,
            authSucceeded: false,
            authErrorMessage: "Fleet API key rejected. Check the shared key with the operator."
        )
        #expect(label.hasPrefix("Auth failed"))
        #expect(!label.contains("Offline"))
        #expect(!FleetServerHealthLabel.isConnected(healthOk: true, authSucceeded: false))
    }

    @Test func connectedIncludesVersion() {
        let label = FleetServerHealthLabel.status(
            healthOk: true,
            authSucceeded: true,
            version: "1"
        )
        #expect(label == "Connected · v1")
    }

    @Test func offlineWhenHealthFails() {
        #expect(
            FleetServerHealthLabel.status(healthOk: false, authSucceeded: false) == "Offline"
        )
    }

    @Test func classifiesHTTPFleetStore401AsAuthFailure() {
        let error = HTTPFleetStoreError.serverError(status: 401, body: #"{"error":"Unauthorized"}"#)
        #expect(FleetServerHealthLabel.isAuthFailure(error))
        #expect(!FleetServerHealthLabel.isAuthFailure(HTTPFleetStoreError.invalidResponse))
    }
}
