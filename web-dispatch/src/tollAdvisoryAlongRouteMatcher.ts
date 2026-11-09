import {
  UK_TOLL_ADVISORY_CATALOG,
  type UKTollAdvisory,
} from './ukTollAdvisoryCatalog'

/** Corridor vertex as [longitude, latitude] (GeoJSON / MapLibre order). */
export type CorridorLngLat = readonly [number, number]

const EARTH_RADIUS_M = 6_371_000

/** Haversine distance in metres between two WGS84 points. */
export function haversineMeters(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
): number {
  const toRad = (deg: number) => (deg * Math.PI) / 180
  const dLat = toRad(lat2 - lat1)
  const dLon = toRad(lon2 - lon1)
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2
  return 2 * EARTH_RADIUS_M * Math.asin(Math.min(1, Math.sqrt(a)))
}

/**
 * Returns catalog advisories whose approach radius intersects any route vertex,
 * ordered by first hit along the polyline (Swift `TollAdvisoryAlongRouteMatcher` parity).
 */
export function advisoriesAlongRoute(
  coordinates: CorridorLngLat[],
  catalog: UKTollAdvisory[] = UK_TOLL_ADVISORY_CATALOG,
): UKTollAdvisory[] {
  if (coordinates.length < 2 || catalog.length === 0) return []

  const hits: { index: number; advisory: UKTollAdvisory }[] = []
  const seen = new Set<string>()

  for (const advisory of catalog) {
    let firstIndex: number | undefined
    for (let index = 0; index < coordinates.length; index++) {
      const [lng, lat] = coordinates[index]
      const distance = haversineMeters(
        lat,
        lng,
        advisory.latitude,
        advisory.longitude,
      )
      if (distance <= advisory.approachRadiusMeters) {
        firstIndex = index
        break
      }
    }
    if (firstIndex != null && !seen.has(advisory.id)) {
      seen.add(advisory.id)
      hits.push({ index: firstIndex, advisory })
    }
  }

  return hits.sort((a, b) => a.index - b.index).map((h) => h.advisory)
}
