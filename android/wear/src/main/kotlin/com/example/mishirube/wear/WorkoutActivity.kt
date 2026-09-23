package com.example.mishirube.wear

import android.app.Activity
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

/// The running workout on the wrist: what to lift next, the rest, and
/// logging the set without reaching for the phone. The phone keeps the
/// records (android/app/.../WearBridge.kt); this only shows them and asks
/// it to log.
class WorkoutActivity : Activity(), DataClient.OnDataChangedListener {
    private lateinit var exercise: TextView
    private lateinit var set: TextView
    private lateinit var progress: TextView
    private lateinit var rest: Chronometer
    private lateinit var log: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        fun text(size: Float, color: Int = Color.WHITE) = TextView(this).apply {
            textSize = size
            setTextColor(color)
            gravity = Gravity.CENTER
        }
        exercise = text(16f)
        set = text(20f, TRAINING)
        progress = text(12f, Color.GRAY)
        rest = Chronometer(this).apply {
            isCountDown = true
            textSize = 18f
            gravity = Gravity.CENTER
            visibility = View.GONE
        }
        log = Button(this).apply {
            text = "完成這一組"
            setOnClickListener { logNextSet() }
        }
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(24, 32, 24, 32)
            listOf(exercise, set, progress, rest, log).forEach(::addView)
        }
        setContentView(ScrollView(this).apply { addView(column) })
        show(null)
        Wearable.getDataClient(this).dataItems.addOnSuccessListener { items ->
            items.firstOrNull { it.uri.path == STATE_PATH }
                ?.let { show(DataMapItem.fromDataItem(it).dataMap) }
            items.release()
        }
    }

    override fun onResume() {
        super.onResume()
        Wearable.getDataClient(this).addListener(this)
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

    private fun show(state: DataMap?) {
        val name = state?.getString("exercise").orEmpty()
        if (name.isEmpty()) {
            exercise.text = "沒有進行中的訓練"
            listOf(set, progress, rest, log).forEach { it.visibility = View.GONE }
            return
        }
        exercise.text = name
        set.text = state?.getString("set").orEmpty()
        progress.text = state?.getString("progress").orEmpty()
        set.visibility = View.VISIBLE
        progress.visibility = View.VISIBLE
        log.visibility = if (state?.getBoolean("hasNext") == true) View.VISIBLE else View.GONE
        val left = (state?.getLong("restEndsAt") ?: 0L) - System.currentTimeMillis()
        if (left > 0) {
            rest.base = SystemClock.elapsedRealtime() + left
            rest.visibility = View.VISIBLE
            rest.start()
        } else {
            rest.stop()
            rest.visibility = View.GONE
        }
    }

    private fun logNextSet() {
        Wearable.getNodeClient(this).connectedNodes.addOnSuccessListener { nodes ->
            for (node in nodes) {
                Wearable.getMessageClient(this).sendMessage(node.id, LOG_PATH, ByteArray(0))
            }
        }
    }

    private companion object {
        const val STATE_PATH = "/workout"
        const val LOG_PATH = "/log-next-set"

        /// The app's green, as AppColors.training in lib/app/theme.dart.
        val TRAINING = Color.rgb(0x2E, 0xE0, 0x9A)
    }
}
