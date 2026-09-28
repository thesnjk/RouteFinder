/** ORS HGV directions helpers for web desk corridor preview (fleet proxy). */

export type LngLat = [number, number]

export interface HgvPreviewProfile {
  lengthMeters?: number
  widthMeters?: number
  heightMeters?: number
  weightTonnes?: number
  axleLoadTonnes?: number
}

const DEFAULT_HGV: Required<HgvPreviewProfile> = {
  lengthMeters: 16.5,
  widthMeters: 2.55,
  heightMeters: 4.0,
  weightTonnes: 40.0,
  axleLoadTonnes: 11.5,
}

/** Build ORS driving-hgv GeoJSON request body (coordinates are [lon, lat]). */
export function buildOrsHgvDirectionsBody(
  stops: Array<{ longitude: number; latitude: number }>,
  profile?: HgvPreviewProfile | null,
): Record<string, unknown> {
  const coordinates = stops.map((s) => [s.longitude, s.latitude])
  const v = { ...DEFAULT_HGV, ...profile }
  return {
    coordinates,
    options: {
      profile_params: {
        restrictions: {
          length: v.lengthMeters,
          width: v.widthMeters,
          height: v.heightMeters,
          weight: v.weightTonnes,
          axleload: v.axleLoadTonnes,
        },
      },
    },
    instructions: false,
    geometry: true,
  }
}

/**
 * Extract a LineString corridor from ORS GeoJSON FeatureCollection / Feature.
 * Returns empty array when geometry is missing or malformed.
 */
export function parseOrsGeoJsonCoordinates(payload: unknown): LngLat[] {
  if (!payload || typeof payload !== 'object') return []
  const root = payload as Record<string, unknown>
  const features = Array.isArray(root.features) ? root.features : [root]
  for (const feature of features) {
    if (!feature || typeof feature !== 'object') continue
    const geometry = (feature as Record<string, unknown>).geometry
    if (!geometry || typeof geometry !== 'object') continue
    const g = geometry as { type?: string; coordinates?: unknown }
    const coords = extractLineCoords(g.type, g.coordinates)
    if (coords.length >= 2) return coords
  }
  return []
}

function extractLineCoords(type: string | undefined, coordinates: unknown): LngLat[] {
  if (!Array.isArray(coordinates) || coordinates.length === 0) return []
  if (type === 'LineString') {
    return normalizeLngLats(coordinates)
  }
  if (type === 'MultiLineString') {
    const first = coordinates[0]
    return Array.isArray(first) ? normalizeLngLats(first) : []
  }
  return []
}

function normalizeLngLats(raw: unknown[]): LngLat[] {
  const out: LngLat[] = []
  for (const pair of raw) {
    if (!Array.isArray(pair) || pair.length < 2) continue
    const lon = Number(pair[0])
    const lat = Number(pair[1])
    if (!Number.isFinite(lon) || !Number.isFinite(lat)) continue
    out.push([lon, lat])
  }
  return out
}
