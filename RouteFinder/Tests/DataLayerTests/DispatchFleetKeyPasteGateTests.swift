import Contracts
import Foundation
import Testing

@Suite("DispatchFleetKeyPasteGate")
struct DispatchFleetKeyPasteGateTests {
    @Test func localDiskDoesNotNeedPaste() {
        #expect(
            !DispatchFleetKeyPasteGate.needsPaste(isRemoteFleet: false, healthOk: nil)
        )
        #expect(
            !DispatchFleetKeyPasteGate.needsPaste(isRemoteFleet: false, healthOk: false)
        )
        #expect(
            !DispatchFleetKeyPasteGate.needsPaste(isRemoteFleet: false, healthOk: true)
        )
    }

    @Test func remoteNotConnectedNeedsPaste() {
        #expect(DispatchFleetKeyPasteGate.needsPaste(isRemoteFleet: true, healthOk: nil))
        #expect(DispatchFleetKeyPasteGate.needsPaste(isRemoteFleet: true, healthOk: false))
    }

    @Test func remoteConnectedHidesPaste() {
        #expect(
            !DispatchFleetKeyPasteGate.needsPaste(isRemoteFleet: true, healthOk: true)
        )
    }
}
