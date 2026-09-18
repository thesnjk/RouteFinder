import { useEffect, useRef } from 'react'
import {
  GeoJSONSource,
  LngLatBounds,
  Map as MapLibreMap,
  Marker,
  NavigationControl,
} from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'
import type { FleetTrip } from './fleet/types'

/** MapLibre GL preview of trip stop coordinates (OSM raster tiles). */
export function TripMapPreview({ trip }: { trip: FleetTrip | null }) {
  const containerRef = useRef<HTMLDivElement>(null)
  const mapRef = useRef<MapLibreMap | null>(null)

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
    if (!map || !trip || trip.stops.length === 0) return

    const markers: Marker[] = []
    const bounds = new LngLatBounds()

    for (const stop of trip.stops) {
      bounds.extend([stop.longitude, stop.latitude])
      const el = document.createElement('div')
      el.className = 'map-marker'
      el.textContent =
        stop.role === 'origin' ? 'A' : stop.role === 'destination' ? 'B' : String(stop.sequence)
      markers.push(new Marker({ element: el }).setLngLat([stop.longitude, stop.latitude]).addTo(map))
    }

    if (trip.driverLatitude != null && trip.driverLongitude != null) {
      bounds.extend([trip.driverLongitude, trip.driverLatitude])
      const el = document.createElement('div')
      el.className = 'map-marker map-marker--driver'
      el.title = 'Driver'
      markers.push(
        new Marker({ element: el }).setLngLat([trip.driverLongitude, trip.driverLatitude]).addTo(map),
      )
    }

    if (trip.stops.length === 1) {
      map.easeTo({ center: [trip.stops[0].longitude, trip.stops[0].latitude], zoom: 11 })
    } else {
      map.fitBounds(bounds, { padding: 48, maxZoom: 12 })
    }

    const coords = trip.stops.map((s) => [s.longitude, s.latitude] as [number, number])
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
  }, [trip])

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
