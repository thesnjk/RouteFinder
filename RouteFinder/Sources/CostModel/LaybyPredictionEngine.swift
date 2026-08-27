import Contracts
import Foundation

/// Fused on-device layby ranker combining HOS, company breaks, physics, occupancy, and traffic.
public enum LaybyPredictionEngine: Sendable {
    /// Arc tolerance when matching laybys ahead of the vehicle (meters).
    public static let arcLookbackMeters: Double = 50

    /// Default multiplier applied to ETAs when live traffic reroute is active.
    public static let defaultTrafficInflationFactor: Double = 1.15

    /// Runs the fused ranker and returns ranked advisories (best first).
    public static func predict(_ input: LaybyPredictionInput) -> LaybyPredictionResult {
        let trafficFactor = max(1, input.trafficInflationFactor ?? 1)
        let eligible = input.candidates.filter { stop in
            guard !input.skippedIds.contains(stop.id) else { return false }
            guard let arc = stop.arcLengthAlongRouteMeters else { return false }
            return arc >= input.currentArcLengthMeters - arcLookbackMeters
        }
        guard !eligible.isEmpty else {
            return LaybyPredictionResult(ranked: [])
        }

        let routeEndArc = input.pathArcLengthsMeters?.last
            ?? eligible.compactMap(\.arcLengthAlongRouteMeters).max()
            ?? input.currentArcLengthMeters

        let hosBudget = hosDriveBudgetSeconds(input)
        let hosDeadlineArc = hosBudget.map {
            deadlineArc(
                currentArc: input.currentArcLengthMeters,
                budgetSeconds: $0,
                pathDurations: input.pathDurationsSeconds,
                pathArcs: input.pathArcLengthsMeters,
                speedMps: input.speedMps,
                trafficFactor: trafficFactor,
                routeEndArc: routeEndArc
            )
        }

        let companyBand = companyArcBand(
            breaks: input.companyBreaks,
            currentArc: input.currentArcLengthMeters,
            now: input.now,
            pathDurations: input.pathDurationsSeconds,
            pathArcs: input.pathArcLengthsMeters,
            speedMps: input.speedMps,
            trafficFactor: trafficFactor,
            routeEndArc: routeEndArc
        )

        let hasHOS = hosBudget != nil
        let hasCompany = companyBand != nil

        if !hasHOS, !hasCompany {
            return geometryFallback(
                eligible: eligible,
                input: input,
                trafficFactor: trafficFactor
            )
        }

        var mayStopFrom = input.currentArcLengthMeters
        var mustStopBy = routeEndArc
        var reasonCodes: [LaybyReasonCode] = []
        var breakWindowOpensAt: Date?
        var isAdvisory = false

        if let hosDeadlineArc {
            mustStopBy = min(mustStopBy, hosDeadlineArc)
            reasonCodes.append(.hosDeadline)
            isAdvisory = true
        }

        if let companyBand {
            mayStopFrom = max(mayStopFrom, companyBand.fromArc)
            mustStopBy = min(mustStopBy, companyBand.toArc)
            breakWindowOpensAt = companyBand.windowStart
            reasonCodes.append(.companyWindow)
            isAdvisory = true
        }

        if mayStopFrom > mustStopBy + 1 {
            return geometryFallback(
                eligible: eligible,
                input: input,
                trafficFactor: trafficFactor,
                note: "Infeasible HOS/company band — geometry fallback."
            )
        }

        let physicsCapArc = physicsPreferredCapArc(
            kineticStress: input.kineticStress,
            pathDurations: input.pathDurationsSeconds,
            pathArcs: input.pathArcLengthsMeters,
            currentArc: input.currentArcLengthMeters,
            deadlineArc: mustStopBy
        )
        if let physicsCapArc, physicsCapArc < mustStopBy {
            reasonCodes.append(.physicsStress)
        }

        let effectiveCap = min(mustStopBy, physicsCapArc ?? mustStopBy)
        let inBand = eligible.filter { stop in
            guard let arc = stop.arcLengthAlongRouteMeters else { return false }
            return arc >= mayStopFrom - arcLookbackMeters && arc <= effectiveCap + arcLookbackMeters
        }

        let pool = inBand.isEmpty ? eligible : inBand
        let rankedStops = rankCandidates(
            pool,
            preferBeforeArc: effectiveCap,
            mayStopFrom: mayStopFrom,
            now: input.now,
            trafficFactor: trafficFactor,
            input: input
        )

        guard !rankedStops.isEmpty else {
            return geometryFallback(
                eligible: eligible,
                input: input,
                trafficFactor: trafficFactor
            )
        }

        if trafficFactor > 1.01 {
            reasonCodes.append(.trafficInflation)
        }

        let advisories = rankedStops.map { scored in
            var codes = reasonCodes
            if scored.occupancyPrior != .low {
                codes.append(.occupancy)
            }
            return makeAdvisory(
                stop: scored.stop,
                input: input,
                trafficFactor: trafficFactor,
                confidence: scored.confidence,
                occupancyPrior: scored.occupancyPrior,
                breakWindowOpensAt: breakWindowOpensAt,
                reasonCodes: codes,
                isAdvisory: isAdvisory
            )
        }

        return LaybyPredictionResult(ranked: advisories)
    }

    // MARK: - Band computation

    private static func hosDriveBudgetSeconds(_ input: LaybyPredictionInput) -> TimeInterval? {
        let continuous = input.remainingContinuousDriveSeconds
        let daily = input.remainingDailyDriveSeconds
        if continuous == nil, daily == nil { return nil }
        let continuousBudget = max(0, continuous ?? .greatestFiniteMagnitude)
        let dailyBudget = max(0, daily ?? .greatestFiniteMagnitude)
        let budget = min(continuousBudget, dailyBudget)
        guard budget.isFinite, budget > 0 else { return continuous ?? daily }
        return budget
    }

    private static func deadlineArc(
        currentArc: Double,
        budgetSeconds: TimeInterval,
        pathDurations: [TimeInterval],
        pathArcs: [Double]?,
        speedMps: Double,
        trafficFactor: Double,
        routeEndArc: Double
    ) -> Double {
        guard budgetSeconds > 0 else { return currentArc }

        if let pathArcs, pathArcs.count == pathDurations.count, !pathDurations.isEmpty {
            var cumulative: TimeInterval = 0
            for (index, duration) in pathDurations.enumerated() {
                let segmentStart = index == 0 ? 0 : pathArcs[index - 1]
                let segmentEnd = pathArcs[index]
                guard segmentEnd > currentArc else { continue }
                let traversedStart = max(currentArc, segmentStart)
                let segmentLength = max(segmentEnd - segmentStart, 1)
                let fraction = (segmentEnd - traversedStart) / segmentLength
                cumulative += duration * fraction * trafficFactor
                if cumulative > budgetSeconds {
                    return min(segmentEnd, routeEndArc)
                }
            }
            return routeEndArc
        }

        let remaining = max(0, routeEndArc - currentArc)
        let reachable = speedMps > 0.5
            ? min(remaining, speedMps * budgetSeconds / trafficFactor)
            : remaining
        return min(currentArc + reachable, routeEndArc)
    }

    private struct CompanyArcBand {
        let fromArc: Double
        let toArc: Double
        let windowStart: Date
    }

    private static func companyArcBand(
        breaks: [CompanyBreakAllocation],
        currentArc: Double,
        now: Date,
        pathDurations: [TimeInterval],
        pathArcs: [Double]?,
        speedMps: Double,
        trafficFactor: Double,
        routeEndArc: Double
    ) -> CompanyArcBand? {
        guard let allocation = breaks.first else { return nil }
        let window = allocation.window

        var fromArc = routeEndArc
        var toArc = currentArc
        var foundFrom = false
        var foundTo = false

        let sampleArcs: [Double]
        if let pathArcs, !pathArcs.isEmpty {
            sampleArcs = [currentArc] + pathArcs.filter { $0 >= currentArc }
        } else {
            sampleArcs = stride(from: currentArc, through: routeEndArc, by: max(500, (routeEndArc - currentArc) / 40)).map { $0 }
        }

        for arc in sampleArcs {
            let eta = timeToReachArc(
                from: currentArc,
                to: arc,
                pathDurations: pathDurations,
                pathArcs: pathArcs,
                speedMps: speedMps,
                trafficFactor: trafficFactor
            )
            let arrival = now.addingTimeInterval(eta)
            if arrival >= window.start, !foundFrom {
                fromArc = arc
                foundFrom = true
            }
            if arrival <= window.end {
                toArc = max(toArc, arc)
                foundTo = true
            }
        }

        guard foundFrom, foundTo, fromArc <= toArc else { return nil }
        return CompanyArcBand(fromArc: fromArc, toArc: toArc, windowStart: window.start)
    }

    private static func physicsPreferredCapArc(
        kineticStress: [SegmentKineticStress]?,
        pathDurations: [TimeInterval],
        pathArcs: [Double]?,
        currentArc: Double,
        deadlineArc: Double
    ) -> Double? {
        guard let kineticStress, !kineticStress.isEmpty else { return nil }

        let deadlineIndex: Int
        if let pathArcs, pathArcs.count == pathDurations.count {
            deadlineIndex = pathArcs.firstIndex(where: { $0 >= deadlineArc }) ?? (pathArcs.count - 1)
        } else {
            deadlineIndex = min(kineticStress.count - 1, pathDurations.count - 1)
        }

        let upper = min(deadlineIndex, kineticStress.count - 1)
        guard upper >= 0 else { return nil }

        for index in 0...upper {
            let sample = kineticStress[index]
            if sample.thermalStressScore >= HosRestInserter.thermalStressThreshold
                || abs(sample.gradePercentage) >= HosRestInserter.gradeStressThreshold {
                if let pathArcs, index < pathArcs.count {
                    let capIndex = max(index - 1, 0)
                    return pathArcs[capIndex]
                }
                let fraction = Double(index) / Double(max(1, kineticStress.count - 1))
                return currentArc + fraction * max(0, deadlineArc - currentArc)
            }
        }
        return nil
    }

    // MARK: - Ranking

    private struct ScoredStop {
        let stop: LaybyStop
        let confidence: Double
        let occupancyPrior: LaybyOccupancyPrior
    }

    private static func rankCandidates(
        _ candidates: [LaybyStop],
        preferBeforeArc: Double,
        mayStopFrom: Double,
        now: Date,
        trafficFactor: Double,
        input: LaybyPredictionInput
    ) -> [ScoredStop] {
        let scored = candidates.compactMap { stop -> ScoredStop? in
            guard let arc = stop.arcLengthAlongRouteMeters else { return nil }
            let eta = timeToReachArc(
                from: input.currentArcLengthMeters,
                to: arc,
                pathDurations: input.pathDurationsSeconds,
                pathArcs: input.pathArcLengthsMeters,
                speedMps: input.speedMps,
                trafficFactor: trafficFactor
            )
            let arrival = now.addingTimeInterval(eta)
            let occupancy = ParkingOccupancyPrior.laybyOccupancyPrior(
                at: arrival,
                for: stop,
                reports: input.crowdReports
            )
            let occupancyScore = occupancyRankScore(occupancy)
            let bandPenalty = arc < mayStopFrom ? -0.25 : 0
            let positionScore = 1.0 - abs(arc - preferBeforeArc) / max(preferBeforeArc, 1)
            let confidence = min(1, max(0.4, 0.55 + positionScore * 0.25 + occupancyScore * 0.15 + bandPenalty))
            return ScoredStop(stop: stop, confidence: confidence, occupancyPrior: occupancy)
        }

        return scored.sorted { lhs, rhs in
            let lArc = lhs.stop.arcLengthAlongRouteMeters ?? 0
            let rArc = rhs.stop.arcLengthAlongRouteMeters ?? 0
            let lDeadlineDelta = abs(lArc - preferBeforeArc)
            let rDeadlineDelta = abs(rArc - preferBeforeArc)
            let equivalentThreshold = max(2_000, preferBeforeArc * 0.05)
            if abs(lDeadlineDelta - rDeadlineDelta) <= equivalentThreshold {
                let lOcc = occupancyRankScore(lhs.occupancyPrior)
                let rOcc = occupancyRankScore(rhs.occupancyPrior)
                if lOcc != rOcc { return lOcc > rOcc }
            }
            if lDeadlineDelta != rDeadlineDelta {
                return lDeadlineDelta < rDeadlineDelta
            }
            let lOcc = occupancyRankScore(lhs.occupancyPrior)
            let rOcc = occupancyRankScore(rhs.occupancyPrior)
            if lOcc != rOcc { return lOcc > rOcc }
            return lArc > rArc
        }
    }

    private static func occupancyRankScore(_ prior: LaybyOccupancyPrior) -> Double {
        switch prior {
        case .low: return 1.0
        case .moderate: return 0.6
        case .high: return 0.2
        }
    }

    private static func geometryFallback(
        eligible: [LaybyStop],
        input: LaybyPredictionInput,
        trafficFactor: Double,
        note: String = ""
    ) -> LaybyPredictionResult {
        guard let stop = eligible.first,
              let arc = stop.arcLengthAlongRouteMeters else {
            return LaybyPredictionResult(ranked: [])
        }
        _ = note
        let advisory = makeAdvisory(
            stop: stop,
            input: input,
            trafficFactor: trafficFactor,
            confidence: 0.35,
            occupancyPrior: ParkingOccupancyPrior.laybyOccupancyPrior(
                at: input.now.addingTimeInterval(
                    timeToReachArc(
                        from: input.currentArcLengthMeters,
                        to: arc,
                        pathDurations: input.pathDurationsSeconds,
                        pathArcs: input.pathArcLengthsMeters,
                        speedMps: input.speedMps,
                        trafficFactor: trafficFactor
                    )
                ),
                for: stop,
                reports: input.crowdReports
            ),
            breakWindowOpensAt: nil,
            reasonCodes: [.geometryFallback],
            isAdvisory: false
        )
        return LaybyPredictionResult(ranked: [advisory])
    }

    private static func makeAdvisory(
        stop: LaybyStop,
        input: LaybyPredictionInput,
        trafficFactor: Double,
        confidence: Double,
        occupancyPrior: LaybyOccupancyPrior,
        breakWindowOpensAt: Date?,
        reasonCodes: [LaybyReasonCode],
        isAdvisory: Bool
    ) -> LaybyAdvisory {
        let latestSignal = ParkingOccupancyPrior.latestOccupancySignal(
            for: stop,
            reports: input.crowdReports
        )
        guard let arc = stop.arcLengthAlongRouteMeters else {
            return LaybyAdvisory(
                stop: stop,
                distanceRemainingMeters: 0,
                confidence: confidence,
                occupancyPrior: occupancyPrior,
                breakWindowOpensAt: breakWindowOpensAt,
                reasonCodes: reasonCodes,
                isAdvisory: isAdvisory,
                lastOccupancyReportAt: latestSignal?.createdAt,
                lastOccupancyKind: latestSignal?.kind
            )
        }
        let remaining = max(0, arc - input.currentArcLengthMeters)
        let eta = input.speedMps > 0.5
            ? (remaining / input.speedMps) * trafficFactor
            : timeToReachArc(
                from: input.currentArcLengthMeters,
                to: arc,
                pathDurations: input.pathDurationsSeconds,
                pathArcs: input.pathArcLengthsMeters,
                speedMps: input.speedMps,
                trafficFactor: trafficFactor
            )
        return LaybyAdvisory(
            stop: stop,
            distanceRemainingMeters: remaining,
            estimatedArrivalSeconds: eta,
            confidence: confidence,
            occupancyPrior: occupancyPrior,
            breakWindowOpensAt: breakWindowOpensAt,
            reasonCodes: reasonCodes,
            isAdvisory: isAdvisory,
            lastOccupancyReportAt: latestSignal?.createdAt,
            lastOccupancyKind: latestSignal?.kind
        )
    }

    private static func timeToReachArc(
        from currentArc: Double,
        to targetArc: Double,
        pathDurations: [TimeInterval],
        pathArcs: [Double]?,
        speedMps: Double,
        trafficFactor: Double
    ) -> TimeInterval {
        guard targetArc > currentArc else { return 0 }

        if let pathArcs, pathArcs.count == pathDurations.count, !pathDurations.isEmpty {
            var total: TimeInterval = 0
            for (index, duration) in pathDurations.enumerated() {
                let segmentStart = index == 0 ? 0 : pathArcs[index - 1]
                let segmentEnd = pathArcs[index]
                guard segmentEnd > currentArc else { continue }
                guard segmentStart < targetArc else { break }
                let overlapStart = max(currentArc, segmentStart)
                let overlapEnd = min(targetArc, segmentEnd)
                guard overlapEnd > overlapStart else { continue }
                let segmentLength = max(segmentEnd - segmentStart, 1)
                let fraction = (overlapEnd - overlapStart) / segmentLength
                total += duration * fraction
            }
            return total * trafficFactor
        }

        guard speedMps > 0.5 else { return 0 }
        return (targetArc - currentArc) / speedMps * trafficFactor
    }
}
