import Foundation
import RouteController
import Testing

@Suite("Fleet ORS routing factory")
struct FleetORSRoutingFactoryTests {
    @Test func usesFleetProxyWhenRemoteServerEnabled() throws {
        let url = URL(string: "http://192.168.1.10:8080")!
        #expect(
            FleetORSRoutingFactory.usesFleetProxy(
                useRemoteFleetServer: true,
                fleetServerURL: url
            )
        )
        #expect(
            !FleetORSRoutingFactory.usesFleetProxy(
                useRemoteFleetServer: false,
                fleetServerURL: url
            )
        )
        #expect(
            !FleetORSRoutingFactory.usesFleetProxy(
                useRemoteFleetServer: true,
                fleetServerURL: nil
            )
        )
    }

    @Test func makeRoutingClientSucceedsForFleetProxyWithoutLocalKey() throws {
        let fleetURL = URL(string: "http://127.0.0.1:8080")!
        let client = try FleetORSRoutingFactory.makeRoutingClient(
            localORSAPIKey: "",
            useRemoteFleetServer: true,
            fleetServerURL: fleetURL,
            fleetAPIKey: "fleet-secret"
        )
        #expect(client != nil)
    }

    @Test func makeRoutingClientRequiresLocalKeyWhenNotUsingProxy() throws {
        #expect(throws: ExternalRoutingError.self) {
            _ = try FleetORSRoutingFactory.makeRoutingClient(
                localORSAPIKey: "",
                useRemoteFleetServer: false,
                fleetServerURL: nil,
                fleetAPIKey: nil
            )
        }
    }

    @Test func fleetProxyPeliasBaseURLAppendsProxyPath() throws {
        let fleetURL = URL(string: "http://192.168.1.10:8080")!
        let peliasBase = FleetORSRoutingFactory.fleetProxyPeliasBaseURL(fleetServerURL: fleetURL)
        #expect(peliasBase.absoluteString == "http://192.168.1.10:8080/v1/proxy/pelias/v1")
    }

    @Test func makeGeocoderSucceedsForFleetProxyWithoutLocalKey() throws {
        let fleetURL = URL(string: "http://127.0.0.1:8080")!
        let geocoder = FleetORSRoutingFactory.makeGeocoder(
            localORSAPIKey: "",
            useRemoteFleetServer: true,
            fleetServerURL: fleetURL,
            fleetAPIKey: "fleet-secret"
        )
        #expect(geocoder != nil)
    }

    @Test func hasCloudRoutingCapabilityWithoutLocalKeyWhenFleetProxyEnabled() throws {
        let fleetURL = URL(string: "http://127.0.0.1:8080")!
        let usesProxy = FleetORSRoutingFactory.usesFleetProxy(
            useRemoteFleetServer: true,
            fleetServerURL: fleetURL
        )
        #expect(usesProxy)
        let geocoder = FleetORSRoutingFactory.makeGeocoder(
            localORSAPIKey: "",
            useRemoteFleetServer: true,
            fleetServerURL: fleetURL,
            fleetAPIKey: nil
        )
        #expect(geocoder != nil)
    }
}
