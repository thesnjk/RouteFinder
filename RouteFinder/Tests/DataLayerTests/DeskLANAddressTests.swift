import Contracts
import Foundation
import Testing

@Suite("DeskLANAddress")
struct DeskLANAddressTests {
    @Test func prefersPrivateLANOverLinkLocalAndPublic() {
        let host = DeskLANAddress.primaryIPv4(hosts: [
            "127.0.0.1",
            "169.254.12.34",
            "8.8.8.8",
            "192.168.1.42",
            "10.0.0.5",
        ])
        #expect(host == "192.168.1.42")
    }

    @Test func prefers10WhenNo192() {
        #expect(
            DeskLANAddress.primaryIPv4(hosts: ["169.254.1.1", "10.1.2.3"]) == "10.1.2.3"
        )
    }

    @Test func accepts172PrivateRange() {
        #expect(DeskLANAddress.isPrivateLAN("172.16.0.1"))
        #expect(DeskLANAddress.isPrivateLAN("172.31.255.1"))
        #expect(!DeskLANAddress.isPrivateLAN("172.15.0.1"))
        #expect(!DeskLANAddress.isPrivateLAN("172.32.0.1"))
        #expect(
            DeskLANAddress.primaryIPv4(hosts: ["172.20.1.9", "8.8.4.4"]) == "172.20.1.9"
        )
    }

    @Test func skipsLoopbackAndEmpty() {
        #expect(DeskLANAddress.primaryIPv4(hosts: []) == nil)
        #expect(DeskLANAddress.primaryIPv4(hosts: ["127.0.0.1", "0.0.0.0"]) == nil)
        #expect(DeskLANAddress.primaryIPv4(hosts: ["  ", "not-an-ip"]) == nil)
    }

    @Test func fleetServerURLFormatsAndPlaceholder() {
        #expect(
            DeskLANAddress.fleetServerURL(host: "192.168.1.10") == "http://192.168.1.10:8080"
        )
        #expect(DeskLANAddress.fleetServerURL(host: nil) == nil)
        #expect(DeskLANAddress.fleetServerURL(host: "  ") == nil)
        #expect(DeskLANAddress.placeholderURL == "http://<office-mac-ip>:8080")
        #expect(
            DeskLANAddress.fleetServerURL(host: "10.0.0.2", port: 9090) == "http://10.0.0.2:9090"
        )
    }
}
