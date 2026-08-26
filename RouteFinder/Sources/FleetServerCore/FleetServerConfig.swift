import Foundation

/// CLI configuration for the fleet HTTP server.
public struct FleetServerConfig: Sendable {
    /// TCP port to bind (default 8080).
    public let port: Int
    /// Optional custom fleet JSON storage directory.
    public let storageDirectory: URL?
    /// Optional shared secret required on `/v1/*` routes.
    public let apiKey: String?
    /// Optional PEM certificate path for TLS.
    public let tlsCertificatePath: URL?
    /// Optional PEM private key path for TLS.
    public let tlsPrivateKeyPath: URL?
    /// Whether to advertise the server via Bonjour on the local network.
    public let advertiseBonjour: Bool

    /// Whether TLS is enabled for this server instance.
    public var usesTLS: Bool {
        tlsCertificatePath != nil && tlsPrivateKeyPath != nil
    }

    /// Creates fleet server configuration.
    public init(
        port: Int = 8080,
        storageDirectory: URL? = nil,
        apiKey: String? = nil,
        tlsCertificatePath: URL? = nil,
        tlsPrivateKeyPath: URL? = nil,
        advertiseBonjour: Bool = true
    ) {
        self.port = port
        self.storageDirectory = storageDirectory
        self.apiKey = apiKey
        self.tlsCertificatePath = tlsCertificatePath
        self.tlsPrivateKeyPath = tlsPrivateKeyPath
        self.advertiseBonjour = advertiseBonjour
    }

    /// Parses command-line arguments into server configuration.
    public static func parse(arguments: [String] = CommandLine.arguments) -> FleetServerConfig {
        var port = 8080
        var storageDirectory: URL?
        var apiKey: String?
        var tlsCertificatePath: URL?
        var tlsPrivateKeyPath: URL?
        var advertiseBonjour = true

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
            case "--api-key":
                index += 1
                if index < arguments.count {
                    apiKey = arguments[index]
                }
            case "--tls-cert":
                index += 1
                if index < arguments.count {
                    tlsCertificatePath = URL(fileURLWithPath: arguments[index])
                }
            case "--tls-key":
                index += 1
                if index < arguments.count {
                    tlsPrivateKeyPath = URL(fileURLWithPath: arguments[index])
                }
            case "--no-bonjour":
                advertiseBonjour = false
            default:
                break
            }
            index += 1
        }

        if apiKey == nil, let envKey = ProcessInfo.processInfo.environment["ROUTEFINDER_FLEET_API_KEY"] {
            let trimmed = envKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                apiKey = trimmed
            }
        }
        if tlsCertificatePath == nil,
           let envCert = ProcessInfo.processInfo.environment["ROUTEFINDER_FLEET_TLS_CERT"] {
            tlsCertificatePath = URL(fileURLWithPath: envCert)
        }
        if tlsPrivateKeyPath == nil,
           let envKey = ProcessInfo.processInfo.environment["ROUTEFINDER_FLEET_TLS_KEY"] {
            tlsPrivateKeyPath = URL(fileURLWithPath: envKey)
        }

        return FleetServerConfig(
            port: port,
            storageDirectory: storageDirectory,
            apiKey: apiKey,
            tlsCertificatePath: tlsCertificatePath,
            tlsPrivateKeyPath: tlsPrivateKeyPath,
            advertiseBonjour: advertiseBonjour
        )
    }
}
