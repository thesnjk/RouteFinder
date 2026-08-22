import Contracts
import Foundation

/// Builds geometry-index-aligned speed limit spines for canonical route processing.
public enum SpeedLimitSpineBinder: Sendable {
    /// Propagates speed limits across gap-filled coordinate arrays.
    public static func fillGaps(in limits: [Double?], coordinateCount: Int) -> [Double?] {
        guard coordinateCount > 0 else { return [] }
        guard !limits.isEmpty else { return Array(repeating: nil, count: coordinateCount) }

        var result = Array(repeating: Double?.none, count: coordinateCount)
        let copyCount = min(limits.count, coordinateCount)
        for index in 0..<copyCount {
            result[index] = limits[index]
        }

        var lastKnown: Double?
        for index in 0..<coordinateCount {
            if let value = result[index] {
                lastKnown = value
            } else if let lastKnown {
                result[index] = lastKnown
            }
        }

        var nextKnown: Double?
        for index in stride(from: coordinateCount - 1, through: 0, by: -1) {
            if let value = result[index] {
                nextKnown = value
            } else if let nextKnown {
                result[index] = nextKnown
            }
        }
        return result
    }

    /// Returns the speed limit in m/s at a raw coordinate index when available.
    public static func limitMps(at index: Int, from limitsKmh: [Double?]) -> Double? {
        guard limitsKmh.indices.contains(index), let kmh = limitsKmh[index] else { return nil }
        return kmh / 3.6
    }

    /// Applies step-index speed ranges to a raw geometry limit array.
    public static func applyStepRanges(
        to limits: inout [Double?],
        ranges: [ORSStepSpeedRange]
    ) {
        for range in ranges {
            guard let limit = range.speedLimitKmh else { continue }
            let start = max(0, range.startIndex)
            let end = min(limits.count - 1, range.endIndex)
            guard start <= end, end >= 0, start < limits.count else { continue }
            for index in start...end where limits[index] == nil {
                limits[index] = limit
            }
        }
    }
}
