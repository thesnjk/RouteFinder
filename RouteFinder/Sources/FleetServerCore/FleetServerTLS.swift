import Foundation
import NIOSSL

/// Builds TLS configuration for the fleet HTTP server.
public enum FleetServerTLS {
    /// Loads a server TLS configuration from PEM certificate and private key files.
    public static func makeServerConfiguration(
        certificatePath: URL,
        privateKeyPath: URL
    ) throws -> TLSConfiguration {
        let certificate = try NIOSSLCertificate(file: certificatePath.path, format: .pem)
        let privateKey = try NIOSSLPrivateKey(file: privateKeyPath.path, format: .pem)
        return TLSConfiguration.makeServerConfiguration(
            certificateChain: [.certificate(certificate)],
            privateKey: .privateKey(privateKey)
        )
    }
}
