package com.example.mishirube.wear

import android.app.Activity
import android.app.AlertDialog
import android.graphics.Color
import android.os.Bundle
import android.os.SystemClock
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.Chronometer
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMap
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.Wearable
import org.json.JSONObject

/// The workout on the wrist: what to lift next with its weight and reps to
/// change, the rest, the clock, the exercise to switch to, today's workout
/// to start, and the way to finish. The phone keeps the records
/// (android/app/.../WearBridge.kt); this shows them and asks it to do what
/// the workout page does.
class WorkoutActivity : Activity(), DataClient.OnDataChangedListener {
    private lateinit var column: LinearLayout
    private var state: DataMap? = null

    /// The words the phone sends, in the app's language; the Chinese ones
    /// stand in until the first state arrives.
    private fun label(key: String, fallback: String): String =
        state?.getDataMap("labels")?.getString(key) ?: fallback

    /// The weight and reps the steppers show; they start from the set to do
    /// next and are sent with the log.
    private var weightKg = 0.0
    private var reps = 0
    private var setKey = ""

    /// Which set the phone says is next, sent back with a request to log it
    /// so that a tap that comes twice is not a second set; and the one
    /// already asked for, until the phone moves on.
    private var phoneSetKey = ""
    private var pendingKey: String? = null

    /// Whether a phone is in reach; what is asked of it otherwise is lost.
    private var isConnected = true

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(24, 32, 24, 32)
        }
        setContentView(ScrollView(this).apply { addView(column) })
        show(null)
    }

    /// The state the phone last published, and whether it can be reached.
    private fun load() {
        Wearable.getDataClient(this).dataItems.addOnSuccessListener { items ->
            items.firstOrNull { it.uri.path == STATE_PATH }
                ?.let { show(DataMapItem.fromDataItem(it).dataMap) }
            items.release()
        }
        checkConnection()
    }

    private fun checkConnection() {
        Wearable.getNodeClient(this).connectedNodes.addOnSuccessListener { nodes ->
            setConnected(nodes.isNotEmpty())
        }
    }

    private fun setConnected(connected: Boolean) {
        if (connected == isConnected) return
        isConnected = connected
        show(state)
    }

    /// A screen that was asleep has missed what the phone published.
    override fun onResume() {
        super.onResume()
        Wearable.getDataClient(this).addListener(this)
        load()
    }

    override fun onPause() {
        Wearable.getDataClient(this).removeListener(this)
        super.onPause()
    }

    override fun onDataChanged(events: DataEventBuffer) {
        for (event in events) {
            if (event.type == DataEvent.TYPE_CHANGED && event.dataItem.uri.path == STATE_PATH) {
                show(DataMapItem.fromDataItem(event.dataItem).dataMap)
            }
        }
    }

    private fun show(map: DataMap?) {
        state = map
        phoneSetKey = map?.getString("setKey").orEmpty()
        if (pendingKey != phoneSetKey) pendingKey = null
        column.removeAllViews()
        when (map?.getString("phase") ?: "none") {
            "idle" -> idle(map!!)
            "ready" -> ready(map!!)
            "running", "paused" -> running(map!!)
            else -> text(label("noWorkout", "沒有進行中的訓練"), 14f, Color.GRAY)
        }
    }

    /// Today's workout, to start from the wrist.
    private fun idle(map: DataMap) {
        text(map.getString("routine").orEmpty(), 16f)
        if (map.containsKey("routineSets")) {
            text(label("sets", "{} 組").replace("{}", "${map.getLong("routineSets")}"), 12f, Color.GRAY)
        }
        button(label("start", "開始運動"), TRAINING) { send("startWorkout") }
            .isEnabled = map.getBoolean("canStart") && isConnected
        notConnected()
    }

    private fun notConnected() {
        if (!isConnected) text(label("notConnected", "未連線"), 12f, Color.GRAY)
    }

    /// A workout arranged on the phone, not yet under way.
    private fun ready(map: DataMap) {
        text(map.getString("workout").orEmpty(), 16f)
        text(map.getString("exercise").orEmpty(), 12f, Color.GRAY)
        button(label("start", "開始運動"), TRAINING) { send("beginWorkout") }
            .isEnabled = isConnected
        notConnected()
    }

    private fun running(map: DataMap) {
        val isPaused = map.getString("phase") == "paused"
        text(map.getString("exercise").orEmpty(), 16f)
        row(
            text(map.getString("progress").orEmpty(), 12f, Color.GRAY, add = false),
            clock(map, isPaused),
        )

        val key = "${map.getLong("index")}|${map.getString("set").orEmpty()}"
        if (key != setKey) {
            setKey = key
            weightKg = if (map.containsKey("weightKg")) map.getDouble("weightKg") else 0.0
            reps = if (map.containsKey("reps")) map.getLong("reps").toInt() else 0
        }
        val hasWeight = map.containsKey("weightKg")
        val hasReps = map.containsKey("reps")
        if (map.getBoolean("hasNext")) {
            if (hasWeight) stepper({ "${weightText(weightKg)} kg" }, map.getDouble("weightStep").let { if (it > 0) it else 2.5 }, { weightKg = maxOf(0.0, weightKg + it) })
            if (hasReps) stepper({ label("reps", "{} 次").replace("{}", "$reps") }, 1.0, { reps = maxOf(0, reps + it.toInt()) })
            if (!hasWeight && !hasReps) text(map.getString("set").orEmpty(), 20f, TRAINING)
            button(label("logSet", "完成這一組"), TRAINING) {
                pendingKey = phoneSetKey
                // A phone that never answers with a new state must not leave
                // the button off for good.
                column.postDelayed({
                    if (pendingKey == phoneSetKey) {
                        pendingKey = null
                        show(state)
                    }
                }, 4000)
                send(
                    "logNextSet",
                    JSONObject().apply {
                        if (hasWeight) put("weightKg", weightKg)
                        if (hasReps) put("reps", reps)
                        put("setKey", phoneSetKey)
                    },
                )
                show(state)
            }.isEnabled = !isPaused && isConnected && pendingKey != phoneSetKey
            notConnected()
        } else {
            text(map.getString("set").orEmpty(), 20f, TRAINING)
        }

        val restLeft = map.getLong("restEndsAt") - System.currentTimeMillis()
        if (map.containsKey("restEndsAt") && restLeft > 0) rest(restLeft)

        val index = map.getLong("index").toInt()
        val count = map.getDataMapArrayList("exercises")?.size ?: 0
        row(
            button("‹", Color.DKGRAY, add = false) { send("selectExercise", JSONObject().put("index", index - 1)) }
                .apply { isEnabled = index > 0 },
            button("›", Color.DKGRAY, add = false) { send("selectExercise", JSONObject().put("index", index + 1)) }
                .apply { isEnabled = index < count - 1 },
        )
        button(if (isPaused) label("resume", "繼續") else label("pause", "暫停"), Color.DKGRAY) { send("togglePause") }
        button(label("finish", "完成訓練"), Color.DKGRAY) { confirmFinish() }
    }

    private fun confirmFinish() {
        AlertDialog.Builder(this)
            .setTitle(label("confirmTitle", "結束這次訓練？"))
            .setPositiveButton(label("confirmSave", "結束並儲存")) { _, _ -> send("finishWorkout") }
            .setNegativeButton(label("confirmKeep", "繼續訓練"), null)
            .show()
    }

    /// The time the workout has taken: counting while it runs, held while it
    /// is paused.
    private fun clock(map: DataMap, isPaused: Boolean): View {
        if (isPaused) {
            val seconds = map.getLong("elapsedMs") / 1000
            return text(clockText(seconds), 12f, Color.rgb(0xFF, 0xB0, 0x20), add = false)
        }
        return Chronometer(this).apply {
            textSize = 12f
            setTextColor(Color.GRAY)
            base = SystemClock.elapsedRealtime() - (System.currentTimeMillis() - map.getLong("clockAt"))
            start()
        }
    }

    private fun clockText(totalSeconds: Long): String {
        val hours = totalSeconds / 3600
        val minutes = totalSeconds % 3600 / 60
        val seconds = totalSeconds % 60
        return if (hours > 0) "%d:%02d:%02d".format(hours, minutes, seconds) else "%d:%02d".format(minutes, seconds)
    }

    /// What is left of the rest, to lengthen, cut or skip.
    private fun rest(leftMillis: Long) {
        text(label("rest", "休息"), 12f, Color.GRAY)
        column.addView(
            Chronometer(this).apply {
                isCountDown = true
                textSize = 18f
                gravity = Gravity.CENTER
                base = SystemClock.elapsedRealtime() + leftMillis
                start()
            },
        )
        row(
            button("−15", Color.DKGRAY, add = false) { send("extendRest", JSONObject().put("seconds", -15)) },
            button("+15", Color.DKGRAY, add = false) { send("extendRest", JSONObject().put("seconds", 15)) },
            button(label("skip", "跳過"), Color.DKGRAY, add = false) { send("skipRest") },
        )
    }

    private fun stepper(label: () -> String, step: Double, change: (Double) -> Unit) {
        val value = TextView(this).apply {
            textSize = 16f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            text = label()
        }
        fun move(by: Double) {
            change(by)
            value.text = label()
        }
        row(
            button("−", Color.DKGRAY, add = false) { move(-step) },
            value,
            button("+", Color.DKGRAY, add = false) { move(step) },
        )
    }

    private fun weightText(kg: Double) = if (kg % 1.0 == 0.0) kg.toLong().toString() else kg.toString()

    private fun text(value: String, size: Float, color: Int = Color.WHITE, add: Boolean = true): TextView =
        TextView(this).apply {
            text = value
            textSize = size
            setTextColor(color)
            gravity = Gravity.CENTER
            if (add) column.addView(this)
        }

    private fun button(label: String, color: Int, add: Boolean = true, onClick: () -> Unit): Button =
        Button(this).apply {
            text = label
            setTextColor(if (color == TRAINING) Color.BLACK else Color.WHITE)
            backgroundTintList = android.content.res.ColorStateList.valueOf(color)
            setOnClickListener { onClick() }
            if (add) column.addView(this)
        }

    private fun row(vararg views: View) {
        column.addView(
            LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER
                views.forEach {
                    addView(it, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
                }
            },
        )
    }

    private fun send(action: String, extras: JSONObject = JSONObject()) {
        val payload = extras.put("action", action).toString().toByteArray()
        Wearable.getNodeClient(this).connectedNodes.addOnSuccessListener { nodes ->
            setConnected(nodes.isNotEmpty())
            for (node in nodes) {
                Wearable.getMessageClient(this).sendMessage(node.id, ACTION_PATH, payload)
            }
        }
    }

    private companion object {
        const val STATE_PATH = "/workout"
        const val ACTION_PATH = "/action"

        /// The app's green, as AppColors.training in lib/app/theme.dart.
        val TRAINING = Color.rgb(0x2E, 0xE0, 0x9A)
    }
}
