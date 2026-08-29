import Contracts
import CoreLocation
import CostModel
import DataLayer
import Foundation
import RouteController

/// Host surface for HOS advisory orchestration owned by ``RouteViewModel``.
@MainActor
public protocol HosAdvisoryHost: AnyObject {
    /// Whether advisory HOS is enabled.
    var hosEnabled: Bool { get }
    /// Latest HOS snapshot for HUD.
    var hosSnapshot: HosClockSnapshot? { get set }
    /// Latest HOS rest forecast.
    var hosForecast: HosRestInsertionResult? { get set }
    /// Imported tachograph card summary.
    var tachoSummary: TachoCardSummary? { get set }
    /// Can-I-drive evaluation status.
    var canIDriveStatus: CanIDriveStatus? { get set }
    /// Error from the most recent tachograph import.
    var tachoImportError: String? { get set }
    /// Advisory EU 561 hours-of-service clock.
    var hosClock: EU561HosClock { get }
    /// Best-effort DDD / JSON driver-card importer.
    var tachoImporter: DDDImporter { get }
    /// Inline error banner text.
    var errorMessage: String? { get set }
    /// Latest search / route result.
    var result: SearchResult? { get }
    /// Active route coordinates.
    var routeCoordinates: [CLLocationCoordinate2D] { get }
    /// Cumulative arc lengths along the route.
    var routeCumulativeLengths: [Double] { get }
    /// Physics-predicted duration when available.
    var physicsPredictedDurationSeconds: TimeInterval? { get }
    /// Upcoming truck POIs for rest insertion.
    var upcomingTruckPois: [TruckPoi] { get }
    /// Vehicle weight text for kinetic stress analysis.
    var vehicleWeight: String { get }
    /// Refreshes trip brief share text after HOS changes.
    func refreshTripBriefShareText()
}

/// Coordinates advisory HOS clock, tachograph import, and rest forecasting.
@MainActor
public final class HosAdvisoryCoordinator {
    private weak var host: HosAdvisoryHost?

    /// Creates an HOS advisory coordinator bound to the given host.
    public init(host: HosAdvisoryHost) {
        self.host = host
    }

    /// Loads persisted HOS log + tacho summary and refreshes HUD state.
    public func bootstrapFromDisk() async {
        guard let host else { return }
        await host.hosClock.loadPersistedLog()
        loadPersistedTachoSummary()
        await refreshHosSnapshot()
        await refreshCanIDriveStatus()
    }

    /// Transitions the advisory HOS duty mode and refreshes the HUD snapshot.
    public func transitionHosMode(_ mode: HosDutyMode, note: String? = nil) async {
        guard let host, host.hosEnabled else { return }
        do {
            _ = try await host.hosClock.transition(mode: HosDutyEvent(mode: mode, note: note))
            await refreshHosSnapshot()
            await refreshHosForecast()
        } catch {
            host.errorMessage = "Could not update hours clock: \(error.localizedDescription)"
        }
    }

    /// Refreshes the HOS HUD snapshot from the clock.
    public func refreshHosSnapshot() async {
        guard let host else { return }
        guard host.hosEnabled else {
            host.hosSnapshot = nil
            await refreshCanIDriveStatus()
            return
        }
        host.hosSnapshot = await host.hosClock.snapshot()
        await refreshCanIDriveStatus()
    }

    /// Recomputes the advisory “Can I drive now?” status from import + clock.
    public func refreshCanIDriveStatus() async {
        guard let host else { return }
        let snapshot: HosClockSnapshot
        if let hosSnapshot = host.hosSnapshot {
            snapshot = hosSnapshot
        } else {
            snapshot = await host.hosClock.snapshot()
        }
        host.canIDriveStatus = CanIDriveEvaluator.evaluate(
            imported: host.tachoSummary,
            clockSnapshot: snapshot
        )
    }

    /// Imports a driver-card JSON / DDD file and refreshes can-I-drive status.
    public func importTachoFile(url: URL) async {
        guard let host else { return }
        host.tachoImportError = nil
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        do {
            let summary = try host.tachoImporter.importDriverCard(from: url)
            host.tachoSummary = summary
            persistTachoSummary(summary)
            await refreshCanIDriveStatus()
        } catch {
            host.tachoImportError = error.localizedDescription
        }
    }

    /// Clears the imported tachograph summary.
    public func clearImportedTachoSummary() async {
        guard let host else { return }
        host.tachoSummary = nil
        host.tachoImportError = nil
        Self.removePersistedTachoSummary()
        await refreshCanIDriveStatus()
    }

    /// Rebuilds the HOS rest forecast for the current route using POIs and path durations.
    public func refreshHosForecast() async {
        guard let host else { return }
        guard host.hosEnabled else {
            host.hosForecast = nil
            return
        }
        let durations = hosPathDurationsSeconds()
        guard !durations.isEmpty else {
            host.hosForecast = await host.hosClock.forecast(pathDurationsSeconds: [])
            await refreshHosSnapshot()
            return
        }
        let snap = await host.hosClock.snapshot()
        host.hosSnapshot = snap
        let arcs: [Double]? = host.routeCumulativeLengths.count == durations.count
            ? Array(host.routeCumulativeLengths.dropFirst())
            : (host.routeCumulativeLengths.count == durations.count + 1
                ? Array(host.routeCumulativeLengths.dropFirst())
                : nil)
        let insertions = HosRestInserter.insertions(
            remainingContinuousDriveSeconds: snap.remainingContinuousDriveSeconds,
            remainingDailyDriveSeconds: snap.remainingDailyDriveSeconds,
            pathDurationsSeconds: durations,
            pathArcLengthsMeters: arcs,
            upcomingTruckPois: host.upcomingTruckPois,
            kineticStress: hosPathKineticStress()
        )
        let base = await host.hosClock.forecast(pathDurationsSeconds: durations)
        host.hosForecast = HosRestInsertionResult(
            remainingContinuousDriveSeconds: snap.remainingContinuousDriveSeconds,
            remainingDailyDriveSeconds: snap.remainingDailyDriveSeconds,
            insertions: insertions.isEmpty ? base.insertions : insertions,
            summary: base.summary
        )
        host.refreshTripBriefShareText()
        if let forecast = host.hosForecast, !forecast.insertions.isEmpty {
            NotificationCenter.default.post(
                name: .routeFinderHosAdvisory,
                object: nil,
                userInfo: ["summary": forecast.summary]
            )
        }
    }

    /// Segment durations along the active route for HOS forecasting.
    public func hosPathDurationsSeconds() -> [TimeInterval] {
        guard let host else { return [] }
        guard let total = host.physicsPredictedDurationSeconds ?? host.result?.metrics.totalTime,
              total > 0 else {
            return []
        }
        let segmentCount = max(host.routeCoordinates.count - 1, 1)
        if host.routeCumulativeLengths.count >= 2 {
            let totalLength = host.routeCumulativeLengths.last ?? 0
            guard totalLength > 0 else {
                return Array(repeating: total / Double(segmentCount), count: segmentCount)
            }
            var durations: [TimeInterval] = []
            for index in 1..<host.routeCumulativeLengths.count {
                let delta = host.routeCumulativeLengths[index] - host.routeCumulativeLengths[index - 1]
                durations.append(total * (delta / totalLength))
            }
            return durations
        }
        return Array(repeating: total / Double(segmentCount), count: segmentCount)
    }

    /// Arc lengths paired with HOS path durations.
    public func hosPathArcLengthsMeters() -> [Double]? {
        guard let host, host.routeCumulativeLengths.count >= 2 else { return nil }
        let durations = hosPathDurationsSeconds()
        if host.routeCumulativeLengths.count == durations.count + 1 {
            return Array(host.routeCumulativeLengths.dropFirst())
        }
        if host.routeCumulativeLengths.count == durations.count {
            return host.routeCumulativeLengths
        }
        return nil
    }

    /// Kinetic stress segments for HOS rest insertion.
    public func hosPathKineticStress() -> [SegmentKineticStress]? {
        guard let host, host.routeCoordinates.count >= 2 else { return nil }
        let path = host.routeCoordinates.map {
            GeoCoordinate3D(latitude: $0.latitude, longitude: $0.longitude, elevationMeters: nil)
        }
        let weightTons = VehicleDimensionParser.parseOptional(host.vehicleWeight) ?? 44
        let segments = KineticGradientAnalyzer.analyzeTopology(path: path, weightTons: weightTons)
        guard !segments.isEmpty else { return nil }
        return segments
    }

    private func persistTachoSummary(_ summary: TachoCardSummary) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(summary) else { return }
        try? data.write(to: Self.tachoSummaryURL(), options: .atomic)
    }

    private func loadPersistedTachoSummary() {
        guard let host else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: Self.tachoSummaryURL()),
              let summary = try? decoder.decode(TachoCardSummary.self, from: data) else {
            return
        }
        host.tachoSummary = summary
    }

    private static func removePersistedTachoSummary() {
        try? FileManager.default.removeItem(at: tachoSummaryURL())
    }

    private static func tachoSummaryURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("RouteFinder/tacho", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("imported_card.json")
    }
}
