import Contracts
import DataLayer
import Foundation
import Hummingbird

/// Builds Hummingbird routes for the fleet dispatch REST API.
public enum FleetRouterBuilder {
    /// Registers fleet API routes backed by the given store.
    public static func buildRouter(store: DiskFleetStore, apiKey: String? = nil) -> Router<BasicRequestContext> {
        let router = Router(context: BasicRequestContext.self)

        router.get("health") { _, _ async throws -> Response in
            try jsonResponse(FleetServerHealthResponse(ok: true, version: "1"))
        }

        if let apiKey, !apiKey.isEmpty {
            router.add(middleware: FleetAuthMiddleware(apiKey: apiKey))
        }

        router.get("v1/orgs") { _, _ async throws -> Response in
            try jsonResponse(try await store.orgs())
        }

        router.post("v1/orgs") { request, context async throws -> Response in
            let body = try await request.decode(as: CreateOrgRequest.self, context: context)
            return try jsonResponse(try await store.createOrg(name: body.name))
        }

        router.get("v1/orgs/:orgId/vehicles") { _, context async throws -> Response in
            let orgId = try requireUUID(context, parameter: "orgId")
            return try jsonResponse(try await store.vehicles(forOrgId: orgId))
        }

        router.post("v1/vehicles") { request, context async throws -> Response in
            let vehicle = try await request.decode(as: FleetVehicle.self, context: context)
            return try jsonResponse(try await store.registerVehicle(vehicle))
        }

        router.post("v1/trips") { request, context async throws -> Response in
            let trip = try await request.decode(as: FleetTrip.self, context: context)
            return try jsonResponse(try await store.pushTrip(trip))
        }

        router.get("v1/vehicles/:vehicleId/active-trip") { _, context async throws -> Response in
            let vehicleId = try requireUUID(context, parameter: "vehicleId")
            guard let trip = try await store.activeTrip(forVehicleId: vehicleId) else {
                return Response(status: .noContent)
            }
            return try jsonResponse(trip)
        }

        router.get("v1/trips/:tripId") { _, context async throws -> Response in
            let tripId = try requireUUID(context, parameter: "tripId")
            guard let trip = try await store.trip(id: tripId) else {
                return Response(status: .notFound)
            }
            return try jsonResponse(trip)
        }

        router.put("v1/trips/:tripId/snapshot") { request, context async throws -> Response in
            let tripId = try requireUUID(context, parameter: "tripId")
            let snapshot = try await request.decode(as: FleetTripSnapshot.self, context: context)
            guard snapshot.tripId == tripId else {
                throw HTTPError(.badRequest, message: "Trip id in path and body must match.")
            }
            return try jsonResponse(try await store.applySnapshot(snapshot))
        }

        return router
    }

    private static func requireUUID(_ context: BasicRequestContext, parameter: String) throws -> UUID {
        guard let raw = context.parameters.get(parameter),
              let uuid = UUID(uuidString: raw) else {
            throw HTTPError(.badRequest, message: "Invalid \(parameter) parameter.")
        }
        return uuid
    }

    private static func jsonResponse<T: Encodable>(_ value: T) throws -> Response {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        var buffer = ByteBuffer()
        buffer.writeData(data)
        var headers = HTTPFields()
        headers[.contentType] = "application/json; charset=utf-8"
        return Response(status: .ok, headers: headers, body: .init(byteBuffer: buffer))
    }
}
