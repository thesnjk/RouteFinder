import Foundation

#if canImport(Darwin)
import Darwin
#endif

/// Errors starting the fleet HTTP listener.
public enum FleetServerStartupError: Error, CustomStringConvertible, Equatable {
    /// The configured TCP port is already bound by another process.
    case addressAlreadyInUse(port: Int)

    public var description: String {
        switch self {
        case .addressAlreadyInUse(let port):
            """
            Port \(port) is already in use. Another RouteFinderFleetServer (or other app) is listening.
            Fix: stop the other process (lsof -nP -iTCP:\(port) -sTCP:LISTEN) or run with --port <other>.
            """
        }
    }
}

/// Checks whether a TCP port can be bound on all interfaces.
public enum FleetPortAvailability {
    /// Throws ``FleetServerStartupError/addressAlreadyInUse(port:)`` when the port is taken.
    public static func ensureAvailable(port: Int) throws {
        #if canImport(Darwin)
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return }
        defer { close(fd) }

        var reuse: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout.size(ofValue: reuse)))

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(UInt16(port).bigEndian)
        addr.sin_addr.s_addr = INADDR_ANY.bigEndian

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if bindResult != 0, errno == EADDRINUSE {
            throw FleetServerStartupError.addressAlreadyInUse(port: port)
        }
        #endif
    }
}
