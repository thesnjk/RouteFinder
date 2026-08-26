import Contracts
import Foundation

#if os(macOS)
/// Publishes the fleet HTTP server on Bonjour for LAN discovery.
public final class FleetBonjourAdvertiser: NSObject, NetServiceDelegate, Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var service: NetService?

    /// Creates a Bonjour advertiser.
    public override init() {
        super.init()
    }

    /// Starts advertising the fleet server on the local network.
    public func start(port: Int, usesTLS: Bool, serviceName: String? = nil) {
        stop()
        let name = serviceName ?? Self.defaultServiceName()
        let netService = NetService(
            domain: "local.",
            type: "\(FleetBonjour.serviceType).",
            name: name,
            port: Int32(port)
        )
        var txtRecord: [String: Data] = [
            FleetBonjour.txtVersionKey: Data("1".utf8),
        ]
        if usesTLS {
            txtRecord[FleetBonjour.txtTLSKey] = Data("1".utf8)
        }
        netService.setTXTRecord(NetService.data(fromTXTRecord: txtRecord))
        netService.delegate = self
        lock.lock()
        service = netService
        lock.unlock()
        netService.publish()
        print("Bonjour: advertising \(name) on port \(port)")
    }

    /// Stops Bonjour advertisement.
    public func stop() {
        lock.lock()
        let current = service
        service = nil
        lock.unlock()
        current?.stop()
    }

    public func netServiceDidPublish(_ sender: NetService) {
        print("Bonjour: published \(sender.name) (\(FleetBonjour.serviceType))")
    }

    public func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        print("Bonjour: failed to publish service — \(errorDict)")
    }

    private static func defaultServiceName() -> String {
        let host = Host.current().localizedName ?? Host.current().name ?? "Dispatch Mac"
        return "RouteFinder Fleet (\(host))"
    }
}
#else
/// Bonjour advertisement is only supported where the fleet server executable runs.
public final class FleetBonjourAdvertiser: Sendable {
    public init() {}

    public func start(port: Int, usesTLS: Bool, serviceName: String? = nil) {}

    public func stop() {}
}
#endif
