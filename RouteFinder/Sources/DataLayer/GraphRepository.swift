import Contracts
import GraphCore
import Foundation

/// In-memory holder for the currently loaded routing graph.
public final class GraphRepository: @unchecked Sendable {
    private var graph: Graph?
    private let lock = NSLock()

    public init() {}

    /// Whether a graph is currently loaded.
    public var isLoaded: Bool {
        lock.lock()
        defer { lock.unlock() }
        return graph != nil
    }

    /// The currently loaded graph, if any.
    public var currentGraph: Graph? {
        lock.lock()
        defer { lock.unlock() }
        return graph
    }

    /// Stores a graph as the current routing graph.
    public func setGraph(_ graph: Graph) {
        lock.lock()
        defer { lock.unlock() }
        self.graph = graph
    }

    /// Clears the loaded graph.
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        graph = nil
    }
}
