import Contracts
import CoreLocation
import DataLayer
import Foundation

/// HeiGIT OpenRouteService HTTP client for HGV routing with GeoJSON geometry.
public struct OpenRouteServiceRoutingClient: ExternalRoutingClient, Sendable {
    private let apiKey: String
    private let baseURL: URL
    private let session: URLSession

    /// Creates an ORS routing client with the given HeiGIT API key.
    public init(apiKey: String, session: URLSession = SecureURLSession.shared) throws {
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
    }

    /// Calculates a route via the configured OpenRouteService profile.
    public func route(request: ExternalRouteRequest) async throws -> ExternalRouteResponse {
        let path = request.preferences.isHGVMode
            ? ORSAPIDefaults.hgvDirectionsPath
            : ORSAPIDefaults.carDirectionsPath
        let routeURL = baseURL.appending(path: path)

        let (data, http) = try await performRouteRequest(url: routeURL, request: request)

        if http.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? ""
            if http.statusCode == 400,
               ORSErrorParser.isUnsupportedExtraInfoError(body: body),
               request.preferences.requestSegmentSpeedLimits {
                let retryRequest = request.omittingExtraInfo()
                let (retryData, retryHTTP) = try await performRouteRequest(url: routeURL, request: retryRequest)
                if retryHTTP.statusCode < 400 {
                    return try parseSuccessResponse(data: retryData)
                }
                throw mapHTTPError(status: retryHTTP.statusCode, data: retryData)
            }
            throw mapHTTPError(status: http.statusCode, data: data)
        }

        return try parseSuccessResponse(data: data)
    }

    private func performRouteRequest(
        url: URL,
        request: ExternalRouteRequest
    ) async throws -> (Data, HTTPURLResponse) {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(ORSAPIDefaults.userAgent, forHTTPHeaderField: "User-Agent")
        urlRequest.httpBody = try OpenRouteServicePayloadBuilder.buildData(from: request)

        guard urlRequest.isSecureHTTPS else {
            throw ExternalRoutingError.invalidConfiguration
        }

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw ExternalRoutingError.serverError(status: -1, body: "Invalid response")
        }
        return (data, http)
    }

    // MARK: - Response parsing

    private func parseSuccessResponse(data: Data) throws -> ExternalRouteResponse {
        let decoder = JSONDecoder()

        if let errorBody = try? decoder.decode(ORSErrorEnvelope.self, from: data),
           let error = errorBody.error {
            throw mapORSError(error, rawBody: DecodingDiagnostics.preview(of: data))
        }

        let collection: ORSRouteFeatureCollection
        do {
            collection = try decoder.decode(ORSRouteFeatureCollection.self, from: data)
        } catch {
            DecodingDiagnostics.logDecodingError(
                error,
                context: "ORS route response",
                responsePreview: DecodingDiagnostics.preview(of: data)
            )
            throw error
        }

        var allCoordinates: [Coordinate] = []
        var totalDistance: Double = 0
        var totalDuration: TimeInterval = 0
        var maneuvers: [ExternalManeuver] = []
        var rawMaxSpeedKmh: [Double?] = []
        var stepSpeedRanges: [ORSStepSpeedRange] = []

        for feature in collection.features {
            if feature.geometry.type == "LineString" {
                let coords = feature.geometry.coordinates.compactMap { pair -> Coordinate? in
                    guard pair.count >= 2 else { return nil }
                    let elevation = pair.count >= 3 ? pair[2] : nil
                    return Coordinate(latitude: pair[1], longitude: pair[0], elevationMeters: elevation)
                }
                allCoordinates.append(contentsOf: coords)

                if let extras = feature.properties.extras {
                    let parsed = parseGeometryMaxSpeeds(
                        extras: extras,
                        coordinateCount: coords.count,
                        coordinates: coords
                    )
                    if rawMaxSpeedKmh.isEmpty {
                        rawMaxSpeedKmh = parsed
                    } else if parsed.count == rawMaxSpeedKmh.count {
                        rawMaxSpeedKmh = zip(rawMaxSpeedKmh, parsed).map { existing, incoming in
                            existing ?? incoming
                        }
                    }
                }
            }
            if let summary = feature.properties.summary {
                totalDistance += summary.distance
                totalDuration += summary.duration
            }
            if let segments = feature.properties.segments {
                for segment in segments {
                    for step in segment.steps ?? [] {
                        let stepCoordinate = stepCoordinate(from: step, fallback: allCoordinates.last)
                        let speedLimitKmh = parsedSpeedLimitKmh(from: step, coordinate: stepCoordinate)
                        maneuvers.append(ExternalManeuver(
                            instruction: step.instruction ?? "Continue",
                            distanceMeters: step.distance ?? 0,
                            durationSeconds: step.duration ?? 0,
                            stepType: step.type,
                            speedLimitKmh: speedLimitKmh
                        ))
                        if let wayPoints = step.wayPoints, wayPoints.count >= 2 {
                            let start = Int(wayPoints[0].rounded(.down))
                            let end = Int(wayPoints[1].rounded(.down))
                            stepSpeedRanges.append(
                                ORSStepSpeedRange(
                                    startIndex: start,
                                    endIndex: end,
                                    speedLimitKmh: speedLimitKmh
                                )
                            )
                        }
                    }
                }
            }
        }

        guard !allCoordinates.isEmpty else {
            throw ExternalRoutingError.noRoute(reason: "No route geometry returned")
        }

        let alignedRawLimits: [Double?]
        if rawMaxSpeedKmh.count == allCoordinates.count {
            alignedRawLimits = rawMaxSpeedKmh
        } else if rawMaxSpeedKmh.isEmpty {
            alignedRawLimits = Array(repeating: nil, count: allCoordinates.count)
        } else {
            alignedRawLimits = resampleSpeedLimits(
                rawMaxSpeedKmh,
                toCount: allCoordinates.count,
                stepRanges: stepSpeedRanges
            )
        }

        let speedLimitSource = SegmentSpeedLimitSource(
            rawGeometrySpeedLimitsKmh: alignedRawLimits,
            stepSpeedRanges: stepSpeedRanges
        )

        return ExternalRouteResponse(
            encodedPolyline: nil,
            polylinePrecision: 6,
            coordinates: allCoordinates,
            distanceMeters: totalDistance,
            durationSeconds: totalDuration,
            maneuvers: maneuvers,
            speedLimitSource: speedLimitSource
        )
    }

    private func parseGeometryMaxSpeeds(
        extras: ORSRouteExtras,
        coordinateCount: Int,
        coordinates: [Coordinate]
    ) -> [Double?] {
        let rawValues = extras.maxSpeed ?? extras.maxSpeeds ?? []
        guard !rawValues.isEmpty else { return [] }

        return rawValues.enumerated().map { index, value in
            guard index < coordinateCount else { return nil }
            guard let numeric = parseMaxSpeedValue(value) else { return nil }
            let coordinate = CLLocationCoordinate2D(
                latitude: coordinates[index].latitude,
                longitude: coordinates[index].longitude
            )
            return SpeedLimitNormalizer.normalizeToKmh(rawValue: numeric, coordinate: coordinate)
        }
    }

    private func parseMaxSpeedValue(_ value: ORSMaxSpeedValue) -> Double? {
        switch value {
        case .number(let raw):
            return raw > 0 ? raw : nil
        case .string(let text):
            let digits = text.filter { $0.isNumber || $0 == "." }
            guard let raw = Double(digits), raw > 0 else { return nil }
            return raw
        }
    }

    private func resampleSpeedLimits(
        _ limits: [Double?],
        toCount: Int,
        stepRanges: [ORSStepSpeedRange]
    ) -> [Double?] {
        guard toCount > 0 else { return [] }
        if limits.count == toCount { return limits }

        var result = Array(repeating: Double?.none, count: toCount)
        if limits.count > 1, toCount > 1 {
            for targetIndex in 0..<toCount {
                let sourceIndex = Int(
                    (Double(targetIndex) / Double(toCount - 1)) * Double(limits.count - 1)
                )
                result[targetIndex] = limits[min(sourceIndex, limits.count - 1)]
            }
        }

        for range in stepRanges {
            guard let limit = range.speedLimitKmh else { continue }
            let start = max(0, range.startIndex)
            let end = min(toCount - 1, range.endIndex)
            guard start <= end else { continue }
            for index in start...end where result[index] == nil {
                result[index] = limit
            }
        }
        return result
    }

    private func mapHTTPError(status: Int, data: Data) -> ExternalRoutingError {
        let body = String(data: data, encoding: .utf8) ?? ""
        let decoder = JSONDecoder()

        if let errorBody = try? decoder.decode(ORSErrorEnvelope.self, from: data),
           let error = errorBody.error {
            if let mapped = tryMapORSError(error) {
                return mapped
            }
        }

        if isNoRouteMessage(body) {
            return .noRoute(reason: body)
        }

        return .serverError(status: status, body: body)
    }

    private func mapORSError(_ error: ORSErrorBody, rawBody: String) -> ExternalRoutingError {
        if let mapped = tryMapORSError(error) {
            return mapped
        }
        let reason = error.message ?? rawBody
        return .noRoute(reason: reason)
    }

    private func tryMapORSError(_ error: ORSErrorBody) -> ExternalRoutingError? {
        let message = error.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if isDimensionBlockedMessage(message) {
            return .vehicleDimensionBlocked(
                reason: message.isEmpty ? "Vehicle restriction on corridor" : message
            )
        }

        if isNoRouteMessage(message) {
            return .noRoute(reason: message.isEmpty ? "No path could be found" : message)
        }

        return nil
    }

    private func isDimensionBlockedMessage(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("height")
            || lower.contains("clearance")
            || lower.contains("bridge")
            || lower.contains("exclusion")
            || lower.contains("too large")
            || lower.contains("restriction")
    }

    private func stepCoordinate(from step: ORSStep, fallback: Coordinate?) -> CLLocationCoordinate2D? {
        if let waypoint = step.wayPoints, waypoint.count >= 2 {
            return CLLocationCoordinate2D(latitude: waypoint[1], longitude: waypoint[0])
        }
        if let fallback {
            return CLLocationCoordinate2D(latitude: fallback.latitude, longitude: fallback.longitude)
        }
        return nil
    }

    private func parsedSpeedLimitKmh(from step: ORSStep, coordinate: CLLocationCoordinate2D?) -> Double? {
        guard let raw = step.maximumSpeed ?? step.maxSpeed, raw > 0 else { return nil }
        guard let coordinate else { return raw }
        return SpeedLimitNormalizer.normalizeToKmh(rawValue: raw, coordinate: coordinate)
    }

    private func isNoRouteMessage(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("no path could be found")
            || lower.contains("no route")
            || lower.contains("could not find a route")
            || lower.contains("not routable")
            || lower.contains("route could not be found")
    }
}

// MARK: - ORS response types

private struct ORSRouteFeatureCollection: Decodable {
    let features: [ORSRouteFeature]
}

private struct ORSRouteFeature: Decodable {
    let geometry: ORSRouteGeometry
    let properties: ORSRouteProperties
}

private struct ORSRouteGeometry: Decodable {
    let type: String
    let coordinates: [[Double]]
}

private struct ORSRouteProperties: Decodable {
    let summary: ORSRouteSummary?
    let segments: [ORSSegment]?
    let extras: ORSRouteExtras?
}

private struct ORSRouteExtras: Decodable {
    let maxSpeed: [ORSMaxSpeedValue]?
    let maxSpeeds: [ORSMaxSpeedValue]?

    enum CodingKeys: String, CodingKey {
        case maxSpeed = "maxspeed"
        case maxSpeeds = "maxspeeds"
    }
}

private enum ORSMaxSpeedValue: Decodable {
    case number(Double)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Double.self) {
            self = .number(value)
            return
        }
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        throw DecodingError.typeMismatch(
            ORSMaxSpeedValue.self,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported maxspeed value")
        )
    }
}

private struct ORSSegment: Decodable {
    let steps: [ORSStep]?
}

private struct ORSStep: Decodable {
    let instruction: String?
    let distance: Double?
    let duration: TimeInterval?
    let type: Int?
    let wayPoints: [Double]?
    let maximumSpeed: Double?
    let maxSpeed: Double?

    enum CodingKeys: String, CodingKey {
        case instruction
        case distance
        case duration
        case type
        case wayPoints = "way_points"
        case maximumSpeed = "maximum_speed"
        case maxSpeed = "max_speed"
    }
}

private struct ORSRouteSummary: Decodable {
    let distance: Double
    let duration: TimeInterval
}

private struct ORSErrorEnvelope: Decodable {
    let error: ORSErrorBody?
}

private struct ORSErrorBody: Decodable {
    let code: Int?
    let message: String?
}
