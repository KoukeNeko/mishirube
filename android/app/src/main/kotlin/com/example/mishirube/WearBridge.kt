package com.example.mishirube

import android.app.Activity
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// The running workout on a paired Wear OS watch (lib/app/watch_sync.dart,
/// the app in android/wear): the phone publishes what to show, and the
/// watch asks the phone to log the next set.
class WearBridge(activity: Activity, private val channel: MethodChannel) {
    private val data = Wearable.getDataClient(activity)
    private val messages = Wearable.getMessageClient(activity)
    private val listener = MessageClient.OnMessageReceivedListener { event ->
        if (event.path == LOG_PATH) channel.invokeMethod("logNextSet", null)
    }

    init {
        messages.addListener(listener)
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "update") return result.notImplemented()
        val state = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
        val request = PutDataMapRequest.create(STATE_PATH).apply {
            dataMap.putString("workout", state["workout"] as? String ?: "")
            dataMap.putString("exercise", state["exercise"] as? String ?: "")
            dataMap.putString("set", state["set"] as? String ?: "")
            dataMap.putString("progress", state["progress"] as? String ?: "")
            dataMap.putLong("restEndsAt", (state["restEndsAt"] as? Double)?.toLong() ?: 0L)
            dataMap.putBoolean("hasNext", state["hasNext"] as? Boolean ?: false)
        }.asPutDataRequest().setUrgent()
        // Without a watch the write simply stays local.
        data.putDataItem(request)
        result.success(null)
    }

    fun close() = messages.removeListener(listener)

    companion object {
        const val STATE_PATH = "/workout"
        const val LOG_PATH = "/log-next-set"
    }
}
