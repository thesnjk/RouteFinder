import Contracts
import Foundation

/// Pure helper that places advisory HOS rest stops along a planned path.
///
/// Prefers secure parking, laybys, and high-flow diesel before continuous/daily
/// drive remaining hits zero, and biases insertion upstream of high kinetic stress.
public enum HosRestInserter: Sendable {
    /// POI kinds acceptable for an advisory break / rest stop.
    public static let preferredKinds: Set<TruckPoiKind> = [
        .overnightSecureParking,
        .layby,
        .highFlowDiesel,
    ]

    /// Thermal stress above which an upstream rest is preferred.
    public static let thermalStressThreshold: Double = 0.55
    /// Absolute grade percent above which an upstream rest is preferred.
    public static let gradeStressThreshold: Double = 6.0
    /// Default 45-minute break duration (EU 561 continuous-drive rule).
    public static let defaultBreakSeconds: TimeInterval = 45 * 60

    /// Computes rest insertions before remaining continuous (and optional daily) drive is exhausted.
    ///
    /// - Parameters:
    ///   - remainingContinuousDriveSeconds: Seconds of continuous driving still available.
    ///   - remainingDailyDriveSeconds: Optional daily remaining; when tighter than continuous, governs deadline.
    ///   - pathDurationsSeconds: Per-segment driving durations along the path.
    ///   - pathArcLengthsMeters: Optional cumulative arc lengths aligned to segment ends (same count as durations).
    ///   - upcomingTruckPois: Candidate rest POIs (ideally projected onto the route).
    ///   - kineticStress: Optional per-segment stress aligned to `pathDurationsSeconds`.
    ///   - restDurationSeconds: Suggested rest length for each insertion.
    /// - Returns: Zero or more insertions; empty when the path fits remaining drive time.
    public static func insertions(
        remainingContinuousDriveSeconds: TimeInterval,
        remainingDailyDriveSeconds: TimeInterval? = nil,
        pathDurationsSeconds: [TimeInterval],
        pathArcLengthsMeters: [Double]? = nil,
        upcomingTruckPois: [TruckPoi],
        kineticStress: [SegmentKineticStress]? = nil,
        restDurationSeconds: TimeInterval = defaultBreakSeconds
    ) -> [HosRestInsertion] {
        guard !pathDurationsSeconds.isEmpty else { return [] }

        let continuousBudget = max(0, remainingContinuousDriveSeconds)
        let dailyBudget = max(0, remainingDailyDriveSeconds ?? .greatestFiniteMagnitude)
        let driveBudget = min(continuousBudget, dailyBudget)
        if driveBudget <= 0 {
            return [
                makeInsertion(
                    afterSegmentIndex: -1,
                    arcLengthMeters: 0,
                    poi: bestPoi(
                        from: upcomingTruckPois,
                        beforeArcMeters: pathArcLengthsMeters?.last ?? 0,
                        preferUpstreamOf: nil
                    ),
                    restDurationSeconds: restDurationSeconds,
                    reason: "No remaining drive time — rest before continuing.",
                    physicsPreferred: false
                ),
            ]
        }

        var cumulative: TimeInterval = 0
        var deadlineIndex: Int?
        for (index, duration) in pathDurationsSeconds.enumerated() {
            cumulative += max(0, duration)
            if cumulative > driveBudget {
                deadlineIndex = index
                break
            }
        }
        guard let deadlineIndex else { return [] }

        let deadlineArc = arcLength(
            atSegmentEnd: deadlineIndex,
            durations: pathDurationsSeconds,
            arcs: pathArcLengthsMeters
        )

        let stressIndex = firstHighStressIndex(
            kineticStress: kineticStress,
            beforeOrAt: deadlineIndex
        )
        let physicsPreferred = stressIndex != nil
        let preferredArcCap: Double
        if let stressIndex {
            preferredArcCap = arcLength(
                atSegmentEnd: max(stressIndex - 1, -1),
                durations: pathDurationsSeconds,
                arcs: pathArcLengthsMeters
            )
        } else {
            preferredArcCap = deadlineArc
        }

        let poi = bestPoi(
            from: upcomingTruckPois,
            beforeArcMeters: preferredArcCap > 0 ? preferredArcCap : deadlineArc,
            preferUpstreamOf: preferredArcCap
        ) ?? bestPoi(
            from: upcomingTruckPois,
            beforeArcMeters: deadlineArc,
            preferUpstreamOf: nil
        )

        let afterIndex: Int
        if let poi, let poiArc = poi.arcLengthAlongRouteMeters, let arcs = pathArcLengthsMeters {
            afterIndex = max(0, arcs.lastIndex(where: { $0 <= poiArc }) ?? 0)
        } else if let stressIndex, stressIndex > 0 {
            afterIndex = stressIndex - 1
        } else {
            afterIndex = max(0, deadlineIndex - 1)
        }

        let limitLabel = dailyBudget < continuousBudget
            ? "daily driving limit"
            : "4.5 h continuous drive"
        let physicsNote = physicsPreferred ? " upstream of high grade/thermal stress" : ""
        let reason = "45 min break before \(limitLabel)\(physicsNote)"

        return [
            makeInsertion(
                afterSegmentIndex: afterIndex,
                arcLengthMeters: poi?.arcLengthAlongRouteMeters
                    ?? arcLength(
                        atSegmentEnd: afterIndex,
                        durations: pathDurationsSeconds,
                        arcs: pathArcLengthsMeters
                    ),
                poi: poi,
                restDurationSeconds: restDurationSeconds,
                reason: reason,
                physicsPreferred: physicsPreferred
            ),
        ]
    }

    // MARK: - Helpers

    private static func makeInsertion(
        afterSegmentIndex: Int,
        arcLengthMeters: Double?,
        poi: TruckPoi?,
        restDurationSeconds: TimeInterval,
        reason: String,
        physicsPreferred: Bool
    ) -> HosRestInsertion {
        HosRestInsertion(
            afterSegmentIndex: afterSegmentIndex,
            arcLengthMeters: arcLengthMeters,
            poiId: poi?.id,
            restDurationSeconds: restDurationSeconds,
            reason: reason,
            physicsPreferred: physicsPreferred
        )
    }

    private static func firstHighStressIndex(
        kineticStress: [SegmentKineticStress]?,
        beforeOrAt deadlineIndex: Int
    ) -> Int? {
        guard let kineticStress else { return nil }
        let upper = min(deadlineIndex, kineticStress.count - 1)
        guard upper >= 0 else { return nil }
        for index in 0...upper {
            let sample = kineticStress[index]
            if sample.thermalStressScore >= thermalStressThreshold
                || abs(sample.gradePercentage) >= gradeStressThreshold {
                return index
            }
        }
        return nil
    }

    private static func arcLength(
        atSegmentEnd index: Int,
        durations: [TimeInterval],
        arcs: [Double]?
    ) -> Double {
        if index < 0 { return 0 }
        if let arcs, index < arcs.count {
            return arcs[index]
        }
        // Duration-proportional proxy when arcs are unknown (meters ≈ seconds for ranking only).
        return durations.prefix(index + 1).reduce(0, +)
    }

    private static func bestPoi(
        from pois: [TruckPoi],
        beforeArcMeters: Double,
        preferUpstreamOf: Double?
    ) -> TruckPoi? {
        let eligible = pois.filter { poi in
            guard preferredKinds.contains(poi.kind), poi.hgvAccess else { return false }
            guard let arc = poi.arcLengthAlongRouteMeters else { return false }
            return arc >= 0 && arc <= beforeArcMeters
        }
        guard !eligible.isEmpty else { return nil }

        let ranked = eligible.sorted { lhs, rhs in
            let lRank = kindRank(lhs.kind)
            let rRank = kindRank(rhs.kind)
            if lRank != rRank { return lRank < rRank }
            let lArc = lhs.arcLengthAlongRouteMeters ?? 0
            let rArc = rhs.arcLengthAlongRouteMeters ?? 0
            if let target = preferUpstreamOf, target > 0 {
                // Prefer the furthest POI still upstream of the stress / deadline.
                return lArc > rArc
            }
            return lArc > rArc
        }
        return ranked.first
    }

    private static func kindRank(_ kind: TruckPoiKind) -> Int {
        switch kind {
        case .overnightSecureParking: return 0
        case .layby: return 1
        case .highFlowDiesel: return 2
        case .adrCompatibleParking: return 3
        case .weighStation: return 4
        }
    }
}
