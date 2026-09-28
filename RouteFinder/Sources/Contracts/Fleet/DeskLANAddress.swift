import Foundation

#if canImport(Darwin)
import Darwin
#endif

/// Detects a shareable office-Mac LAN IPv4 for desk / driver URL pairing.
///
/// Office PC and manual driver paste need `http://192.168.x.x:8080`, not `127.0.0.1`
/// and not a System Settings scavenger hunt for `<office-mac-ip>`.
public enum DeskLANAddress: Sendable {
    /// Fallback shown when no usable interface address is found.
    public static let placeholderURL = "http://<office-mac-ip>:8080"

    /// Picks the best shareable IPv4 from an injectable host list (unit-testable).
    ///
    /// Skips loopback and link-local (`169.254.`). Prefers RFC1918 private ranges
    /// (`10.`, `192.168.`, `172.16–31.`) when multiple candidates exist.
    public static func primaryIPv4(hosts: [String]) -> String? {
        let candidates = hosts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && isUsableIPv4($0) }
        if let privateLAN = candidates.first(where: isPrivateLAN) {
            return privateLAN
        }
        return candidates.first
    }

    /// Enumerates local IPv4 interfaces and returns the preferred LAN address.
    public static func primaryIPv4() -> String? {
        primaryIPv4(hosts: enumerateIPv4Hosts())
    }

    /// Builds `http://<host>:<port>` when host is non-empty.
    public static func fleetServerURL(host: String?, port: Int = 8080) -> String? {
        guard let host else { return nil }
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return "http://\(trimmed):\(port)"
    }

    /// Detected share URL, or ``placeholderURL`` when detection fails.
    public static func shareableFleetServerURL(port: Int = 8080) -> String {
        fleetServerURL(host: primaryIPv4(), port: port) ?? placeholderURL
    }

    /// True for IPv4 literals that are neither loopback nor link-local.
    public static func isUsableIPv4(_ host: String) -> Bool {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4,
              parts.allSatisfy({ UInt8($0) != nil }) else {
            return false
        }
        if host.hasPrefix("127.") { return false }
        if host == "0.0.0.0" { return false }
        if host.hasPrefix("169.254.") { return false }
        return true
    }

    /// True for RFC1918 private LAN addresses.
    public static func isPrivateLAN(_ host: String) -> Bool {
        if host.hasPrefix("10.") { return true }
        if host.hasPrefix("192.168.") { return true }
        let parts = host.split(separator: ".")
        guard parts.count == 4,
              parts[0] == "172",
              let second = Int(parts[1]),
              (16...31).contains(second) else {
            return false
        }
        return true
    }

    private static func enumerateIPv4Hosts() -> [String] {
        #if canImport(Darwin)
        var addresses: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else {
            return []
        }
        defer { freeifaddrs(first) }

        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let iface = pointer {
            defer { pointer = iface.pointee.ifa_next }
            let flags = Int32(iface.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0
            guard isUp, !isLoopback,
                  let addr = iface.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_INET) else {
                continue
            }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                addr,
                socklen_t(addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            if result == 0 {
                addresses.append(String(cString: hostname))
            }
        }
        return addresses
        #else
        return []
        #endif
    }
}
