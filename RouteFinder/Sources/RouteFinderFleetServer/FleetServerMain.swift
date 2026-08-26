import FleetServerCore
import Foundation
import Hummingbird
import HummingbirdCore
import HummingbirdTLS
import DataLayer

@main
struct FleetServerApp {
    static func main() async throws {
        let config = FleetServerConfig.parse()
        let store = DiskFleetStore(storageDirectory: config.storageDirectory)
        let router = FleetRouterBuilder.buildRouter(store: store, apiKey: config.apiKey)

        let serverBuilder: HTTPServerBuilder
        if let certificatePath = config.tlsCertificatePath,
           let privateKeyPath = config.tlsPrivateKeyPath {
            let tlsConfiguration = try FleetServerTLS.makeServerConfiguration(
                certificatePath: certificatePath,
                privateKeyPath: privateKeyPath
            )
            serverBuilder = try HTTPServerBuilder.tls(.http1(), tlsConfiguration: tlsConfiguration)
            print("RouteFinder fleet server listening with TLS on 0.0.0.0:\(config.port)")
        } else {
            serverBuilder = HTTPServerBuilder.http1()
            print("RouteFinder fleet server listening on 0.0.0.0:\(config.port)")
        }

        if config.apiKey != nil {
            print("Fleet API key authentication enabled.")
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
