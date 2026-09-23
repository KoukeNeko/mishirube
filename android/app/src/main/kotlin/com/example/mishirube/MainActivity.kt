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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mishirube/healthconnect")
        val bridge = HealthConnectBridge(this, channel, privacyRequested = asksForPrivacy(intent))
        channel.setMethodCallHandler(bridge::handle)
        health = bridge
        val labels = LabelReaderBridge(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mishirube/ocr")
            .setMethodCallHandler(labels::handle)
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
