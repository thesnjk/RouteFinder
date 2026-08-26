import FleetServerCore
import Foundation
import Hummingbird
import DataLayer

@main
struct FleetServerApp {
    static func main() async throws {
        let config = FleetServerConfig.parse()
        let store = DiskFleetStore(storageDirectory: config.storageDirectory)
        let router = FleetRouterBuilder.buildRouter(store: store)
        let app = Application(
            router: router,
            configuration: .init(address: .hostname("0.0.0.0", port: config.port))
        )
        print("RouteFinder fleet server listening on 0.0.0.0:\(config.port)")
        try await app.runService()
    }
}
