package com.example.mishirube

import android.content.Context
import android.graphics.Color
import android.location.Location
import android.view.View
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapLibreMapOptions
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.Style
import org.maplibre.android.style.expressions.Expression
import org.maplibre.android.style.layers.CircleLayer
import org.maplibre.android.style.layers.LineLayer
import org.maplibre.android.style.layers.Property
import org.maplibre.android.style.layers.PropertyFactory
import org.maplibre.android.style.sources.GeoJsonOptions
import org.maplibre.android.style.sources.GeoJsonSource
import org.maplibre.geojson.Feature
import org.maplibre.geojson.FeatureCollection
import org.maplibre.geojson.LineString
import org.maplibre.geojson.Point

/**
 * A workout's route for lib/features/activity/route_map.dart, drawn
 * with MapLibre on OpenFreeMap's dark style: free, with no key and no
 * account. The line is coloured by speed along its actual length, and
 * without a network the route is drawn on a plain dark background.
 */
class RouteMapFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        RouteMapView(context, args as? Map<*, *> ?: emptyMap<Any, Any>())
}

private const val STYLE_URL = "https://tiles.openfreemap.org/styles/dark"

/** What the map shows without a network: the route on the page's black. */
private const val OFFLINE_STYLE =
    """{"version":8,"sources":{},"layers":[{"id":"background","type":"background","paint":{"background-color":"#0F1110"}}]}"""

class RouteMapView(context: Context, args: Map<*, *>) : PlatformView {
    private val points: List<List<Double>> = (args["points"] as? List<*>).orEmpty()
        .mapNotNull { point -> (point as? List<*>)?.mapNotNull { (it as? Number)?.toDouble() } }
        .filter { it.size >= 3 }
    private val interactive = args["interactive"] as? Boolean ?: false
    // A texture, not a surface, so it composes inside Flutter's page.
    private val map = MapView(context, MapLibreMapOptions.createFromAttributes(context).textureMode(true))
    private var isOffline = false

    init {
        map.onCreate(null)
        map.onStart()
        map.onResume()
        map.getMapAsync { mapLibre ->
            mapLibre.uiSettings.setAllGesturesEnabled(interactive)
            mapLibre.uiSettings.isLogoEnabled = false
            mapLibre.uiSettings.isCompassEnabled = interactive
            map.addOnDidFailLoadingMapListener {
                if (!isOffline) {
                    isOffline = true
                    mapLibre.setStyle(Style.Builder().fromJson(OFFLINE_STYLE)) { draw(mapLibre, it) }
                }
            }
            mapLibre.setStyle(Style.Builder().fromUri(STYLE_URL)) { draw(mapLibre, it) }
        }
    }

    private fun draw(mapLibre: MapLibreMap, style: Style) {
        if (points.size < 2) return
        val line = LineString.fromLngLats(points.map { Point.fromLngLat(it[1], it[0]) })
        style.addSource(
            GeoJsonSource("route", Feature.fromGeometry(line), GeoJsonOptions().withLineMetrics(true))
        )
        style.addLayer(
            LineLayer("route", "route").withProperties(
                PropertyFactory.lineWidth(5f),
                PropertyFactory.lineCap(Property.LINE_CAP_ROUND),
                PropertyFactory.lineJoin(Property.LINE_JOIN_ROUND),
                PropertyFactory.lineGradient(gradient()),
            )
        )
        val ends = FeatureCollection.fromFeatures(
            listOf(points.first(), points.last()).mapIndexed { index, point ->
                Feature.fromGeometry(Point.fromLngLat(point[1], point[0])).apply {
                    addBooleanProperty("start", index == 0)
                }
            }
        )
        style.addSource(GeoJsonSource("ends", ends))
        style.addLayer(
            CircleLayer("ends", "ends").withProperties(
                PropertyFactory.circleRadius(7f),
                PropertyFactory.circleStrokeWidth(2f),
                PropertyFactory.circleStrokeColor(Color.WHITE),
                PropertyFactory.circleColor(
                    Expression.switchCase(
                        Expression.get("start"), Expression.color(Color.rgb(52, 199, 89)),
                        Expression.color(Color.rgb(255, 69, 58)),
                    )
                ),
            )
        )
        val bounds = LatLngBounds.Builder()
            .includes(points.map { LatLng(it[0], it[1]) })
            .build()
        mapLibre.moveCamera(CameraUpdateFactory.newLatLngBounds(bounds, 96))
    }

    /** Red when slow through yellow to green when fast, placed by distance. */
    private fun gradient(): Expression {
        val speeds = points.map { it[2] }
        val slowest = speeds.minOrNull() ?: 0.0
        val range = maxOf((speeds.maxOrNull() ?: 0.0) - slowest, 0.1)
        val along = DoubleArray(points.size)
        for (i in 1 until points.size) {
            val metres = FloatArray(1)
            Location.distanceBetween(
                points[i - 1][0], points[i - 1][1], points[i][0], points[i][1], metres)
            along[i] = along[i - 1] + metres[0]
        }
        val total = along.last().takeIf { it > 0 } ?: 1.0
        var last = -1.0
        val stops = points.indices.mapNotNull { i ->
            val progress = along[i] / total
            // Stops must rise strictly.
            if (progress <= last) return@mapNotNull null
            last = progress
            val hue = ((speeds[i] - slowest) / range * 120).toFloat()
            Expression.stop(progress, Expression.color(Color.HSVToColor(floatArrayOf(hue, 0.85f, 0.95f))))
        }
        return Expression.interpolate(
            Expression.linear(), Expression.lineProgress(), *stops.toTypedArray())
    }

    override fun getView(): View = map

    override fun dispose() {
        map.onPause()
        map.onStop()
        map.onDestroy()
    }
}
