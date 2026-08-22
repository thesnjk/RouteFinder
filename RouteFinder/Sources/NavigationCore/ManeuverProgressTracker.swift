import Contracts
import Foundation

/// Tracks advancement through turn-by-turn instructions based on arc-length progress.
public struct ManeuverProgressTracker: Sendable {
    private let instructions: [TurnInstruction]
    private let cumulativeArcLengths: [Double]

    /// Creates a maneuver progress tracker.
    ///
    /// - Parameters:
    ///   - instructions: Ordered turn instructions for the active route.
    ///   - cumulativeArcLengths: Cumulative arc lengths at each instruction anchor, aligned by index.
    public init(instructions: [TurnInstruction], cumulativeArcLengths: [Double] = []) {
        self.instructions = instructions
        self.cumulativeArcLengths = cumulativeArcLengths
    }

    /// Returns the index of the current upcoming maneuver for the given arc length.
    public func currentManeuverIndex(for arcLengthMeters: Double) -> Int? {
        guard !instructions.isEmpty else { return nil }

        if cumulativeArcLengths.isEmpty {
            let perSegment = instructions.count > 1 ? 1.0 / Double(instructions.count) : 1.0
            let fraction = arcLengthMeters > 0 ? min(1, arcLengthMeters) : 0
            let index = min(instructions.count - 1, Int(fraction / perSegment))
            return index
        }

        for index in stride(from: cumulativeArcLengths.count - 1, through: 0, by: -1) {
            if arcLengthMeters >= cumulativeArcLengths[index] {
                return min(index, instructions.count - 1)
            }
        }
        return 0
    }

    /// Returns the current upcoming turn instruction, if any.
    public func currentManeuver(for arcLengthMeters: Double) -> TurnInstruction? {
        guard let index = currentManeuverIndex(for: arcLengthMeters) else { return nil }
        return instructions[index]
    }
}
