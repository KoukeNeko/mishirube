package com.example.mishirube

import android.content.Intent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// A FragmentActivity, because asking for Health Connect permissions
// goes through an activity result.
class MainActivity : FlutterFragmentActivity() {
    private var health: HealthConnectBridge? = null
    private var wear: WearBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        org.maplibre.android.MapLibre.getInstance(this)
        flutterEngine.platformViewsController.registry
            .registerViewFactory("mishirube/route_map", RouteMapFactory())
        val snapshots = RouteSnapshotBridge(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mishirube/route_map")
            .setMethodCallHandler(snapshots::handle)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mishirube/healthconnect")
        val bridge = HealthConnectBridge(this, channel, privacyRequested = asksForPrivacy(intent))
        channel.setMethodCallHandler(bridge::handle)
        health = bridge
        val labels = LabelReaderBridge(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mishirube/ocr")
            .setMethodCallHandler(labels::handle)
        val watchChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mishirube/watch")
        val watch = WearBridge(this, watchChannel)
        watchChannel.setMethodCallHandler(watch::handle)
        wear = watch
        val bedtime = BedtimeReminder(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mishirube/bedtime")
            .setMethodCallHandler(bedtime::handle)
        val rest = RestNoticeBridge(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mishirube/rest_notice")
            .setMethodCallHandler(rest::handle)
        // Keeps the screen on while a workout page is open
        // (lib/shared/screen_awake.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mishirube/screen_awake")
            .setMethodCallHandler { call, result ->
                val isOn = call.arguments as? Boolean
                if (call.method != "keepOn" || isOn == null) {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (isOn) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
                result.success(null)
            }
    }

    override fun onDestroy() {
        wear?.close()
        super.onDestroy()
    }

    // Health Connect's permission screens open the app again to have it
    // explain its use of health data.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (asksForPrivacy(intent)) health?.showPrivacy()
    }

    private fun asksForPrivacy(intent: Intent?) = intent?.action in setOf(
        "androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE",
        "android.intent.action.VIEW_PERMISSION_USAGE",
    )
}
