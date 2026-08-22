import Contracts
import Foundation

/// Grade percentages sampled along a route polyline.
public struct ElevationProfile: Sendable, Hashable {
    /// Source coordinates used to build the profile.
    public let coordinates: [Coordinate]
    /// Cumulative arc lengths at each coordinate (meters), same count as source coordinates.
    public let cumulativeLengths: [Double]
    /// Grade percentage per segment index (length = coordinates.count - 1).
    public let gradesPercent: [Double]

    /// Creates an elevation profile from coordinates with optional elevation data.
    public init(coordinates: [Coordinate]) {
        self.coordinates = coordinates
        guard coordinates.count >= 2 else {
            cumulativeLengths = coordinates.isEmpty ? [] : [0]
            gradesPercent = []
            return
        }

        var cumulative: [Double] = [0]
        var grades: [Double] = []

        for index in 0..<(coordinates.count - 1) {
            let from = coordinates[index]
            let to = coordinates[index + 1]
            let horizontal = Self.horizontalDistanceMeters(from: from, to: to)
            cumulative.append(cumulative.last! + horizontal)

            let rise = (to.elevationMeters ?? from.elevationMeters ?? 0) - (from.elevationMeters ?? 0)
            let grade = horizontal > 0.5 ? (rise / horizontal) * 100 : 0
            grades.append(grade)
        }

        cumulativeLengths = cumulative
        gradesPercent = grades
    }

    /// Returns the grade percentage at the given arc length along the route.
    public func gradePercent(atArcLength arcLength: Double) -> Double {
        guard let segment = segmentState(atArcLength: arcLength) else { return 0 }

        let startGrade = gradesPercent[segment.index]
        let endIndex = min(segment.index + 1, gradesPercent.count - 1)
        let endGrade = gradesPercent[endIndex]
        return startGrade + (endGrade - startGrade) * segment.fraction
    }

    /// Returns interpolated elevation in meters at the given arc length.
    public func elevationMeters(atArcLength arcLength: Double) -> Double? {
        guard coordinates.count >= 2, let segment = segmentState(atArcLength: arcLength) else {
            return coordinates.first?.elevationMeters
        }

        let from = coordinates[segment.index]
        let to = coordinates[min(segment.index + 1, coordinates.count - 1)]
        guard let fromElevation = from.elevationMeters, let toElevation = to.elevationMeters else {
            return from.elevationMeters ?? to.elevationMeters
        }
        return fromElevation + (toElevation - fromElevation) * segment.fraction
    }

    /// Maximum absolute grade magnitude along the profile.
    public var maxAbsoluteGradePercent: Double {
        gradesPercent.map { abs($0) }.max() ?? 0
    }

    private struct SegmentState {
        let index: Int
        let fraction: Double
    }

    private func segmentState(atArcLength arcLength: Double) -> SegmentState? {
        guard !gradesPercent.isEmpty, cumulativeLengths.count >= 2 else { return nil }

        let clamped = min(max(arcLength, 0), cumulativeLengths.last ?? 0)
        for index in 0..<gradesPercent.count {
            let segmentEnd = cumulativeLengths[index + 1]
            if clamped <= segmentEnd || index == gradesPercent.count - 1 {
                let segmentStart = cumulativeLengths[index]
                let length = max(segmentEnd - segmentStart, 0.001)
                let fraction = min(1, max(0, (clamped - segmentStart) / length))
                return SegmentState(index: index, fraction: fraction)
            }
        }
        let lastIndex = max(0, gradesPercent.count - 1)
        return SegmentState(index: lastIndex, fraction: 1)
    }

    private static func horizontalDistanceMeters(from: Coordinate, to: Coordinate) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLat = (to.latitude - from.latitude) * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180
        let sinDLat = sin(deltaLat / 2)
        let sinDLon = sin(deltaLon / 2)
        let h = sinDLat * sinDLat + cos(lat1) * cos(lat2) * sinDLon * sinDLon
        return 2 * earthRadius * atan2(sqrt(h), sqrt(max(0, 1 - h)))
    }
}
