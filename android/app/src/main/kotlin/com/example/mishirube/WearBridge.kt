package com.example.mishirube

import android.app.Activity
import com.google.android.gms.wearable.DataMap
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/// The workout on a paired Wear OS watch (lib/app/watch_sync.dart, the app
/// in android/wear): the phone publishes what to show, and the watch asks
/// it to do what the workout page does.
class WearBridge(activity: Activity, private val channel: MethodChannel) {
    private val data = Wearable.getDataClient(activity)
    private val messages = Wearable.getMessageClient(activity)
    private val listener = MessageClient.OnMessageReceivedListener { event ->
        if (event.path != ACTION_PATH) return@OnMessageReceivedListener
        val request = JSONObject(String(event.data))
        val action = request.optString("action")
        if (action !in ACTIONS) return@OnMessageReceivedListener
        val arguments = HashMap<String, Any>()
        for (key in request.keys()) if (key != "action") arguments[key] = request.get(key)
        channel.invokeMethod(action, arguments)
    }

    init {
        messages.addListener(listener)
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "update") return result.notImplemented()
        val state = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
        val request = PutDataMapRequest.create(STATE_PATH).apply {
            val map = dataMap
            map.putString("phase", state["phase"] as? String ?: "none")
            for (key in STRINGS) (state[key] as? String)?.let { map.putString(key, it) }
            for (key in LONGS) (state[key] as? Number)?.let { map.putLong(key, it.toLong()) }
            for (key in DOUBLES) (state[key] as? Number)?.let { map.putDouble(key, it.toDouble()) }
            for (key in BOOLEANS) (state[key] as? Boolean)?.let { map.putBoolean(key, it) }
            (state["labels"] as? Map<*, *>)?.let { labels ->
                map.putDataMap(
                    "labels",
                    DataMap().apply {
                        for ((key, text) in labels) {
                            if (key is String && text is String) putString(key, text)
                        }
                    },
                )
            }
            (state["exercises"] as? List<*>)?.let { list ->
                map.putDataMapArrayList(
                    "exercises",
                    ArrayList(
                        list.filterIsInstance<Map<*, *>>().map { item ->
                            DataMap().apply {
                                putString("name", item["name"] as? String ?: "")
                                putInt("done", (item["done"] as? Number)?.toInt() ?: 0)
                                putInt("total", (item["total"] as? Number)?.toInt() ?: 0)
                            }
                        },
                    ),
                )
            }
        }.asPutDataRequest().setUrgent()
        // Without a watch the write simply stays local.
        data.putDataItem(request)
        result.success(null)
    }

    fun close() = messages.removeListener(listener)

    companion object {
        const val STATE_PATH = "/workout"
        const val ACTION_PATH = "/action"

        /// What the watch can ask of the phone, as lib/app/watch_sync.dart.
        private val ACTIONS = setOf(
            "logNextSet", "extendRest", "skipRest", "togglePause", "beginWorkout",
            "startWorkout", "finishWorkout", "selectExercise",
        )
        private val STRINGS = listOf("workout", "exercise", "set", "progress", "routine", "setKey")
        private val LONGS = listOf(
            "restEndsAt", "restLength", "setEndsAt", "clockAt", "elapsedMs", "index", "routineSets", "reps",
        )
        private val DOUBLES = listOf("weightKg", "weightStep")
        private val BOOLEANS = listOf("hasNext", "canStart")
    }
}
