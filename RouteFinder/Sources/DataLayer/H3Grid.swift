import Contracts
import Foundation

/// Spatial hex-grid indexer compatible with H3 resolution semantics.
public enum H3Grid {
    /// Default resolution (~1.2 km² cells, similar to H3 resolution 7).
    public static let defaultResolution = 7

    /// Cell size in degrees at the given resolution.
    public static func cellSizeDegrees(resolution: Int = defaultResolution) -> Double {
        0.01 * pow(2.0, Double(9 - resolution))
    }

    /// Returns the H3 cell containing the given coordinate.
    public static func cell(for coordinate: Coordinate, resolution: Int = defaultResolution) -> H3CellIndex {
        let size = cellSizeDegrees(resolution: resolution)
        let row = Int(floor((coordinate.latitude + 90) / size))
        let col = Int(floor((coordinate.longitude + 180) / size))
        let encoded = (UInt64(resolution) << 56) | (UInt64(row) << 28) | UInt64(col)
        return H3CellIndex(value: encoded)
    }

    /// Returns neighboring cells at the given ring distance.
    public static func neighbors(of cell: H3CellIndex, ring: Int = 1) -> [H3CellIndex] {
        let resolution = Int((cell.value >> 56) & 0xFF)
        let row = Int((cell.value >> 28) & 0xFFFFFFF)
        let col = Int(cell.value & 0xFFFFFFF)

        var cells: [H3CellIndex] = []
        for dr in -ring...ring {
            for dc in -ring...ring {
                if max(abs(dr), abs(dc)) == ring {
                    let encoded = (UInt64(resolution) << 56) | (UInt64(row + dr) << 28) | UInt64(col + dc)
                    cells.append(H3CellIndex(value: encoded))
                }
            }
        }
        return cells
    }

    /// Returns all cells covering the corridor between two coordinates with buffer rings.
    public static func corridor(
        from: Coordinate,
        to: Coordinate,
        bufferRings: Int = 2,
        resolution: Int = defaultResolution
    ) -> Set<H3CellIndex> {
        var cells: Set<H3CellIndex> = []
        let startCell = cell(for: from, resolution: resolution)
        let endCell = cell(for: to, resolution: resolution)

        cells.insert(startCell)
        cells.insert(endCell)

        for ring in 0...bufferRings {
            cells.formUnion(neighbors(of: startCell, ring: ring))
            cells.formUnion(neighbors(of: endCell, ring: ring))
        }

        let steps = 20
        for step in 0...steps {
            let t = Double(step) / Double(steps)
            let lat = from.latitude + (to.latitude - from.latitude) * t
            let lon = from.longitude + (to.longitude - from.longitude) * t
            let midCell = cell(for: Coordinate(latitude: lat, longitude: lon), resolution: resolution)
            cells.insert(midCell)
            for ring in 0...bufferRings {
                cells.formUnion(neighbors(of: midCell, ring: ring))
            }
        }

        return cells
    }

    /// Returns all cells whose centers (sampled on a half-cell lattice) fall inside the bbox.
    ///
    /// Used by offline tile download to determine which `*.graphjson` files cover a region.
    public static func cellsCovering(
        minLat: Double,
        maxLat: Double,
        minLon: Double,
        maxLon: Double,
        resolution: Int = defaultResolution
    ) -> Set<H3CellIndex> {
        let size = cellSizeDegrees(resolution: resolution)
        let step = max(size * 0.5, 1e-6)
        var cells: Set<H3CellIndex> = []
        var lat = min(minLat, maxLat)
        let latMax = max(minLat, maxLat)
        let lonMin = min(minLon, maxLon)
        let lonMax = max(minLon, maxLon)

        while lat <= latMax + step {
            var lon = lonMin
            while lon <= lonMax + step {
                cells.insert(cell(for: Coordinate(latitude: lat, longitude: lon), resolution: resolution))
                lon += step
            }
            lat += step
        }

        // Corner samples ensure edge coverage when the lattice misses boundaries.
        for (latCorner, lonCorner) in [
            (minLat, minLon), (minLat, maxLon), (maxLat, minLon), (maxLat, maxLon)
        ] {
            cells.insert(cell(for: Coordinate(latitude: latCorner, longitude: lonCorner), resolution: resolution))
        }
        return cells
    }
}
