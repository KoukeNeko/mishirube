package com.example.mishirube

import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.app.Application
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// The rest between sets as an ongoing notification counting down to its
/// end (lib/app/rest_notice.dart), seen from the lock screen and the
/// shade, and a notification that sounds when the rest, or a timed set,
/// ends. The end is an alarm that posts it, so it comes with the app in the
/// background; not one in the foreground, where the app says it itself.
///
/// The alarm is inexact (`setAndAllowWhileIdle`, which needs no extra
/// permission): in Doze it may come late, by minutes.
class RestNoticeBridge(private val activity: Activity) {
    private val manager = activity.getSystemService(NotificationManager::class.java)
    private val alarms = activity.getSystemService(AlarmManager::class.java)

    init {
        activity.application.registerActivityLifecycleCallbacks(
            object : Application.ActivityLifecycleCallbacks {
                override fun onActivityResumed(resumed: Activity) {
                    if (resumed === activity) isForeground = true
                }

                override fun onActivityPaused(paused: Activity) {
                    if (paused === activity) isForeground = false
                }

                override fun onActivityDestroyed(destroyed: Activity) {
                    if (destroyed === activity) destroyed.application.unregisterActivityLifecycleCallbacks(this)
                }

                override fun onActivityCreated(created: Activity, state: Bundle?) {}
                override fun onActivityStarted(started: Activity) {}
                override fun onActivityStopped(stopped: Activity) {}
                override fun onActivitySaveInstanceState(saved: Activity, state: Bundle) {}
            },
        )
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "schedule" -> {
                val endsAt = (call.argument<Double>("endsAt") ?: return result.error("badArguments", null, null)).toLong()
                val endedTitle = call.argument<String>("endedTitle") ?: ""
                val body = call.argument<String>("body") ?: ""
                if (canNotify()) {
                    show(endsAt, call.argument<String>("restingTitle") ?: "", body)
                    scheduleEnd(REST, endsAt, endedTitle, body, endedTitle)
                }
                result.success(null)
            }
            // The rest ran out in the app: its notification goes with it,
            // the alarm having come or being about to.
            "ended" -> {
                manager.cancel(NOTIFICATION_ID)
                result.success(null)
            }
            "cancel" -> {
                manager.cancel(NOTIFICATION_ID)
                manager.cancel(REST_END_ID)
                alarms.cancel(pending(activity, REST))
                result.success(null)
            }
            "scheduleSet" -> {
                val endsAt = (call.argument<Double>("endsAt") ?: return result.error("badArguments", null, null)).toLong()
                if (canNotify()) {
                    scheduleEnd(
                        SET,
                        endsAt,
                        call.argument<String>("title") ?: "",
                        call.argument<String>("body") ?: "",
                        call.argument<String>("endedTitle") ?: "",
                    )
                }
                result.success(null)
            }
            "cancelSet" -> {
                manager.cancel(SET_END_ID)
                alarms.cancel(pending(activity, SET))
                result.success(null)
            }
            "cue" -> {
                cue()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun canNotify(): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            // Asked once; declining leaves the rest shown in the app only.
            activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), PERMISSION_REQUEST)
            return false
        }
        return true
    }

    private fun show(endsAt: Long, title: String, body: String) {
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

    private fun scheduleEnd(kind: Int, endsAt: Long, title: String, body: String, channel: String) {
        activity.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit()
            .putString("title$kind", title)
            .putString("body$kind", body)
            .putString("channel", channel.ifEmpty { title })
            .apply()
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, endsAt, pending(activity, kind))
    }

    /// A short beep on the notification volume: no audio focus taken, so
    /// music goes on playing.
    private fun cue() {
        val tone = ToneGenerator(AudioManager.STREAM_NOTIFICATION, TONE_VOLUME)
        tone.startTone(ToneGenerator.TONE_PROP_BEEP, TONE_MILLIS)
        Handler(Looper.getMainLooper()).postDelayed({ tone.release() }, TONE_MILLIS * 2L)
    }

    /// Posts the end of the rest or the set when its alarm goes off, and
    /// takes the countdown of a rest away.
    class Receiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (isForeground) return
            val kind = intent.getIntExtra(KIND, REST)
            val saved = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(
                NotificationChannel(END_CHANNEL_ID, saved.getString("channel", "") ?: "", NotificationManager.IMPORTANCE_DEFAULT),
            )
            val open = PendingIntent.getActivity(
                context,
                0,
                context.packageManager.getLaunchIntentForPackage(context.packageName),
                PendingIntent.FLAG_IMMUTABLE,
            )
            if (kind == REST) manager.cancel(NOTIFICATION_ID)
            manager.notify(
                if (kind == REST) REST_END_ID else SET_END_ID,
                Notification.Builder(context, END_CHANNEL_ID)
                    .setSmallIcon(context.applicationInfo.icon)
                    .setContentTitle(saved.getString("title$kind", ""))
                    .setContentText(saved.getString("body$kind", ""))
                    .setContentIntent(open)
                    .setAutoCancel(true)
                    .build(),
            )
        }
    }

    companion object {
        const val CHANNEL_ID = "rest"
        const val END_CHANNEL_ID = "rest_end"
        const val NOTIFICATION_ID = 7
        const val REST_END_ID = 9
        const val SET_END_ID = 10
        const val PERMISSION_REQUEST = 7
        const val PREFERENCES = "rest_notice"
        const val KIND = "kind"
        const val REST = 0
        const val SET = 1
        const val TONE_VOLUME = 80
        const val TONE_MILLIS = 150

        /// Whether the app's window is in front, where the alarm stays quiet.
        @Volatile
        var isForeground = false

        fun pending(context: Context, kind: Int): PendingIntent = PendingIntent.getBroadcast(
            context,
            kind,
            Intent(context, Receiver::class.java).putExtra(KIND, kind),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }
}
