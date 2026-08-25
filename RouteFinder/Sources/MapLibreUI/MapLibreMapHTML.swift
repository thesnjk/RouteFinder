import Foundation

enum MapLibreMapHTML {
    static func page(
        styleURL: String,
        scriptURL: String,
        cssURL: String,
        inlineScript: String? = nil,
        inlineStyleSheet: String? = nil
    ) -> String {
        let cssTag: String
        if let inlineStyleSheet {
            cssTag = "<style>\n\(inlineStyleSheet)\n</style>"
        } else {
            cssTag = "<link href=\"\(cssURL)\" rel=\"stylesheet\"/>"
        }

        let scriptTag: String
        if let inlineScript {
            scriptTag = "<script>\n\(inlineScript)\n</script>"
        } else {
            scriptTag = "<script src=\"\(scriptURL)\"></script>"
        }

        return """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8"/>
          <meta name="viewport" content="width=device-width, initial-scale=1"/>
          \(cssTag)
          \(scriptTag)
          <style>
            html, body, #map { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; }
            .maplibregl-ctrl-attrib { font-size: 10px; }
            body.pin-mode #map { cursor: crosshair; }
          </style>
        </head>
        <body>
          <div id="map"></div>
          <script>
            const bridge = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.mapBridge;
            let map = null;
            let routeSourceId = 'route-source';
            let routeLayerId = 'route-layer';
            let routeRemainingSourceId = 'route-remaining-source';
            let routeTraveledSourceId = 'route-traveled-source';
            let routeRemainingLayerId = 'route-remaining-layer';
            let routeTraveledLayerId = 'route-traveled-layer';
            let markerFeatures = [];
            let interactionMode = 'navigate';
            let userMapInteraction = false;
            let programmaticMove = false;
            let routeCoordinatesCache = [];
            let routeCumulativeLengths = [];
            let routeTotalLengthMeters = 0;
            let routeRevealFrame = null;
            let vehicleIconLengthMeters = 12;
            let vehicleIconVisible = false;
            let vehicleIconCenter = { lng: 0, lat: 0 };
            const initialStyleURL = '\(styleURL)';

            function post(type, payload) {
              if (!bridge) return;
              bridge.postMessage(Object.assign({ type }, payload || {}));
            }

            const KMH_TO_MPH = 0.621371;

            function isUnitedKingdom(lat, lng) {
              return lat >= 49.5 && lat <= 61.0 && lng >= -8.5 && lng <= 2.0;
            }

            function isUnitedStates(lat, lng) {
              return lat >= 24.0 && lat <= 49.5 && lng >= -125.0 && lng <= -66.0;
            }

            function regionalMeasurementSystem(lng, lat) {
              if (isUnitedKingdom(lat, lng) || isUnitedStates(lat, lng)) {
                return 'imperial';
              }
              return 'metric';
            }

            function formatSpeedLimitKmh(speedKmh, lng, lat) {
              const system = regionalMeasurementSystem(lng, lat);
              if (system === 'imperial') {
                return Math.round(speedKmh * KMH_TO_MPH) + ' mph';
              }
              return Math.round(speedKmh) + ' km/h';
            }

            function ensureRouteLayer() {
              if (!map || !map.isStyleLoaded()) return;
              if (!map.getSource(routeSourceId)) {
                map.addSource(routeSourceId, { type: 'geojson', data: { type: 'Feature', geometry: { type: 'LineString', coordinates: [] } } });
                map.addLayer({
                  id: routeLayerId,
                  type: 'line',
                  source: routeSourceId,
                  layout: { 'line-join': 'round', 'line-cap': 'round' },
                  paint: { 'line-color': '#3b82f6', 'line-width': 5, 'line-opacity': 0 }
                });
              }
              ensureProgressRouteLayers();
            }

            function ensureProgressRouteLayers() {
              if (!map || !map.isStyleLoaded()) return;
              if (!map.getSource(routeRemainingSourceId)) {
                map.addSource(routeRemainingSourceId, { type: 'geojson', data: { type: 'Feature', geometry: { type: 'LineString', coordinates: [] } } });
                map.addLayer({
                  id: routeRemainingLayerId,
                  type: 'line',
                  source: routeRemainingSourceId,
                  layout: { 'line-join': 'round', 'line-cap': 'round' },
                  paint: { 'line-color': '#3b82f6', 'line-width': 5, 'line-opacity': 0.95 }
                });
              }
              if (!map.getSource(routeTraveledSourceId)) {
                map.addSource(routeTraveledSourceId, { type: 'geojson', data: { type: 'Feature', geometry: { type: 'LineString', coordinates: [] } } });
                map.addLayer({
                  id: routeTraveledLayerId,
                  type: 'line',
                  source: routeTraveledSourceId,
                  layout: { 'line-join': 'round', 'line-cap': 'round' },
                  paint: { 'line-color': '#9ca3af', 'line-width': 5, 'line-opacity': 0.55 }
                });
              }
            }

            function metersPerPixelAtLat(lat, zoom) {
              const earthCircumference = 40075016.686;
              const latRad = lat * Math.PI / 180;
              return (earthCircumference * Math.cos(latRad)) / (Math.pow(2, zoom + 8));
            }

            function vehicleIconRadiusPixels(lengthM, lat, zoom) {
              const mpp = metersPerPixelAtLat(lat, zoom);
              const radius = (lengthM || 12) / (2 * mpp);
              return Math.max(6, Math.min(radius, 40));
            }

            function updateVehicleIconRadius() {
              if (!map || !vehicleIconVisible) return;
              const radius = vehicleIconRadiusPixels(vehicleIconLengthMeters, vehicleIconCenter.lat, map.getZoom());
              if (map.getLayer('vehicle-icon-layer')) {
                map.setPaintProperty('vehicle-icon-layer', 'circle-radius', radius);
              }
            }

            function splitRouteAtArcLength(coords, cumulative, arcLengthM) {
              if (!coords || coords.length < 2 || !cumulative || cumulative.length < 2) {
                return { traveled: [], remaining: coords || [] };
              }
              const target = Math.max(0, Math.min(arcLengthM, cumulative[cumulative.length - 1] || 0));
              let segmentIndex = 0;
              for (let i = 1; i < cumulative.length; i++) {
                if (cumulative[i] >= target) {
                  segmentIndex = i - 1;
                  break;
                }
                segmentIndex = i - 1;
              }
              const segStart = cumulative[segmentIndex] || 0;
              const segEnd = cumulative[segmentIndex + 1] || segStart;
              const segLen = Math.max(segEnd - segStart, 1e-9);
              const t = Math.min(1, Math.max(0, (target - segStart) / segLen));
              const from = coords[segmentIndex];
              const to = coords[Math.min(segmentIndex + 1, coords.length - 1)];
              const splitPoint = [
                from[0] + (to[0] - from[0]) * t,
                from[1] + (to[1] - from[1]) * t
              ];
              const traveled = coords.slice(0, segmentIndex + 1);
              if (t > 0.0001) traveled.push(splitPoint);
              const remaining = [splitPoint].concat(coords.slice(segmentIndex + 1));
              return { traveled, remaining };
            }

            function applyRouteProgressLayers(traveled, remaining) {
              if (!map) return;
              ensureProgressRouteLayers();
              if (map.getSource(routeTraveledSourceId)) {
                map.getSource(routeTraveledSourceId).setData({
                  type: 'Feature',
                  geometry: { type: 'LineString', coordinates: traveled || [] }
                });
              }
              if (map.getSource(routeRemainingSourceId)) {
                map.getSource(routeRemainingSourceId).setData({
                  type: 'Feature',
                  geometry: { type: 'LineString', coordinates: remaining || [] }
                });
              }
            }

            function ensureMarkerSource() {
              if (!map.getSource('markers-source')) {
                map.addSource('markers-source', { type: 'geojson', data: { type: 'FeatureCollection', features: [] } });
                map.addLayer({
                  id: 'markers-layer',
                  type: 'circle',
                  source: 'markers-source',
                  paint: {
                    'circle-radius': 9,
                    'circle-color': ['get', 'color'],
                    'circle-stroke-width': 2,
                    'circle-stroke-color': '#ffffff'
                  }
                });
              }
            }

            function offsetMeters(lng, lat, bearingDeg, forwardM, rightM) {
              const earthRadius = 6378137;
              const bearingRad = bearingDeg * Math.PI / 180;
              const east = forwardM * Math.sin(bearingRad) + rightM * Math.cos(bearingRad);
              const north = forwardM * Math.cos(bearingRad) - rightM * Math.sin(bearingRad);
              const latRad = lat * Math.PI / 180;
              const deltaLat = north / earthRadius * 180 / Math.PI;
              const deltaLng = east / (earthRadius * Math.cos(latRad)) * 180 / Math.PI;
              return [lng + deltaLng, lat + deltaLat];
            }

            function vehicleFootprintPolygon(lng, lat, bearingDeg, lengthM, widthM) {
              const length = lengthM || 12;
              const halfW = (widthM || 2.55) / 2;
              const corners = [
                [length, -halfW],
                [length, halfW],
                [0, halfW],
                [0, -halfW]
              ].map(([forwardM, rightM]) => offsetMeters(lng, lat, bearingDeg, forwardM, rightM));
              corners.push(corners[0]);
              return corners;
            }

            function ensureVehicleLayer() {
              if (!map.getSource('vehicle-source')) {
                map.addSource('vehicle-source', {
                  type: 'geojson',
                  data: { type: 'Feature', geometry: { type: 'Polygon', coordinates: [[]] }, properties: { visible: false } }
                });
                map.addLayer({
                  id: 'vehicle-fill-layer',
                  type: 'fill',
                  source: 'vehicle-source',
                  paint: {
                    'fill-color': '#2563eb',
                    'fill-opacity': 0.55
                  },
                  layout: { visibility: 'none' }
                });
                map.addLayer({
                  id: 'vehicle-outline-layer',
                  type: 'line',
                  source: 'vehicle-source',
                  paint: {
                    'line-color': '#ffffff',
                    'line-width': 2,
                    'line-opacity': 0.95
                  },
                  layout: { visibility: 'none' }
                });
              }
            }

            function ensureVehicleIconLayer() {
              if (!map.getSource('vehicle-icon-source')) {
                map.addSource('vehicle-icon-source', {
                  type: 'geojson',
                  data: { type: 'Feature', geometry: { type: 'Point', coordinates: [0, 0] }, properties: { visible: false } }
                });
                map.addLayer({
                  id: 'vehicle-icon-layer',
                  type: 'circle',
                  source: 'vehicle-icon-source',
                  paint: {
                    'circle-radius': 10,
                    'circle-color': '#2563eb',
                    'circle-stroke-width': 3,
                    'circle-stroke-color': '#ffffff',
                    'circle-opacity': 0.95
                  },
                  layout: { visibility: 'none' }
                });
              }
            }

            function postMoveEnd() {
              if (!map) return;
              const c = map.getCenter();
              post('moveend', {
                lng: c.lng,
                lat: c.lat,
                zoom: map.getZoom(),
                userInitiated: userMapInteraction && !programmaticMove
              });
              userMapInteraction = false;
              programmaticMove = false;
            }

            function fitRouteBounds(padding) {
              if (!map || !map.isStyleLoaded() || routeCoordinatesCache.length < 2) return;
              const lngs = routeCoordinatesCache.map(c => c[0]);
              const lats = routeCoordinatesCache.map(c => c[1]);
              programmaticMove = true;
              map.fitBounds(
                [[Math.min(...lngs), Math.min(...lats)], [Math.max(...lngs), Math.max(...lats)]],
                {
                  padding: padding || { top: 60, bottom: 60, left: 40, right: 40 },
                  duration: 800
                }
              );
            }
            window.fitRouteBounds = fitRouteBounds;

            window.initMap = function(center, zoom, style, controlPosition) {
              map = new maplibregl.Map({
                container: 'map',
                style: style,
                center: center,
                zoom: zoom,
                attributionControl: true
              });
              map.addControl(
                new maplibregl.NavigationControl({ showCompass: true }),
                controlPosition || 'top-right'
              );
              map.on('load', () => {
                ensureRouteLayer();
                ensureMarkerSource();
                ensureVehicleLayer();
                ensureVehicleIconLayer();
                post('ready', {});
              });
              map.on('dragstart', () => { userMapInteraction = true; });
              map.on('zoomstart', () => { userMapInteraction = true; });
              map.on('moveend', postMoveEnd);
              map.on('zoomend', () => {
                updateVehicleIconRadius();
                postMoveEnd();
              });
              map.on('click', (e) => {
                post('click', { lng: e.lngLat.lng, lat: e.lngLat.lat, button: 0 });
              });
              map.on('contextmenu', (e) => {
                e.preventDefault();
                post('contextmenu', { lng: e.lngLat.lng, lat: e.lngLat.lat });
              });
            };

            window.setInteractionMode = function(mode) {
              interactionMode = mode;
              document.body.classList.toggle('pin-mode', mode === 'pin');
            };

            window.setRoute = function(coords, cumulativeLengths, padding) {
              if (!map || !map.isStyleLoaded() || !map.getSource(routeSourceId)) return;
              routeCoordinatesCache = coords || [];
              if (cumulativeLengths && cumulativeLengths.length > 0) {
                routeCumulativeLengths = cumulativeLengths;
                routeTotalLengthMeters = cumulativeLengths[cumulativeLengths.length - 1] || 0;
              }
              map.getSource(routeSourceId).setData({
                type: 'Feature',
                geometry: { type: 'LineString', coordinates: routeCoordinatesCache }
              });
              const split = splitRouteAtArcLength(routeCoordinatesCache, routeCumulativeLengths, 0);
              applyRouteProgressLayers(split.traveled, split.remaining);
              // Camera fit is driven by native code with chrome-aware padding.
              if (padding) {
                fitRouteBounds(padding);
              }
            };

            window.animateRouteReveal = function(coords, cumulativeLengths, durationMs) {
              if (!map) return;
              if (routeRevealFrame) cancelAnimationFrame(routeRevealFrame);
              routeCoordinatesCache = coords || [];
              routeCumulativeLengths = cumulativeLengths || [];
              routeTotalLengthMeters = routeCumulativeLengths.length > 0
                ? routeCumulativeLengths[routeCumulativeLengths.length - 1]
                : 0;
              const total = routeTotalLengthMeters || 1;
              const duration = durationMs || 1200;
              const start = performance.now();
              function frame(now) {
                const elapsed = now - start;
                const fraction = Math.min(1, elapsed / duration);
                const arcLength = total * fraction;
                const split = splitRouteAtArcLength(routeCoordinatesCache, routeCumulativeLengths, arcLength);
                applyRouteProgressLayers(split.traveled, split.remaining);
                if (fraction < 1) {
                  routeRevealFrame = requestAnimationFrame(frame);
                } else {
                  routeRevealFrame = null;
                  window.setRouteProgress(0);
                }
              }
              routeRevealFrame = requestAnimationFrame(frame);
            };

            window.setRouteProgress = function(fraction) {
              if (!map || routeCoordinatesCache.length < 2) return;
              const clamped = Math.max(0, Math.min(1, fraction || 0));
              const arcLength = (routeTotalLengthMeters || 0) * clamped;
              const split = splitRouteAtArcLength(routeCoordinatesCache, routeCumulativeLengths, arcLength);
              applyRouteProgressLayers(split.traveled, split.remaining);
            };

            window.applyRouteSplitLayers = function(traveledCoords, remainingCoords) {
              if (!map) return;
              ensureProgressRouteLayers();
              if (map.getSource(routeTraveledSourceId)) {
                map.getSource(routeTraveledSourceId).setData({
                  type: 'Feature',
                  geometry: { type: 'LineString', coordinates: traveledCoords || [] }
                });
              }
              if (map.getSource(routeRemainingSourceId)) {
                map.getSource(routeRemainingSourceId).setData({
                  type: 'Feature',
                  geometry: { type: 'LineString', coordinates: remainingCoords || [] }
                });
              }
            };

            window.loadRouteGeometry = function(coords, cumulativeLengths, totalLengthMeters) {
              if (!map || !map.isStyleLoaded()) return;
              routeCoordinatesCache = coords || [];
              routeCumulativeLengths = cumulativeLengths || [];
              routeTotalLengthMeters = totalLengthMeters || (
                routeCumulativeLengths.length > 0
                  ? routeCumulativeLengths[routeCumulativeLengths.length - 1]
                  : 0
              );
              ensureRouteLayer();
              map.getSource(routeSourceId).setData({
                type: 'Feature',
                geometry: { type: 'LineString', coordinates: routeCoordinatesCache }
              });
              const split = splitRouteAtArcLength(routeCoordinatesCache, routeCumulativeLengths, 0);
              applyRouteProgressLayers(split.traveled, split.remaining);
              // Camera fit is driven by native code with chrome-aware padding.
            };

            window.zoomBy = function(delta) {
              if (!map || !map.isStyleLoaded()) return;
              userMapInteraction = true;
              map.zoomTo(map.getZoom() + (delta || 0), { duration: 200 });
            };

            window.setZoom = function(zoom) {
              if (!map || !map.isStyleLoaded()) return;
              if (typeof zoom !== 'number' || !isFinite(zoom)) return;
              userMapInteraction = true;
              map.zoomTo(zoom, { duration: 200 });
            };

            function decodePolyline(encoded, precision) {
              const factor = Math.pow(10, precision || 5);
              let index = 0, lat = 0, lng = 0, coordinates = [];
              while (index < encoded.length) {
                let result = 0, shift = 0, b;
                do {
                  b = encoded.charCodeAt(index++) - 63;
                  result |= (b & 0x1f) << shift;
                  shift += 5;
                } while (b >= 0x20);
                const dlat = (result & 1) ? ~(result >> 1) : (result >> 1);
                lat += dlat;
                result = 0; shift = 0;
                do {
                  b = encoded.charCodeAt(index++) - 63;
                  result |= (b & 0x1f) << shift;
                  shift += 5;
                } while (b >= 0x20);
                const dlng = (result & 1) ? ~(result >> 1) : (result >> 1);
                lng += dlng;
                coordinates.push([lng / factor, lat / factor]);
              }
              return coordinates;
            }

            window.setRouteEncoded = function(encoded, precision) {
              if (!encoded) {
                setRoute([]);
                return;
              }
              setRoute(decodePolyline(encoded, precision || 6));
            };

            window.setMarkers = function(markers) {
              if (!map || !map.getSource('markers-source')) return;
              const features = (markers || []).map(m => ({
                type: 'Feature',
                geometry: { type: 'Point', coordinates: [m.lng, m.lat] },
                properties: { color: m.color, title: m.title || '' }
              }));
              map.getSource('markers-source').setData({ type: 'FeatureCollection', features });
            };

            window.updateVehicleSpatialFootprint = function(coordinates, bearing, renderMode, centerLng, centerLat, visible) {
              if (!map) return;
              ensureVehicleLayer();
              ensureVehicleIconLayer();
              const show = visible === true || visible === 'true';
              if (!show) {
                map.setLayoutProperty('vehicle-fill-layer', 'visibility', 'none');
                map.setLayoutProperty('vehicle-outline-layer', 'visibility', 'none');
                map.setLayoutProperty('vehicle-icon-layer', 'visibility', 'none');
                return;
              }
              const mode = (renderMode || 'polygon').toLowerCase();
              const zoom = map.getZoom();
              const usePolygon = mode === 'polygon' && zoom >= 16.0;
              if (usePolygon && coordinates && coordinates.length > 0) {
                const polygon = coordinates.map(function(c) { return [c.lng, c.lat]; });
                map.setLayoutProperty('vehicle-fill-layer', 'visibility', 'visible');
                map.setLayoutProperty('vehicle-outline-layer', 'visibility', 'visible');
                map.setLayoutProperty('vehicle-icon-layer', 'visibility', 'none');
                map.getSource('vehicle-source').setData({
                  type: 'Feature',
                  geometry: { type: 'Polygon', coordinates: [polygon] },
                  properties: { bearing: bearing || 0, visible: true }
                });
              } else {
                map.setLayoutProperty('vehicle-fill-layer', 'visibility', 'none');
                map.setLayoutProperty('vehicle-outline-layer', 'visibility', 'none');
                map.setLayoutProperty('vehicle-icon-layer', 'visibility', 'visible');
                vehicleIconVisible = true;
                vehicleIconLengthMeters = window._vehicleLengthMeters || 12;
                vehicleIconCenter = { lng: centerLng, lat: centerLat };
                const radius = vehicleIconRadiusPixels(vehicleIconLengthMeters, centerLat, zoom);
                map.setPaintProperty('vehicle-icon-layer', 'circle-radius', radius);
                map.getSource('vehicle-icon-source').setData({
                  type: 'Feature',
                  geometry: { type: 'Point', coordinates: [centerLng, centerLat] },
                  properties: { bearing: bearing || 0, visible: true }
                });
              }
            };

            window.setSimulatedVehicleFootprint = function(lng, lat, visible, bearing, footprintJSON, lengthM, widthM, renderMode) {
              if (!map) return;
              window._vehicleLengthMeters = lengthM || 12;
              window._vehicleWidthMeters = widthM || 2.55;
              const show = visible === true || visible === 'true';
              if (!show) {
                vehicleIconVisible = false;
                updateVehicleSpatialFootprint([], 0, 'icon', 0, 0, false);
                return;
              }
              let footprintCoords = [];
              try {
                const parsed = typeof footprintJSON === 'string' ? JSON.parse(footprintJSON) : footprintJSON;
                footprintCoords = (parsed || []).map(function(pair) {
                  return { lng: pair[0], lat: pair[1] };
                });
              } catch (e) {
                const polygon = vehicleFootprintPolygon(lng, lat, bearing || 0, lengthM, widthM);
                footprintCoords = polygon.slice(0, -1).map(function(pair) {
                  return { lng: pair[0], lat: pair[1] };
                });
              }
              updateVehicleSpatialFootprint(footprintCoords, bearing || 0, renderMode, lng, lat, true);
            };

            window.setSimulatedVehicle = function(lng, lat, visible, bearing, lengthM, widthM, renderMode) {
              if (!map) return;
              window._vehicleLengthMeters = lengthM || 12;
              window._vehicleWidthMeters = widthM || 2.55;
              const show = visible === true || visible === 'true';
              if (!show) {
                vehicleIconVisible = false;
                updateVehicleSpatialFootprint([], 0, 'icon', 0, 0, false);
                return;
              }
              const polygon = vehicleFootprintPolygon(lng, lat, bearing || 0, lengthM, widthM);
              const footprintRing = polygon.slice(0, -1).map(function(pair) { return [pair[0], pair[1]]; });
              window.setSimulatedVehicleFootprint(
                lng, lat, true, bearing || 0, JSON.stringify(footprintRing), lengthM, widthM, renderMode
              );
            };

            window.easeToCenter = function(lng, lat, zoom, durationMs) {
              if (!map) return;
              programmaticMove = true;
              const options = { center: [lng, lat], duration: durationMs || 200 };
              if (zoom != null && !Number.isNaN(zoom)) {
                options.zoom = zoom;
              }
              map.easeTo(options);
            };

            window.easeToNavigation = function(lng, lat, zoom, bearing, pitch, durationMs) {
              if (!map) return;
              programmaticMove = true;
              const options = { center: [lng, lat], duration: durationMs || 200 };
              if (zoom != null && !Number.isNaN(zoom)) {
                options.zoom = zoom;
              }
              if (bearing != null && !Number.isNaN(bearing)) {
                options.bearing = bearing;
              }
              if (pitch != null && !Number.isNaN(pitch)) {
                options.pitch = pitch;
              }
              map.easeTo(options);
            };

            window.flyTo = function(center, zoom) {
              if (!map) return;
              programmaticMove = true;
              const options = { center, duration: 900 };
              if (zoom != null && !Number.isNaN(zoom)) {
                options.zoom = zoom;
              }
              map.flyTo(options);
            };

            window.setHazards = function(geojson) {
              if (!map) return;
              const sourceId = 'hazards-source';
              const layerId = 'hazards-layer';
              const data = typeof geojson === 'string' ? JSON.parse(geojson) : geojson;
              if (!map.getSource(sourceId)) {
                map.addSource(sourceId, { type: 'geojson', data: data });
                map.addLayer({
                  id: layerId,
                  type: 'circle',
                  source: sourceId,
                  paint: {
                    'circle-radius': 7,
                    'circle-color': ['get', 'color'],
                    'circle-stroke-width': 2,
                    'circle-stroke-color': '#ffffff',
                    'circle-opacity': 0.9
                  }
                });
              } else {
                map.getSource(sourceId).setData(data);
              }
            };
          </script>
        </body>
        </html>
        """
    }
}
