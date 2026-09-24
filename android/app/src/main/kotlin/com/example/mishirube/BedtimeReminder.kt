package com.example.mishirube

import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

/// A daily reminder before the suggested bedtime (lib/app/bedtime_reminder.dart):
/// an inexact daily alarm, since a reminder a few minutes late is still a
/// reminder, which posts the notification when it goes off.
class BedtimeReminder(private val activity: Activity) {
    private val alarms = activity.getSystemService(AlarmManager::class.java)

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "schedule" -> {
                val hour = call.argument<Int>("hour")
                val minute = call.argument<Int>("minute")
                if (hour == null || minute == null) return result.error("badArguments", null, null)
                if (Build.VERSION.SDK_INT >= 33 &&
                    activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                    PackageManager.PERMISSION_GRANTED
                ) {
                    activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST)
                }
                activity.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit()
                    .putString("title", call.argument<String>("title") ?: "")
                    .putString("body", call.argument<String>("body") ?: "")
                    .apply()
                val next = Calendar.getInstance().apply {
                    set(Calendar.HOUR_OF_DAY, hour)
                    set(Calendar.MINUTE, minute)
                    set(Calendar.SECOND, 0)
                    if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
                }
                alarms.setInexactRepeating(
                    AlarmManager.RTC_WAKEUP,
                    next.timeInMillis,
                    AlarmManager.INTERVAL_DAY,
                    pending(activity),
                )
                result.success(null)
            }
            "cancel" -> {
                alarms.cancel(pending(activity))
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /// Posts the reminder when the alarm goes off.
    class Receiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val saved = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, saved.getString("title", "") ?: "", NotificationManager.IMPORTANCE_DEFAULT),
            )
            val open = PendingIntent.getActivity(
                context,
                0,
                context.packageManager.getLaunchIntentForPackage(context.packageName),
                PendingIntent.FLAG_IMMUTABLE,
            )
            manager.notify(
                NOTIFICATION_ID,
                Notification.Builder(context, CHANNEL_ID)
                    .setSmallIcon(context.applicationInfo.icon)
                    .setContentTitle(saved.getString("title", ""))
                    .setContentText(saved.getString("body", ""))
                    .setContentIntent(open)
                    .setAutoCancel(true)
                    .build(),
            )
        }
    }

    private companion object {
        const val PREFERENCES = "bedtime_reminder"
        const val CHANNEL_ID = "bedtime"
        const val NOTIFICATION_ID = 8
        const val REQUEST = 8

        fun pending(context: Context): PendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, Receiver::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }
}
