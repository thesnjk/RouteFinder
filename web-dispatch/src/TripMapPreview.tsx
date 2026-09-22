import { useEffect, useMemo, useRef } from 'react'
import {
  GeoJSONSource,
  LngLatBounds,
  Map as MapLibreMap,
  Marker,
  NavigationControl,
} from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'
import type { FleetTrip } from './fleet/types'
import { tripMapFingerprint } from './tripMapFingerprint'

/** MapLibre GL preview of trip stop coordinates (OSM raster tiles). */
export function TripMapPreview({ trip }: { trip: FleetTrip | null }) {
  const containerRef = useRef<HTMLDivElement>(null)
  const mapRef = useRef<MapLibreMap | null>(null)
  const tripRef = useRef(trip)
  tripRef.current = trip
  const fingerprint = useMemo(() => tripMapFingerprint(trip), [trip])

  useEffect(() => {
    if (!containerRef.current) return
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
  }, [])

  useEffect(() => {
    const map = mapRef.current
    const current = tripRef.current
    if (!map || !current || current.stops.length === 0 || fingerprint === 'empty') return

    const markers: Marker[] = []
    const bounds = new LngLatBounds()

    for (const stop of current.stops) {
      bounds.extend([stop.longitude, stop.latitude])
      const el = document.createElement('div')
      el.className = 'map-marker'
      el.textContent =
        stop.role === 'origin' ? 'A' : stop.role === 'destination' ? 'B' : String(stop.sequence)
      markers.push(new Marker({ element: el }).setLngLat([stop.longitude, stop.latitude]).addTo(map))
    }

    if (current.driverLatitude != null && current.driverLongitude != null) {
      bounds.extend([current.driverLongitude, current.driverLatitude])
      const el = document.createElement('div')
      el.className = 'map-marker map-marker--driver'
      el.title = 'Driver'
      markers.push(
        new Marker({ element: el })
          .setLngLat([current.driverLongitude, current.driverLatitude])
          .addTo(map),
      )
    }

    if (current.stops.length === 1) {
      map.easeTo({
        center: [current.stops[0].longitude, current.stops[0].latitude],
        zoom: 11,
      })
    } else {
      map.fitBounds(bounds, { padding: 48, maxZoom: 12 })
    }

    const coords = current.stops.map((s) => [s.longitude, s.latitude] as [number, number])
    const sourceId = 'trip-line'
    const existing = map.getSource(sourceId)
    if (existing) {
      ;(existing as GeoJSONSource).setData({
        type: 'Feature',
        properties: {},
        geometry: { type: 'LineString', coordinates: coords },
      })
    } else {
      map.addSource(sourceId, {
        type: 'geojson',
        data: {
          type: 'Feature',
          properties: {},
          geometry: { type: 'LineString', coordinates: coords },
        },
      })
      map.addLayer({
        id: 'trip-line-layer',
        type: 'line',
        source: sourceId,
        paint: { 'line-color': '#0f766e', 'line-width': 4 },
      })
    }

    return () => {
      for (const marker of markers) marker.remove()
    }
  }, [fingerprint])

  if (!trip || trip.stops.length < 2) {
    return (
      <div className="map-preview map-preview--empty">
        Push a trip to preview the corridor on the map.
      </div>
    )
  }

  return (
    <div className="map-preview">
      <div ref={containerRef} className="map-preview__canvas" />
    </div>
  )
}
