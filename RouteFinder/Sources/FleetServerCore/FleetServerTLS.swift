import Foundation
import NIOSSL

/// Builds TLS configuration for the fleet HTTP server.
public enum FleetServerTLS {
    /// Loads a server TLS configuration from PEM certificate and private key files.
    public static func makeServerConfiguration(
        certificatePath: URL,
        privateKeyPath: URL
    ) throws -> TLSConfiguration {
        let certificates = try NIOSSLCertificate.fromPEMFile(certificatePath.path)
        guard let certificate = certificates.first else {
            throw FleetServerTLSError.missingCertificate
        }
        let privateKey = try NIOSSLPrivateKey(file: privateKeyPath.path, format: .pem)
        return TLSConfiguration.makeServerConfiguration(
            certificateChain: [.certificate(certificate)],
            privateKey: .privateKey(privateKey)
        )
    }
}

/// Errors loading fleet server TLS material from disk.
public enum FleetServerTLSError: Error, Sendable, LocalizedError {
    case missingCertificate
    case missingPrivateKey

    public var errorDescription: String? {
        switch self {
        case .missingCertificate:
            return "TLS certificate PEM file did not contain a certificate."
        case .missingPrivateKey:
            return "TLS private key PEM file did not contain a key."
        }
    }
}
