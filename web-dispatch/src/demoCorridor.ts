import type { GeocodedStop } from './GeocodeSearchField'

/** Demo-script corridor coords — must match Mac `DispatchTripDraft.norfolkDemoCorridor()`. */
export const NORWICH: GeocodedStop = {
  label: 'Norwich',
  latitude: 52.6309,
  longitude: 1.2974,
}

/** Demo-script destination — must match Mac `norfolkDemoCorridor()`. */
export const KINGS_LYNN: GeocodedStop = {
  label: "King's Lynn",
  latitude: 52.7519,
  longitude: 0.3955,
}

/** Resolved origin/dest for one-tap Load without Pelias. */
export function loadNorfolkDemoStops(): { origin: GeocodedStop; destination: GeocodedStop } {
  return { origin: { ...NORWICH }, destination: { ...KINGS_LYNN } }
}
