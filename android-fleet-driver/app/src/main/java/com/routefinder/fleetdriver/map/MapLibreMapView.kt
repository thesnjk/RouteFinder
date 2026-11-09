package com.routefinder.fleetdriver.map

import android.graphics.Color
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.routefinder.fleetdriver.routing.LatLon
import org.maplibre.android.MapLibre
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.Style
import org.maplibre.android.style.expressions.Expression
import org.maplibre.android.style.layers.CircleLayer
import org.maplibre.android.style.layers.LineLayer
import org.maplibre.android.style.layers.PropertyFactory
import org.maplibre.android.style.sources.GeoJsonSource
import org.maplibre.geojson.Feature
import org.maplibre.geojson.FeatureCollection
import org.maplibre.geojson.LineString
import org.maplibre.geojson.Point

private const val ROUTE_SOURCE = "rf-route-source"
private const val ROUTE_LAYER = "rf-route-layer"
private const val PARKING_SOURCE = "rf-parking-source"
private const val PARKING_LAYER = "rf-parking-layer"
private const val HAZARD_SOURCE = "rf-hazard-source"
private const val HAZARD_LAYER = "rf-hazard-layer"
private const val DEMO_STYLE = "https://demotiles.maplibre.org/style.json"

/**
 * Compose MapLibre map with optional route polyline, parking markers, and crowd hazard pins.
 */
@Composable
fun MapLibreMapView(
    routeCoordinates: List<LatLon>,
    followLat: Double? = null,
    followLon: Double? = null,
    parkingMarkers: List<ParkingMapMarker> = emptyList(),
    hazardOverlayGeoJson: String = HazardOverlayBuilder.EMPTY_FEATURE_COLLECTION,
    modifier: Modifier = Modifier.fillMaxSize(),
) {
    val context = LocalContext.current
    remember(context) {
        MapLibre.getInstance(context)
    }
    val mapView = remember {
        MapView(context).also { it.onCreate(null) }
    }
    val lifecycleOwner = LocalLifecycleOwner.current
    val mapState = remember { mutableStateOf<MapLibreMap?>(null) }

    DisposableEffect(lifecycleOwner, mapView) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_START -> mapView.onStart()
                Lifecycle.Event.ON_RESUME -> mapView.onResume()
                Lifecycle.Event.ON_PAUSE -> mapView.onPause()
                Lifecycle.Event.ON_STOP -> mapView.onStop()
                Lifecycle.Event.ON_DESTROY -> mapView.onDestroy()
                else -> Unit
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            mapView.onDestroy()
        }
    }

    AndroidView(
        factory = {
            mapView.getMapAsync { map ->
                mapState.value = map
                map.setStyle(Style.Builder().fromUri(DEMO_STYLE)) { style ->
                    ensureRouteLayers(style)
                    ensureParkingLayers(style)
                    ensureHazardLayers(style)
                    RouteLineController.setRoute(style, routeCoordinates)
                    ParkingMarkerController.setMarkers(style, parkingMarkers)
                    HazardMarkerController.setGeoJson(style, hazardOverlayGeoJson)
                    if (routeCoordinates.size >= 2) {
                        fitRoute(map, routeCoordinates)
                    }
                }
            }
            mapView
        },
        modifier = modifier,
        update = {
            mapState.value?.getStyle { style ->
                RouteLineController.setRoute(style, routeCoordinates)
                ParkingMarkerController.setMarkers(style, parkingMarkers)
                HazardMarkerController.setGeoJson(style, hazardOverlayGeoJson)
            }
        },
    )

    LaunchedEffect(routeCoordinates, mapState.value) {
        val map = mapState.value ?: return@LaunchedEffect
        map.getStyle { style ->
            RouteLineController.setRoute(style, routeCoordinates)
            if (routeCoordinates.size >= 2) {
                fitRoute(map, routeCoordinates)
            }
        }
    }

    LaunchedEffect(parkingMarkers, mapState.value) {
        val map = mapState.value ?: return@LaunchedEffect
        map.getStyle { style ->
            ParkingMarkerController.setMarkers(style, parkingMarkers)
        }
    }

    LaunchedEffect(hazardOverlayGeoJson, mapState.value) {
        val map = mapState.value ?: return@LaunchedEffect
        map.getStyle { style ->
            HazardMarkerController.setGeoJson(style, hazardOverlayGeoJson)
        }
    }

    LaunchedEffect(followLat, followLon, mapState.value) {
        val lat = followLat ?: return@LaunchedEffect
        val lon = followLon ?: return@LaunchedEffect
        mapState.value?.animateCamera(CameraUpdateFactory.newLatLngZoom(LatLng(lat, lon), 15.0))
    }
}

object RouteLineController {
    fun setRoute(style: Style, coordinates: List<LatLon>) {
        ensureRouteLayers(style)
        val source = style.getSourceAs<GeoJsonSource>(ROUTE_SOURCE) ?: return
        if (coordinates.size < 2) {
            source.setGeoJson(FeatureCollection.fromFeatures(emptyArray()))
            return
        }
        val line = LineString.fromLngLats(
            coordinates.map { Point.fromLngLat(it.longitude, it.latitude) },
        )
        source.setGeoJson(Feature.fromGeometry(line))
    }
}

object ParkingMarkerController {
    fun setMarkers(style: Style, markers: List<ParkingMapMarker>) {
        ensureParkingLayers(style)
        val source = style.getSourceAs<GeoJsonSource>(PARKING_SOURCE) ?: return
        source.setGeoJson(ParkingMapMarkerBuilder.toFeatureCollection(markers))
    }
}

object HazardMarkerController {
    fun setGeoJson(style: Style, geoJson: String) {
        ensureHazardLayers(style)
        val source = style.getSourceAs<GeoJsonSource>(HAZARD_SOURCE) ?: return
        val payload = geoJson.ifBlank { HazardOverlayBuilder.EMPTY_FEATURE_COLLECTION }
        source.setGeoJson(payload)
    }
}

private fun ensureRouteLayers(style: Style) {
    if (style.getSource(ROUTE_SOURCE) == null) {
        style.addSource(GeoJsonSource(ROUTE_SOURCE))
    }
    if (style.getLayer(ROUTE_LAYER) == null) {
        style.addLayer(
            LineLayer(ROUTE_LAYER, ROUTE_SOURCE).withProperties(
                PropertyFactory.lineColor(Color.parseColor("#1565C0")),
                PropertyFactory.lineWidth(5f),
                PropertyFactory.lineOpacity(0.9f),
            ),
        )
    }
}

private fun ensureParkingLayers(style: Style) {
    if (style.getSource(PARKING_SOURCE) == null) {
        style.addSource(GeoJsonSource(PARKING_SOURCE))
    }
    if (style.getLayer(PARKING_LAYER) == null) {
        style.addLayer(
            CircleLayer(PARKING_LAYER, PARKING_SOURCE).withProperties(
                PropertyFactory.circleRadius(8f),
                PropertyFactory.circleStrokeWidth(1.5f),
                PropertyFactory.circleStrokeColor(Color.WHITE),
                PropertyFactory.circleOpacity(0.92f),
                PropertyFactory.circleColor(
                    Expression.match(
                        Expression.get("tier"),
                        Expression.literal("AMPLE"),
                        Expression.color(Color.parseColor(ParkingMapMarkerBuilder.COLOR_AMPLE)),
                        Expression.literal("LIMITED"),
                        Expression.color(Color.parseColor(ParkingMapMarkerBuilder.COLOR_LIMITED)),
                        Expression.literal("FULL"),
                        Expression.color(Color.parseColor(ParkingMapMarkerBuilder.COLOR_FULL)),
                        Expression.color(Color.parseColor(ParkingMapMarkerBuilder.COLOR_LIMITED)),
                    ),
                ),
            ),
        )
    }
}

private fun ensureHazardLayers(style: Style) {
    if (style.getSource(HAZARD_SOURCE) == null) {
        style.addSource(GeoJsonSource(HAZARD_SOURCE))
    }
    if (style.getLayer(HAZARD_LAYER) == null) {
        style.addLayer(
            CircleLayer(HAZARD_LAYER, HAZARD_SOURCE).withProperties(
                PropertyFactory.circleRadius(9f),
                PropertyFactory.circleStrokeWidth(2f),
                PropertyFactory.circleStrokeColor(Color.WHITE),
                PropertyFactory.circleOpacity(0.95f),
                PropertyFactory.circleColor(Color.parseColor(HazardOverlayBuilder.PIN_COLOR)),
            ),
        )
    }
}

private fun fitRoute(map: MapLibreMap, coordinates: List<LatLon>) {
    val builder = LatLngBounds.Builder()
    coordinates.forEach { builder.include(LatLng(it.latitude, it.longitude)) }
    try {
        map.animateCamera(CameraUpdateFactory.newLatLngBounds(builder.build(), 80))
    } catch (_: Exception) {
        val mid = coordinates[coordinates.size / 2]
        map.animateCamera(CameraUpdateFactory.newLatLngZoom(LatLng(mid.latitude, mid.longitude), 11.0))
    }
}
