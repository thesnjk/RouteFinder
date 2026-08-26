import Contracts
import Foundation
import Network

/// Discovers fleet HTTP servers advertised on the local network via Bonjour.
public enum FleetBonjourBrowser {
    /// Scans the LAN for fleet servers for up to the given timeout.
    public static func discover(timeout: TimeInterval = 3) async -> [DiscoveredFleetServer] {
        await withCheckedContinuation { continuation in
            let state = DiscoveryState()
            let browser = NWBrowser(
                for: .bonjour(type: FleetBonjour.serviceType, domain: nil),
                using: .tcp
            )

            browser.browseResultsChangedHandler = { results, _ in
                state.updateResults(Array(results))
            }

            browser.stateUpdateHandler = { browserState in
                if case .failed = browserState {
                    browser.cancel()
                    continuation.resume(returning: [])
                }
            }

            browser.start(queue: DispatchQueue(label: "com.routefinder.fleet.bonjour.browser"))

            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                Task {
                    browser.cancel()
                    let results = state.snapshotResults()
                    var servers: [DiscoveredFleetServer] = []
                    for result in results {
                        if let server = await resolve(result) {
                            servers.append(server)
                        }
                    }
                    var seen = Set<String>()
                    let deduped = servers
                        .filter { seen.insert($0.baseURL.absoluteString).inserted }
                        .sorted {
                            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                        }
                    continuation.resume(returning: deduped)
                }
            }
        }
    }

    private static func resolve(_ result: NWBrowser.Result) async -> DiscoveredFleetServer? {
        let displayName = serviceDisplayName(from: result)
        let usesTLS = FleetBonjour.usesTLS(fromTXTRecord: txtRecord(from: result))

        return await withCheckedContinuation { (continuation: CheckedContinuation<DiscoveredFleetServer?, Never>) in
            let connection = NWConnection(to: result.endpoint, using: .tcp)
            let resolveState = ResolveState(continuation)

            connection.stateUpdateHandler = { connectionState in
                switch connectionState {
                case .ready:
                    defer { connection.cancel() }
                    guard let remote = connection.currentPath?.remoteEndpoint,
                          case .hostPort(let host, let port) = remote,
                          let url = FleetBonjour.baseURL(
                            host: hostString(from: host),
                            port: Int(port.rawValue),
                            usesTLS: usesTLS
                          ) else {
                        resolveState.resumeOnce(returning: nil)
                        return
                    }
                    resolveState.resumeOnce(returning: DiscoveredFleetServer(
                        id: "\(displayName)-\(url.absoluteString)",
                        displayName: displayName,
                        baseURL: url
                    ))
                case .failed, .cancelled:
                    connection.cancel()
                    resolveState.resumeOnce(returning: nil)
                default:
                    break
                }
            }

            connection.start(queue: DispatchQueue(label: "com.routefinder.fleet.bonjour.resolve"))

            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
                connection.cancel()
                resolveState.resumeOnce(returning: nil)
            }
        }
    }

    private static func serviceDisplayName(from result: NWBrowser.Result) -> String {
        if case .service(let name, _, _, _) = result.endpoint {
            return name
        }
        return "RouteFinder Fleet"
    }

    private static func txtRecord(from result: NWBrowser.Result) -> [String: Data]? {
        guard case .bonjour(let txtRecord) = result.metadata else { return nil }
        var record: [String: Data] = [:]
        for (key, value) in txtRecord.dictionary {
            record[key] = Data(value.utf8)
        }
        return record
    }

    private static func hostString(from host: NWEndpoint.Host) -> String {
        switch host {
        case .name(let name, _):
            return name
        case .ipv4(let address):
            return "\(address)"
        case .ipv6(let address):
            return "\(address)"
        @unknown default:
            return "localhost"
        }
    }
}

private final class ResolveState: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false
    private let continuation: CheckedContinuation<DiscoveredFleetServer?, Never>

    init(_ continuation: CheckedContinuation<DiscoveredFleetServer?, Never>) {
        self.continuation = continuation
    }

    func resumeOnce(returning value: DiscoveredFleetServer?) {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return }
        resumed = true
        continuation.resume(returning: value)
    }
}

private final class DiscoveryState: @unchecked Sendable {
    private let lock = NSLock()
    private var results: [NWBrowser.Result] = []

    func updateResults(_ results: [NWBrowser.Result]) {
        lock.lock()
        self.results = results
        lock.unlock()
    }

    func snapshotResults() -> [NWBrowser.Result] {
        lock.lock()
        defer { lock.unlock() }
        return results
    }
}
