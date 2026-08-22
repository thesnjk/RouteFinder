import Contracts
import Foundation

/// Fills missing elevation samples in route coordinates before grade analysis.
public enum ElevationGapFiller: Sendable {
    /// Linearly interpolates `nil` elevations between known samples; leading/trailing gaps use nearest known value.
    public static func fillGaps(in coordinates: [Coordinate]) -> [Coordinate] {
        guard !coordinates.isEmpty else { return coordinates }

        let elevations = coordinates.map(\.elevationMeters)
        guard elevations.contains(where: { $0 != nil }) else { return coordinates }

        var filled = elevations
        var index = 0
        while index < filled.count {
            guard filled[index] == nil else {
                index += 1
                continue
            }

            let gapStart = index
            while index < filled.count, filled[index] == nil {
                index += 1
            }
            let gapEnd = index

            let before = gapStart > 0 ? filled[gapStart - 1] : nil
            let after = gapEnd < filled.count ? filled[gapEnd] : nil

            if let before, let after {
                let span = gapEnd - gapStart + 1
                for offset in 0..<(gapEnd - gapStart) {
                    let t = Double(offset + 1) / Double(span)
                    filled[gapStart + offset] = before + (after - before) * t
                }
            } else if let before {
                for offset in gapStart..<gapEnd {
                    filled[offset] = before
                }
            } else if let after {
                for offset in gapStart..<gapEnd {
                    filled[offset] = after
                }
            }
        }

        return zip(coordinates, filled).map { coordinate, elevation in
            Coordinate(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                elevationMeters: elevation
            )
        }
    }
}
