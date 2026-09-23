package com.example.mishirube

import android.Manifest
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// The rest between sets as an ongoing notification counting down to its
/// end (lib/app/rest_notice.dart), seen from the lock screen and the
/// shade. It goes away by itself when the rest is over.
class RestNoticeBridge(private val activity: Activity) {
    private val manager = activity.getSystemService(NotificationManager::class.java)

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "schedule" -> {
                val endsAt = (call.argument<Double>("endsAt") ?: return result.error("badArguments", null, null)).toLong()
                show(
                    endsAt,
                    call.argument<String>("restingTitle") ?: "",
                    call.argument<String>("body") ?: "",
                )
                result.success(null)
            }
            "cancel" -> {
                manager.cancel(NOTIFICATION_ID)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun show(endsAt: Long, title: String, body: String) {
        if (Build.VERSION.SDK_INT >= 33 &&
            activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            // Asked once; declining leaves the rest shown in the app only.
            activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), PERMISSION_REQUEST)
            return
        }
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, title, NotificationManager.IMPORTANCE_LOW),
        )
        val open = PendingIntent.getActivity(
            activity,
            0,
            Intent(activity, activity.javaClass).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val remaining = endsAt - System.currentTimeMillis()
        if (remaining <= 0) return
        val notification = Notification.Builder(activity, CHANNEL_ID)
            .setSmallIcon(activity.applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setWhen(endsAt)
            .setShowWhen(true)
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .setTimeoutAfter(remaining)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(open)
            .build()
        manager.notify(NOTIFICATION_ID, notification)
    }

    private companion object {
        const val CHANNEL_ID = "rest"
        const val NOTIFICATION_ID = 7
        const val PERMISSION_REQUEST = 7
    }
}
