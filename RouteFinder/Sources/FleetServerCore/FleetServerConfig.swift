import Foundation

/// CLI configuration for the fleet HTTP server.
public struct FleetServerConfig: Sendable {
    /// TCP port to bind (default 8080).
    public let port: Int
    /// Optional custom fleet JSON storage directory.
    public let storageDirectory: URL?

    /// Creates fleet server configuration.
    public init(port: Int = 8080, storageDirectory: URL? = nil) {
        self.port = port
        self.storageDirectory = storageDirectory
    }

    /// Parses command-line arguments into server configuration.
    public static func parse(arguments: [String] = CommandLine.arguments) -> FleetServerConfig {
        var port = 8080
        var storageDirectory: URL?
        var index = 1
        while index < arguments.count {
            switch arguments[index] {
            case "--port":
                index += 1
                if index < arguments.count, let parsed = Int(arguments[index]) {
                    port = parsed
                }
            case "--storage-dir":
                index += 1
                if index < arguments.count {
                    storageDirectory = URL(fileURLWithPath: arguments[index], isDirectory: true)
                }
            default:
                break
            }
            index += 1
        }
        return FleetServerConfig(port: port, storageDirectory: storageDirectory)
    }
}
