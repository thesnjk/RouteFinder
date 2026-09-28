import Contracts
import Foundation
import Testing

@Suite("DispatchPushGate")
struct DispatchPushGateTests {
    @Test func requiresVehicleStopsRemoteAndConnected() {
        #expect(
            DispatchPushGate.canPush(
                hasVehicle: true,
                hasResolvedStops: true,
                isRemoteFleet: true,
                healthOk: true
            )
        )
    }

    @Test func localDiskBlocksPush() {
        #expect(
            !DispatchPushGate.canPush(
                hasVehicle: true,
                hasResolvedStops: true,
                isRemoteFleet: false,
                healthOk: true
            )
        )
        #expect(
            DispatchPushGate.isBlockedByFleetHealth(
                hasVehicle: true,
                hasResolvedStops: true,
                isRemoteFleet: false,
                healthOk: true
            )
        )
    }

    @Test func remoteOfflineOrAuthFailedBlocksPush() {
        #expect(
            !DispatchPushGate.canPush(
                hasVehicle: true,
                hasResolvedStops: true,
                isRemoteFleet: true,
                healthOk: false
            )
        )
        #expect(
            DispatchPushGate.isBlockedByFleetHealth(
                hasVehicle: true,
                hasResolvedStops: true,
                isRemoteFleet: true,
                healthOk: false
            )
        )
    }

    @Test func missingStopsStillBlocksEvenWhenConnected() {
        #expect(
            !DispatchPushGate.canPush(
                hasVehicle: true,
                hasResolvedStops: false,
                isRemoteFleet: true,
                healthOk: true
            )
        )
        #expect(
            !DispatchPushGate.isBlockedByFleetHealth(
                hasVehicle: true,
                hasResolvedStops: false,
                isRemoteFleet: true,
                healthOk: true
            )
        )
    }

    @Test func missingVehicleBlocksWithoutFleetHealthHint() {
        #expect(
            !DispatchPushGate.canPush(
                hasVehicle: false,
                hasResolvedStops: true,
                isRemoteFleet: true,
                healthOk: true
            )
        )
        #expect(
            !DispatchPushGate.isBlockedByFleetHealth(
                hasVehicle: false,
                hasResolvedStops: true,
                isRemoteFleet: true,
                healthOk: true
            )
        )
    }
}
