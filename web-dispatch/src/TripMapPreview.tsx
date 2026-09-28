import { useEffect, useMemo, useRef } from 'react'
import {
  GeoJSONSource,
  LngLatBounds,
  Map as MapLibreMap,
  Marker,
  NavigationControl,
} from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'
import type { FleetApiClient, HgvPreviewProfile, LngLat } from './fleet/client'
import type { FleetTrip } from './fleet/types'
import {
  fleetPinsFingerprint,
  type RosterDriverPin,
} from './fleetRoster'
import { tripMapFingerprint, tripMapFetchFingerprint } from './tripMapFingerprint'

function setTripLine(map: MapLibreMap, coords: LngLat[]) {
  if (coords.length < 2) return
  const sourceId = 'trip-line'
  const data = {
    type: 'Feature' as const,
    properties: {},
    geometry: { type: 'LineString' as const, coordinates: coords },
  }
  const existing = map.getSource(sourceId)
  if (existing) {
    ;(existing as GeoJSONSource).setData(data)
  } else {
    map.addSource(sourceId, { type: 'geojson', data })
    map.addLayer({
      id: 'trip-line-layer',
      type: 'line',
      source: sourceId,
      paint: { 'line-color': '#0f766e', 'line-width': 4 },
    })
  }
}

function clearTripLine(map: MapLibreMap) {
  if (map.getLayer('trip-line-layer')) map.removeLayer('trip-line-layer')
  if (map.getSource('trip-line')) map.removeSource('trip-line')
}

/** MapLibre GL preview: selected trip corridor + fleet-wide driver GPS pins. */
export function TripMapPreview({
  trip,
  client,
  vehicleProfile,
  onRoutePreviewError,
  fleetPins = [],
  selectedVehicleId = null,
}: {
  trip: FleetTrip | null
  client: FleetApiClient | null
  vehicleProfile?: HgvPreviewProfile | null
  /** Fired when fleet ORS corridor preview fails (429/cap, network); map keeps straight-line. */
  onRoutePreviewError?: (message: string) => void
  /** Yard pins from roster GPS (no per-truck ORS). */
  fleetPins?: RosterDriverPin[]
  selectedVehicleId?: string | null
}) {
  const containerRef = useRef<HTMLDivElement>(null)
  const mapRef = useRef<MapLibreMap | null>(null)
  const tripRef = useRef(trip)
  tripRef.current = trip
  const clientRef = useRef(client)
  clientRef.current = client
  const profileRef = useRef(vehicleProfile)
  profileRef.current = vehicleProfile
  const onErrorRef = useRef(onRoutePreviewError)
  onErrorRef.current = onRoutePreviewError
  const pinsRef = useRef(fleetPins)
  pinsRef.current = fleetPins
  const selectedRef = useRef(selectedVehicleId)
  selectedRef.current = selectedVehicleId

  const tripFp = useMemo(() => tripMapFingerprint(trip), [trip])
  const pinsFp = useMemo(() => fleetPinsFingerprint(fleetPins), [fleetPins])
  const fingerprint = tripMapFetchFingerprint({
    tripFp,
    pinsFp,
    selectedVehicleId,
    orsReady: client != null,
    weightTonnes: vehicleProfile?.weightTonnes ?? null,
  })

  const hasTripCorridor = trip != null && trip.stops.length >= 2
  const hasYardPins = fleetPins.length > 0
  const showMap = hasTripCorridor || hasYardPins

  useEffect(() => {
    if (!showMap || !containerRef.current) return
    if (mapRef.current) return

    const map = new MapLibreMap({
      container: containerRef.current,
      style: {
        version: 8,
        sources: {
          osm: {
            type: 'raster',
            tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'],
            tileSize: 256,
            attribution: '© OpenStreetMap',
          },
        },
        layers: [{ id: 'osm', type: 'raster', source: 'osm' }],
      },
      center: [1.2974, 52.6309],
      zoom: 8,
    })
    map.addControl(new NavigationControl({ showCompass: false }), 'top-right')
    mapRef.current = map

    return () => {
      map.remove()
      mapRef.current = null
    }
  }, [showMap])

  useEffect(() => {
    const map = mapRef.current
    if (!map || (tripFp === 'empty' && pinsFp === 'none')) return

    let cancelled = false
    const markers: Marker[] = []
    const bounds = new LngLatBounds()
    let hasBounds = false
    const current = tripRef.current
    const pins = pinsRef.current
    const selectedId = selectedRef.current

    if (current && current.stops.length > 0) {
      for (const stop of current.stops) {
        bounds.extend([stop.longitude, stop.latitude])
        hasBounds = true
        const el = document.createElement('div')
        el.className = 'map-marker'
        el.textContent =
          stop.role === 'origin' ? 'A' : stop.role === 'destination' ? 'B' : String(stop.sequence)
        markers.push(new Marker({ element: el }).setLngLat([stop.longitude, stop.latitude]).addTo(map))
      }
    }

    const selectedHasRosterPin =
      selectedId != null && pins.some((p) => p.vehicleId === selectedId)

    for (const pin of pins) {
      bounds.extend([pin.longitude, pin.latitude])
      hasBounds = true
      const selected = pin.vehicleId === selectedId
      const el = document.createElement('div')
      el.className = selected
        ? 'map-marker map-marker--driver map-marker--selected'
        : 'map-marker map-marker--fleet'
      el.title = pin.label
      el.textContent = selected ? '●' : pin.label.slice(0, 1).toUpperCase()
      markers.push(
        new Marker({ element: el }).setLngLat([pin.longitude, pin.latitude]).addTo(map),
      )
    }

    if (
      current?.driverLatitude != null &&
      current.driverLongitude != null &&
      !selectedHasRosterPin
    ) {
      bounds.extend([current.driverLongitude, current.driverLatitude])
      hasBounds = true
      const el = document.createElement('div')
      el.className = 'map-marker map-marker--driver'
      el.title = 'Driver'
      markers.push(
        new Marker({ element: el })
          .setLngLat([current.driverLongitude, current.driverLatitude])
          .addTo(map),
      )
    }

    if (hasBounds) {
      if (current && current.stops.length === 1 && pins.length === 0) {
        map.easeTo({
          center: [current.stops[0].longitude, current.stops[0].latitude],
          zoom: 11,
        })
      } else {
        map.fitBounds(bounds, { padding: 48, maxZoom: 12 })
      }
    }

    if (current && current.stops.length >= 2) {
      const straightLine = current.stops.map(
        (s) => [s.longitude, s.latitude] as LngLat,
      )
      setTripLine(map, straightLine)

      const api = clientRef.current
      if (api) {
        const ordered = [...current.stops].sort((a, b) => a.sequence - b.sequence)
        void api
          .routePreviewHGV(ordered, profileRef.current)
          .then((corridor) => {
            if (cancelled || corridor.length < 2) return
            setTripLine(map, corridor)
            const corridorBounds = new LngLatBounds()
            for (const [lng, lat] of corridor) corridorBounds.extend([lng, lat])
            for (const pin of pinsRef.current) {
              corridorBounds.extend([pin.longitude, pin.latitude])
            }
            map.fitBounds(corridorBounds, { padding: 48, maxZoom: 12 })
          })
          .catch((err: unknown) => {
            const message = err instanceof Error ? err.message : String(err)
            onErrorRef.current?.(message)
          })
      }
    } else {
      clearTripLine(map)
    }

    return () => {
      cancelled = true
      for (const marker of markers) marker.remove()
    }
  }, [fingerprint, tripFp, pinsFp])

  if (!showMap) {
    return (
      <div className="map-preview map-preview--empty">
        Push a trip to preview the corridor, or wait for cab GPS on the fleet roster.
      </div>
    )
  }

  return (
    <div className="map-preview">
      <div ref={containerRef} className="map-preview__canvas" />
    </div>
  )
}
