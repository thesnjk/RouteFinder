import Contracts
import GraphCore
import Foundation

/// Actor that loads and caches routing graphs from CSV files.
public actor GraphLoader {
    private var cachedGraph: Graph?
    private var cachedNodesPath: String?
    private var cachedEdgesPath: String?

    public init() {}

    /// Whether a graph is currently loaded.
    public var isLoaded: Bool {
        cachedGraph != nil
    }

    /// The currently loaded graph.
    public var graph: Graph? {
        cachedGraph
    }

    /// Loads a graph from CSV paths, using cache if paths match.
    public func load(nodesPath: String, edgesPath: String) async throws -> Graph {
        if cachedNodesPath == nodesPath,
           cachedEdgesPath == edgesPath,
           let cached = cachedGraph {
            return cached
        }

        let graph = try await Graph.loadFromCSV(nodesPath: nodesPath, edgesPath: edgesPath)
        cachedGraph = graph
        cachedNodesPath = nodesPath
        cachedEdgesPath = edgesPath
        return graph
    }

    /// Sets a pre-built graph directly (e.g. from synthetic builder).
    public func setGraph(_ graph: Graph) {
        cachedGraph = graph
        cachedNodesPath = nil
        cachedEdgesPath = nil
    }

    /// Clears the cached graph.
    public func clear() {
        cachedGraph = nil
        cachedNodesPath = nil
        cachedEdgesPath = nil
    }
}
