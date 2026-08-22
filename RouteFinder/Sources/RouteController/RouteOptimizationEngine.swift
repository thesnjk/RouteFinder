import Contracts
import CoreLocation
import DataLayer
import Foundation
import GraphCore

// MARK: - Route Optimization Engine

/// Dual-tier TSP solver: ORS Vroom network tier with in-actor Haversine 2-opt fallback.
public actor RouteOptimizationEngine {
    private static let maxMatrixCacheEntries = 20

    private let orsAPIKey: String?
    private let storedVehicleProfile: VehicleSpecificationProfile?
    private let requestTimeoutSeconds: TimeInterval
    private let session: URLSession
    private var matrixCache: [String: [[Double]]] = [:]
    private var matrixCacheOrder: [String] = []
    private var fullMatrixCache: [String: RoutingMatrix] = [:]

    /// Creates a route optimization engine.
    public init(
        orsAPIKey: String? = VehicleProfileStore.loadORSAPIKey(),
        vehicleProfile: VehicleSpecificationProfile? = nil,
        requestTimeoutSeconds: TimeInterval = 30,
        session: URLSession = SecureURLSession.shared
    ) {
        self.orsAPIKey = orsAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.storedVehicleProfile = vehicleProfile
        self.requestTimeoutSeconds = requestTimeoutSeconds
        self.session = session
    }

  /// Legacy initializer preserving HGV mode selection without a specification profile.
    public init(
        orsAPIKey: String? = VehicleProfileStore.loadORSAPIKey(),
        isHGVMode: Bool = true,
        requestTimeoutSeconds: TimeInterval = 30,
        session: URLSession = SecureURLSession.shared
    ) {
        self.orsAPIKey = orsAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.requestTimeoutSeconds = requestTimeoutSeconds
        self.session = session
        if isHGVMode {
            self.storedVehicleProfile = VehicleSpecificationProfile.routingDefault(
                vehicleClass: .heavyGoodsVehicle
            )
        } else {
            self.storedVehicleProfile = VehicleSpecificationProfile.routingDefault(
                vehicleClass: .passengerCar
            )
        }
    }

    /// Optimizes a full coordinate sequence with cloud Vroom and automatic local fallback.
    public func optimizeSequence(
        startPoint: CLLocationCoordinate2D,
        waypoints: [CLLocationCoordinate2D],
        endPoint: CLLocationCoordinate2D,
        vehicleProfile: VehicleSpecificationProfile,
        constraints: RouteSequenceConstraints? = nil,
        tier: OptimizationTier = .localPreferred
    ) async throws -> [CLLocationCoordinate2D] {
        guard waypoints.count > 1 else {
            return [startPoint] + waypoints + [endPoint]
        }

        let resolvedTier = effectiveTier(for: tier)
        switch resolvedTier {
        case .localOnly:
            return await runLocalSequence(
                startPoint: startPoint,
                waypoints: waypoints,
                endPoint: endPoint
            )
        case .cloudOnly:
            return try await runCloudSequenceWithFallback(
                startPoint: startPoint,
                waypoints: waypoints,
                endPoint: endPoint,
                vehicleProfile: vehicleProfile,
                constraints: constraints,
                allowFallback: false
            ).sequence
        case .localPreferred:
            #if os(macOS)
            if orsAPIKey?.isEmpty != false {
                return await runLocalSequence(
                    startPoint: startPoint,
                    waypoints: waypoints,
                    endPoint: endPoint
                )
            }
            return try await runCloudSequenceWithFallback(
                startPoint: startPoint,
                waypoints: waypoints,
                endPoint: endPoint,
                vehicleProfile: vehicleProfile,
                constraints: constraints,
                allowFallback: true
            ).sequence
            #else
            return try await runCloudSequenceWithFallback(
                startPoint: startPoint,
                waypoints: waypoints,
                endPoint: endPoint,
                vehicleProfile: vehicleProfile,
                constraints: constraints,
                allowFallback: true
            ).sequence
            #endif
        }
    }

    /// Optimizes waypoint sequence using cloud Vroom with automatic local fallback.
    public func optimize(_ request: WaypointOptimizationRequest) async throws -> WaypointOptimizationResult {
        guard request.intermediateStops.count > 1 else {
            return WaypointOptimizationResult(
                optimizedStopIndices: Array(0..<request.intermediateStops.count),
                usedLocalTier: false
            )
        }

        let vehicleProfile = storedVehicleProfile
            ?? VehicleSpecificationProfile.routingDefault(
                vehicleClass: request.vehicleCapacityTonnes ?? 0 >= 3.5 ? .heavyGoodsVehicle : .passengerCar,
                grossWeightKilograms: (request.vehicleCapacityTonnes ?? 44.0) * 1000.0
            )

        let constraints = Self.legacyConstraints(from: request)
        let start = CLLocationCoordinate2D(
            latitude: request.origin.latitude,
            longitude: request.origin.longitude
        )
        let end = CLLocationCoordinate2D(
            latitude: request.destination.latitude,
            longitude: request.destination.longitude
        )
        let waypoints = request.intermediateStops.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }

        let resolvedTier = effectiveTier(for: request.tier)
        let usedLocalOnly = resolvedTier == .localOnly
            || (resolvedTier == .localPreferred && orsAPIKey?.isEmpty != false)

        var usedLocalTier = false
        do {
            let sequence: [CLLocationCoordinate2D]
            if usedLocalOnly {
                usedLocalTier = true
                sequence = await runLocalSequence(
                    startPoint: start,
                    waypoints: waypoints,
                    endPoint: end,
                    providedMatrix: request.distanceMatrix
                )
            } else {
                let cloudResult = try await runCloudSequenceWithFallback(
                    startPoint: start,
                    waypoints: waypoints,
                    endPoint: end,
                    vehicleProfile: vehicleProfile,
                    constraints: constraints,
                    allowFallback: resolvedTier != .cloudOnly,
                    providedMatrix: request.distanceMatrix
                )
                usedLocalTier = cloudResult.usedLocalTier
                sequence = cloudResult.sequence
            }

            let optimizedWaypoints = Array(sequence.dropFirst().dropLast())
            let indices = Self.permutationIndices(
                original: waypoints,
                optimized: optimizedWaypoints
            )
            return WaypointOptimizationResult(
                optimizedStopIndices: indices,
                usedLocalTier: usedLocalTier
            )
        } catch {
            if let matrix = request.distanceMatrix {
                let sequence = await runLocalSequence(
                    startPoint: start,
                    waypoints: waypoints,
                    endPoint: end,
                    providedMatrix: matrix
                )
                let optimizedWaypoints = Array(sequence.dropFirst().dropLast())
                let indices = Self.permutationIndices(
                    original: waypoints,
                    optimized: optimizedWaypoints
                )
                return WaypointOptimizationResult(optimizedStopIndices: indices, usedLocalTier: true)
            }
            throw error
        }
    }

    private struct SequenceOptimizationResult: Sendable {
        let sequence: [CLLocationCoordinate2D]
        let usedLocalTier: Bool
    }

    private func effectiveTier(for tier: OptimizationTier) -> OptimizationTier {
        #if os(macOS)
        return tier
        #else
        switch tier {
        case .localOnly, .localPreferred:
            return .cloudOnly
        case .cloudOnly:
            return .cloudOnly
        }
        #endif
    }

    private func runCloudSequenceWithFallback(
        startPoint: CLLocationCoordinate2D,
        waypoints: [CLLocationCoordinate2D],
        endPoint: CLLocationCoordinate2D,
        vehicleProfile: VehicleSpecificationProfile,
        constraints: RouteSequenceConstraints?,
        allowFallback: Bool,
        providedMatrix: [[Double]]? = nil
    ) async throws -> SequenceOptimizationResult {
        guard let orsAPIKey, !orsAPIKey.isEmpty else {
            if allowFallback {
                let sequence = await runLocalSequence(
                    startPoint: startPoint,
                    waypoints: waypoints,
                    endPoint: endPoint,
                    providedMatrix: providedMatrix
                )
                return SequenceOptimizationResult(sequence: sequence, usedLocalTier: true)
            }
            throw ExternalRoutingError.notConfigured
        }

        let routingWaypoints = waypoints.map { RoutingCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
        let payload = VroomPayloadBuilder.buildRequest(
            start: startPoint,
            end: endPoint,
            waypoints: routingWaypoints,
            vehicleProfile: vehicleProfile,
            constraints: constraints
        )

        do {
            let client = try VroomNetworkClient(
                apiKey: orsAPIKey,
                session: session,
                requestTimeoutSeconds: requestTimeoutSeconds
            )
            let orderedIndices = try await client.optimize(payload: payload, stopCount: waypoints.count)
            let reordered = orderedIndices.map { waypoints[$0] }
            let sequence = [startPoint] + reordered + [endPoint]
            return SequenceOptimizationResult(sequence: sequence, usedLocalTier: false)
        } catch {
            if allowFallback, shouldFallback(for: error) {
                let sequence = await runLocalSequence(
                    startPoint: startPoint,
                    waypoints: waypoints,
                    endPoint: endPoint,
                    providedMatrix: providedMatrix
                )
                return SequenceOptimizationResult(sequence: sequence, usedLocalTier: true)
            }
            throw error
        }
    }

    private func shouldFallback(for error: Error) -> Bool {
        if let routingError = error as? ExternalRoutingError {
            switch routingError {
            case .serverError(let status, _):
                return status == 429 || status >= 500 || (400...499).contains(status)
            case .noRoute:
                return true
            default:
                return false
            }
        }
        return true
    }

    private func runLocalSequence(
        startPoint: CLLocationCoordinate2D,
        waypoints: [CLLocationCoordinate2D],
        endPoint: CLLocationCoordinate2D,
        providedMatrix: [[Double]]? = nil
    ) async -> [CLLocationCoordinate2D] {
        let allCoordinates = [startPoint] + waypoints + [endPoint]
        let routingCoordinates = allCoordinates.map {
            RoutingCoordinate(latitude: $0.latitude, longitude: $0.longitude)
        }

        let matrix: [[Double]]
        if let providedMatrix {
            matrix = providedMatrix
        } else {
            matrix = await distanceMatrix(for: routingCoordinates)
        }

        let orderedIndices = LocalTwoOptEngine.optimize(
            stopCount: waypoints.count,
            matrix: matrix
        )

        let reordered = orderedIndices.map { waypoints[$0] }
        return [startPoint] + reordered + [endPoint]
    }

    private func distanceMatrix(for coordinates: [RoutingCoordinate]) async -> [[Double]] {
        let cacheKey = matrixCacheKey(for: coordinates)
        if let cached = matrixCache[cacheKey] {
            return cached
        }

        let matrix: [[Double]]
        if let orsAPIKey, !orsAPIKey.isEmpty,
           let orsMatrix = await fetchORSMatrix(coordinates: coordinates, apiKey: orsAPIKey) {
            matrix = orsMatrix
        } else {
            matrix = LocalTwoOptEngine.haversineMatrix(for: coordinates)
        }

        storeMatrixInCache(key: cacheKey, matrix: matrix)
        return matrix
    }

    private func fetchORSMatrix(
        coordinates: [RoutingCoordinate],
        apiKey: String
    ) async -> [[Double]]? {
        guard let baseURL = URL(string: ORSAPIDefaults.baseURL) else { return nil }
        let isHGV = storedVehicleProfile?.vehicleClass != .passengerCar
        let path = isHGV ? ORSAPIDefaults.hgvMatrixPath : ORSAPIDefaults.carMatrixPath
        let matrixURL = baseURL.appending(path: path)

        var request = URLRequest(url: matrixURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(ORSAPIDefaults.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = requestTimeoutSeconds

        let payload = MatrixPayloadGenerator.buildPayload(coordinates: coordinates)
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        guard request.isSecureHTTPS else { return nil }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let envelope = try JSONDecoder().decode(ORSMatrixEnvelope.self, from: data)
            return MatrixPayloadGenerator.parseResponse(envelope, locationCount: coordinates.count)?.primaryCostMatrix
        } catch {
            return nil
        }
    }

    /// Fetches a full duration and distance matrix for the given coordinates.
    public func fetchRoutingMatrix(
        coordinates: [RoutingCoordinate],
        vehicleProfile: VehicleSpecificationProfile
    ) async -> RoutingMatrix {
        let cacheKey = matrixCacheKey(for: coordinates) + ".full"
        if let cached = fullMatrixCache[cacheKey] {
            return cached
        }

        let matrix: RoutingMatrix
        if let orsAPIKey, !orsAPIKey.isEmpty,
           let orsMatrix = await fetchFullORSMatrix(
               coordinates: coordinates,
               apiKey: orsAPIKey,
               vehicleProfile: vehicleProfile
           ) {
            matrix = orsMatrix
        } else {
            let haversine = LocalTwoOptEngine.haversineMatrix(for: coordinates)
            matrix = RoutingMatrix(
                durations: haversine,
                distances: haversine,
                locationIndices: Array(0..<coordinates.count)
            )
        }

        storeFullMatrixInCache(key: cacheKey, matrix: matrix)
        return matrix
    }

    /// Optimizes intermediate stop order for a coordinator request.
    public func optimizeCoordinatorRequest(
        _ request: RouteOptimizationCoordinatorRequest
    ) async throws -> RouteOptimizationCoordinatorResult {
        let matrixStart = CFAbsoluteTimeGetCurrent()
        let allCoordinates = [request.origin]
            + request.intermediateStops
            + [request.destination]

        let routingMatrix = await fetchRoutingMatrix(
            coordinates: allCoordinates,
            vehicleProfile: request.vehicleProfile
        )
        let matrixFetchDurationMs = Int((CFAbsoluteTimeGetCurrent() - matrixStart) * 1000)

        let optimizeStart = CFAbsoluteTimeGetCurrent()
        let start = CLLocationCoordinate2D(
            latitude: request.origin.latitude,
            longitude: request.origin.longitude
        )
        let end = CLLocationCoordinate2D(
            latitude: request.destination.latitude,
            longitude: request.destination.longitude
        )
        let waypoints = request.intermediateStops.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }

        let resolvedTier = effectiveTier(for: request.tier)
        var usedLocalTier = false
        var indices: [Int]

        if resolvedTier == .localOnly || (resolvedTier == .localPreferred && orsAPIKey?.isEmpty != false) {
            usedLocalTier = true
            indices = LocalTwoOptEngine.optimize(
                stopCount: waypoints.count,
                matrix: routingMatrix.primaryCostMatrix
            )
        } else {
            do {
                let cloudResult = try await runCloudSequenceWithFallback(
                    startPoint: start,
                    waypoints: waypoints,
                    endPoint: end,
                    vehicleProfile: request.vehicleProfile,
                    constraints: nil,
                    allowFallback: resolvedTier != .cloudOnly,
                    providedMatrix: routingMatrix.primaryCostMatrix
                )
                usedLocalTier = cloudResult.usedLocalTier
                let optimizedWaypoints = Array(cloudResult.sequence.dropFirst().dropLast())
                indices = Self.permutationIndices(original: waypoints, optimized: optimizedWaypoints)
            } catch {
                usedLocalTier = true
                indices = LocalTwoOptEngine.optimize(
                    stopCount: waypoints.count,
                    matrix: routingMatrix.primaryCostMatrix
                )
            }
        }

        let optimizationDurationMs = Int((CFAbsoluteTimeGetCurrent() - optimizeStart) * 1000)

        return RouteOptimizationCoordinatorResult(
            optimizedStopIndices: indices,
            usedLocalTier: usedLocalTier,
            matrixFetchDurationMs: matrixFetchDurationMs,
            optimizationDurationMs: optimizationDurationMs
        )
    }

    private func fetchFullORSMatrix(
        coordinates: [RoutingCoordinate],
        apiKey: String,
        vehicleProfile: VehicleSpecificationProfile
    ) async -> RoutingMatrix? {
        guard let baseURL = URL(string: ORSAPIDefaults.baseURL) else { return nil }
        let isHGV = vehicleProfile.vehicleClass != .passengerCar
        let path = isHGV ? ORSAPIDefaults.hgvMatrixPath : ORSAPIDefaults.carMatrixPath
        let matrixURL = baseURL.appending(path: path)

        var request = URLRequest(url: matrixURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(ORSAPIDefaults.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = requestTimeoutSeconds
        request.httpBody = try? JSONSerialization.data(
            withJSONObject: MatrixPayloadGenerator.buildPayload(coordinates: coordinates)
        )

        guard request.isSecureHTTPS else { return nil }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let envelope = try JSONDecoder().decode(ORSMatrixEnvelope.self, from: data)
            return MatrixPayloadGenerator.parseResponse(envelope, locationCount: coordinates.count)
        } catch {
            return nil
        }
    }

    private func storeFullMatrixInCache(key: String, matrix: RoutingMatrix) {
        fullMatrixCache[key] = matrix
        if fullMatrixCache.count > Self.maxMatrixCacheEntries {
            if let firstKey = fullMatrixCache.keys.first {
                fullMatrixCache.removeValue(forKey: firstKey)
            }
        }
    }

    private func matrixCacheKey(for coordinates: [RoutingCoordinate]) -> String {
        coordinates
            .map { String(format: "%.5f,%.5f", $0.latitude, $0.longitude) }
            .joined(separator: "|")
    }

    private func storeMatrixInCache(key: String, matrix: [[Double]]) {
        matrixCache[key] = matrix
        matrixCacheOrder.removeAll { $0 == key }
        matrixCacheOrder.append(key)
        while matrixCacheOrder.count > Self.maxMatrixCacheEntries {
            let evicted = matrixCacheOrder.removeFirst()
            matrixCache.removeValue(forKey: evicted)
        }
    }

    private static func legacyConstraints(
        from request: WaypointOptimizationRequest
    ) -> RouteSequenceConstraints? {
        var stopWindows: [GeoCoordinateKey: RouteSequenceConstraints.TimeWindow] = [:]
        if let optimizationWaypoints = request.optimizationWaypoints {
            for waypoint in optimizationWaypoints {
                if let window = waypoint.timeWindow {
                    let key = GeoCoordinateKey(waypoint.coordinate)
                    stopWindows[key] = RouteSequenceConstraints.TimeWindow(
                        start: window.start,
                        end: window.end
                    )
                }
            }
        }

        var breakDurations: [TimeInterval]? = nil
        if let breakRules = request.breakRules, !breakRules.isEmpty {
            breakDurations = breakRules.map { TimeInterval($0.serviceDurationSeconds) }
        }

        if stopWindows.isEmpty, breakDurations == nil {
            return nil
        }
        return RouteSequenceConstraints(
            stopTimeWindows: stopWindows.isEmpty ? nil : stopWindows,
            driverBreakIntervals: breakDurations
        )
    }

    private static func permutationIndices(
        original: [CLLocationCoordinate2D],
        optimized: [CLLocationCoordinate2D]
    ) -> [Int] {
        optimized.map { optimizedCoordinate in
            original.firstIndex(where: {
                abs($0.latitude - optimizedCoordinate.latitude) < 1e-6
                    && abs($0.longitude - optimizedCoordinate.longitude) < 1e-6
            }) ?? 0
        }
    }
}

// MARK: - Local 2-Opt Engine

private enum LocalTwoOptEngine {
    static func optimize(stopCount: Int, matrix: [[Double]]) -> [Int] {
        guard stopCount > 1 else {
            return Array(0..<stopCount)
        }

        let pointCount = stopCount + 2
        guard matrix.count == pointCount, matrix.allSatisfy({ $0.count == pointCount }) else {
            return Array(0..<stopCount)
        }

        var order = Array(0..<stopCount)
        order = twoOptImprove(
            order: order,
            matrix: matrix,
            originIndex: 0,
            destinationIndex: pointCount - 1
        )
        return order
    }

    static func haversineMatrix(for coordinates: [RoutingCoordinate]) -> [[Double]] {
        let count = coordinates.count
        var matrix = Array(repeating: Array(repeating: 0.0, count: count), count: count)
        for i in 0..<count {
            for j in 0..<count where j != i {
                let a = coordinates[i].coordinate
                let b = coordinates[j].coordinate
                matrix[i][j] = Haversine.distance(from: a, to: b)
            }
        }
        return matrix
    }

    private static func twoOptImprove(
        order: [Int],
        matrix: [[Double]],
        originIndex: Int,
        destinationIndex: Int
    ) -> [Int] {
        var bestOrder = order
        var bestDistance = tourDistance(
            order: bestOrder,
            matrix: matrix,
            originIndex: originIndex,
            destinationIndex: destinationIndex
        )
        var improved = true

        while improved {
            improved = false
            guard bestOrder.count >= 2 else { break }

            for i in 0..<(bestOrder.count - 1) {
                for j in (i + 1)..<bestOrder.count {
                    var candidate = bestOrder
                    candidate[i...j].reverse()
                    let distance = tourDistance(
                        order: candidate,
                        matrix: matrix,
                        originIndex: originIndex,
                        destinationIndex: destinationIndex
                    )
                    if distance + 1e-6 < bestDistance {
                        bestDistance = distance
                        bestOrder = candidate
                        improved = true
                    }
                }
            }
        }

        return bestOrder
    }

    private static func tourDistance(
        order: [Int],
        matrix: [[Double]],
        originIndex: Int,
        destinationIndex: Int
    ) -> Double {
        var indices = [originIndex]
        indices.append(contentsOf: order.map { $0 + 1 })
        indices.append(destinationIndex)

        var total = 0.0
        for pair in zip(indices, indices.dropFirst()) {
            total += matrix[pair.0][pair.1]
        }
        return total
    }
}

// MARK: - Vroom Network Client

private struct VroomNetworkClient: Sendable {
    private let apiKey: String
    private let baseURL: URL
    private let session: URLSession
    private let requestTimeoutSeconds: TimeInterval

    init(
        apiKey: String,
        session: URLSession,
        requestTimeoutSeconds: TimeInterval
    ) throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ExternalRoutingError.notConfigured
        }
        guard let url = URL(string: ORSAPIDefaults.baseURL) else {
            throw ExternalRoutingError.invalidConfiguration
        }
        self.apiKey = trimmed
        self.baseURL = url
        self.session = session
        self.requestTimeoutSeconds = requestTimeoutSeconds
    }

    func optimize(payload: VroomRequest, stopCount: Int) async throws -> [Int] {
        let optimizationURL = baseURL.appending(path: ORSAPIDefaults.optimizationPath)
        var urlRequest = URLRequest(url: optimizationURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(ORSAPIDefaults.userAgent, forHTTPHeaderField: "User-Agent")
        urlRequest.timeoutInterval = requestTimeoutSeconds

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        urlRequest.httpBody = try encoder.encode(payload)

        guard urlRequest.isSecureHTTPS else {
            throw ExternalRoutingError.invalidConfiguration
        }

        let frozenRequest = urlRequest
        let (data, response) = try await withTimeout(seconds: requestTimeoutSeconds) {
            try await session.data(for: frozenRequest)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ExternalRoutingError.serverError(status: -1, body: "Invalid response")
        }

        if http.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ExternalRoutingError.serverError(status: http.statusCode, body: body)
        }

        return try parseResponse(data: data, stopCount: stopCount)
    }

    private func parseResponse(data: Data, stopCount: Int) throws -> [Int] {
        let decoder = JSONDecoder()
        let envelope: VroomResponse
        do {
            envelope = try decoder.decode(VroomResponse.self, from: data)
        } catch {
            DecodingDiagnostics.logDecodingError(
                error,
                context: "ORS Vroom optimization response",
                responsePreview: DecodingDiagnostics.preview(of: data)
            )
            throw error
        }

        guard let route = envelope.routes?.first else {
            throw ExternalRoutingError.noRoute(reason: "No optimization route returned")
        }

        var orderedJobIDs: [Int] = []
        for step in route.steps ?? [] {
            if let jobID = step.job {
                orderedJobIDs.append(jobID)
            }
        }

        if orderedJobIDs.isEmpty, let unassigned = envelope.unassigned, !unassigned.isEmpty {
            throw ExternalRoutingError.noRoute(reason: "Optimization left jobs unassigned")
        }

        let indices = orderedJobIDs.map { $0 - 1 }
        guard indices.count == stopCount, Set(indices) == Set(0..<stopCount) else {
            throw ExternalRoutingError.noRoute(reason: "Invalid optimization job ordering")
        }

        return indices
    }

    private func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                let nanoseconds = UInt64(seconds * 1_000_000_000)
                try await Task.sleep(nanoseconds: nanoseconds)
                throw ExternalRoutingError.serverError(status: 408, body: "Optimization request timed out")
            }
            guard let result = try await group.next() else {
                throw ExternalRoutingError.serverError(status: 408, body: "Optimization request timed out")
            }
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Vroom Payload Builder

private enum VroomPayloadBuilder {
    static func buildRequest(
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D,
        waypoints: [RoutingCoordinate],
        vehicleProfile: VehicleSpecificationProfile,
        constraints: RouteSequenceConstraints?
    ) -> VroomRequest {
        let jobs = waypoints.enumerated().map { index, waypoint in
            let window = constraints?.timeWindow(for: waypoint)
            var timeWindows: [[Int]]? = nil
            if let window {
                timeWindows = [window.vroomUnixSeconds()]
            }
            return VroomJob(
                id: index + 1,
                location: [waypoint.longitude, waypoint.latitude],
                timeWindows: timeWindows,
                delivery: nil
            )
        }

        let vehicle = buildVehicle(
            start: start,
            end: end,
            vehicleProfile: vehicleProfile,
            constraints: constraints
        )

        let shipments = buildShipments(from: constraints?.shipments)

        return VroomRequest(
            jobs: jobs.isEmpty ? nil : jobs,
            shipments: shipments,
            vehicles: [vehicle]
        )
    }

    private static func buildVehicle(
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D,
        vehicleProfile: VehicleSpecificationProfile,
        constraints: RouteSequenceConstraints?
    ) -> VroomVehicle {
        let profile = vroomProfile(for: vehicleProfile.vehicleClass)
        let capacityKg = max(Int(vehicleProfile.grossWeightKilograms), 1000)
        let breaks = buildBreaks(from: constraints)

        var dimensions: [Double]? = nil
        if vehicleProfile.vehicleClass != .passengerCar {
            dimensions = [
                vehicleProfile.heightMeters,
                vehicleProfile.widthMeters,
                vehicleProfile.lengthMeters,
            ]
        }

        return VroomVehicle(
            id: 1,
            profile: profile,
            start: [start.longitude, start.latitude],
            end: [end.longitude, end.latitude],
            capacity: [capacityKg],
            dimensions: dimensions,
            breaks: breaks
        )
    }

    private static func vroomProfile(for vehicleClass: VehicleProfileClass) -> String {
        switch vehicleClass {
        case .heavyGoodsVehicle, .lightCommercialVehicle:
            return "driving-hgv"
        case .passengerCar:
            return "driving-car"
        }
    }

    private static func buildBreaks(
        from constraints: RouteSequenceConstraints?
    ) -> [VroomBreak]? {
        guard let intervals = constraints?.driverBreakIntervals, !intervals.isEmpty else {
            return nil
        }

        let windowBounds = breakWindowBounds(from: constraints)
        return intervals.enumerated().map { index, duration in
            VroomBreak(
                id: index + 1,
                timeWindows: [windowBounds],
                service: Int(duration)
            )
        }
    }

    private static func breakWindowBounds(from constraints: RouteSequenceConstraints?) -> [Int] {
        if let stopWindows = constraints?.stopTimeWindows, !stopWindows.isEmpty {
            let starts = stopWindows.values.map(\.start)
            let ends = stopWindows.values.map(\.end)
            if let minStart = starts.min(), let maxEnd = ends.max() {
                let startSeconds = Int(minStart.timeIntervalSince1970)
                let endSeconds = Int(maxEnd.timeIntervalSince1970)
                return [startSeconds, max(startSeconds, endSeconds)]
            }
        }

        let now = Date()
        let end = now.addingTimeInterval(86_400)
        return [Int(now.timeIntervalSince1970), Int(end.timeIntervalSince1970)]
    }

    private static func buildShipments(
        from pairs: [RouteSequenceConstraints.ShipmentPair]?
    ) -> [VroomShipment]? {
        guard let pairs, !pairs.isEmpty else { return nil }

        return pairs.enumerated().map { index, pair in
            let pickupID = (index * 2) + 1
            let deliveryID = pickupID + 1

            var pickupWindows: [[Int]]? = nil
            if let window = pair.pickupTimeWindow {
                pickupWindows = [window.vroomUnixSeconds()]
            }
            var deliveryWindows: [[Int]]? = nil
            if let window = pair.deliveryTimeWindow {
                deliveryWindows = [window.vroomUnixSeconds()]
            }

            return VroomShipment(
                pickup: VroomShipmentStep(
                    id: pickupID,
                    location: [pair.pickup.longitude, pair.pickup.latitude],
                    timeWindows: pickupWindows,
                    amount: pair.pickupAmount.map { [$0] }
                ),
                delivery: VroomShipmentStep(
                    id: deliveryID,
                    location: [pair.delivery.longitude, pair.delivery.latitude],
                    timeWindows: deliveryWindows,
                    amount: pair.deliveryAmount.map { [$0] }
                )
            )
        }
    }
}

// MARK: - Vroom Codable Types

private struct VroomRequest: Encodable {
    let jobs: [VroomJob]?
    let shipments: [VroomShipment]?
    let vehicles: [VroomVehicle]
}

private struct VroomJob: Encodable {
    let id: Int
    let location: [Double]
    let timeWindows: [[Int]]?
    let delivery: [Int]?
}

private struct VroomShipment: Encodable {
    let pickup: VroomShipmentStep
    let delivery: VroomShipmentStep
}

private struct VroomShipmentStep: Encodable {
    let id: Int
    let location: [Double]
    let timeWindows: [[Int]]?
    let amount: [Int]?
}

private struct VroomVehicle: Encodable {
    let id: Int
    let profile: String
    let start: [Double]
    let end: [Double]
    let capacity: [Int]
    let dimensions: [Double]?
    let breaks: [VroomBreak]?
}

private struct VroomBreak: Encodable {
    let id: Int
    let timeWindows: [[Int]]
    let service: Int
}

private struct VroomResponse: Decodable {
    let routes: [VroomRoute]?
    let unassigned: [VroomUnassignedJob]?
}

private struct VroomRoute: Decodable {
    let steps: [VroomStep]?
}

private struct VroomStep: Decodable {
    let job: Int?
}

private struct VroomUnassignedJob: Decodable {
    let id: Int?
}

// MARK: - Vehicle Specification Profile Routing Defaults

extension VehicleSpecificationProfile {
    /// Builds a routing-default specification profile when registry data is unavailable.
    public static func routingDefault(
        vehicleClass: VehicleProfileClass,
        grossWeightKilograms: Double? = nil,
        registrationMark: String = ""
    ) -> VehicleSpecificationProfile {
        let template = vehicleClass.canonicalDimensions
        let weight = grossWeightKilograms ?? template.grossWeightKilograms
        return VehicleSpecificationProfile(
            registrationMark: registrationMark,
            vehicleClass: vehicleClass,
            make: "Unknown",
            model: "Unknown",
            grossWeightKilograms: weight,
            lengthMeters: template.lengthMeters,
            widthMeters: template.widthMeters,
            heightMeters: template.heightMeters,
            axleCount: template.axleCount,
            wheelbaseMeters: vehicleClass.defaultWheelbaseMeters,
            source: .transientHeuristic
        )
    }
}

// MARK: - Test Support

#if DEBUG
extension RouteOptimizationEngine {
    /// Encodes a Vroom payload for unit testing.
    public static func buildVroomPayloadData(
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D,
        waypoints: [RoutingCoordinate],
        vehicleProfile: VehicleSpecificationProfile,
        constraints: RouteSequenceConstraints? = nil
    ) throws -> Data {
        let request = VroomPayloadBuilder.buildRequest(
            start: start,
            end: end,
            waypoints: waypoints,
            vehicleProfile: vehicleProfile,
            constraints: constraints
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(request)
    }
}
#endif
