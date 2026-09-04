import FleetServerCore
import Foundation
import Hummingbird
import HummingbirdCore
import HummingbirdTLS
import DataLayer

@main
struct FleetServerApp {
    static func main() async {
        do {
            try await run()
        } catch let error as FleetServerStartupError {
            fputs("RouteFinder fleet server: \(error)\n", stderr)
            exit(1)
        } catch {
            fputs("RouteFinder fleet server failed: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func run() async throws {
        let config = FleetServerConfig.parse()
        try FleetPortAvailability.ensureAvailable(port: config.port)

        let store = DiskFleetStore(storageDirectory: config.storageDirectory)
        let eventHub = FleetEventHub()
        let proxyMeter = FleetProxyUsageMeter(budget: config.proxyBudget)
        let router = FleetRouterBuilder.buildRouter(
            store: store,
            apiKey: config.apiKey,
            orsAPIKey: config.orsAPIKey,
            eventHub: eventHub,
            proxyMeter: proxyMeter
        )

        let serverBuilder: HTTPServerBuilder
        if let certificatePath = config.tlsCertificatePath,
           let privateKeyPath = config.tlsPrivateKeyPath {
            let tlsConfiguration = try FleetServerTLS.makeServerConfiguration(
                certificatePath: certificatePath,
                privateKeyPath: privateKeyPath
            )
            serverBuilder = try HTTPServerBuilder.tls(.http1(), tlsConfiguration: tlsConfiguration)
            print("RouteFinder fleet server starting with TLS on 0.0.0.0:\(config.port)")
        } else {
            serverBuilder = HTTPServerBuilder.http1()
            print("RouteFinder fleet server starting on 0.0.0.0:\(config.port)")
        }

        if config.apiKey != nil {
            print("Fleet API key authentication enabled.")
        }
        if let ors = config.orsAPIKey, !ors.isEmpty {
            print("ORS proxy enabled (operator-paid). Caps: \(config.proxyBudget.routeDailyCap) routes / \(config.proxyBudget.geocodeDailyCap) geocodes per day.")
        } else {
            print("ORS proxy disabled — pass --ors-key or ORS_API_KEY so drivers need no HeiGIT keys.")
        }

        let bonjourAdvertiser = FleetBonjourAdvertiser()
        if config.advertiseBonjour {
            bonjourAdvertiser.start(port: config.port, usesTLS: config.usesTLS)
        }
        defer { bonjourAdvertiser.stop() }

        let app = Application(
            router: router,
            server: serverBuilder,
            configuration: .init(address: .hostname("0.0.0.0", port: config.port))
        )
        try await app.runService()
    }
}
