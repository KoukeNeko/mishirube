package com.example.mishirube

import android.content.pm.PackageManager
import androidx.activity.ComponentActivity
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.HeartRateVariabilityRmssdRecord
import androidx.health.connect.client.records.HydrationRecord
import androidx.health.connect.client.records.OxygenSaturationRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.RespiratoryRateRecord
import androidx.health.connect.client.records.SkinTemperatureRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.time.Instant
import kotlin.reflect.KClass
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Health Connect, read only, for lib/backend/health/health_source.dart.
 *
 * Answers the same three calls Apple Health answers on iOS: whether
 * Health Connect is here, a request to read, and one kind's records in
 * a window, named in the app's terms. Turning sleep into nights happens
 * in Dart (nightsOf), where it can be tested.
 */
class HealthConnectBridge(
    private val activity: ComponentActivity,
    private val channel: MethodChannel,
    private var privacyRequested: Boolean,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var pendingRequest: MethodChannel.Result? = null

    // Registered while the activity is being created, as the result API
    // requires.
    private val permissionLauncher = activity.registerForActivityResult(
        PermissionController.createRequestPermissionResultContract()
    ) {
        // The request went through; which kinds were allowed shows in
        // what the reads return.
        pendingRequest?.success(true)
        pendingRequest = null
    }

    private val client by lazy { HealthConnectClient.getOrCreate(activity) }

    /** Asks Dart to show the privacy page now. */
    fun showPrivacy() {
        channel.invokeMethod("showPrivacy", null)
    }

    /** The kinds whose read permission is granted; a workout needs its session. */
    private suspend fun grantedKinds(): List<String> {
        val granted = client.permissionController.getGrantedPermissions()
        return listOf("sleep", "weight", "workouts", "water", "overnight").filter { kind ->
            val needed = when (kind) {
                "workouts" -> HealthPermission.getReadPermission(ExerciseSessionRecord::class)
                // Heart rate stands for the rest: one allowed is enough to read.
                "overnight" -> HealthPermission.getReadPermission(HeartRateRecord::class)
                else -> permissionsFor(listOf(kind)).single()
            }
            needed in granted
        }
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(
                HealthConnectClient.getSdkStatus(activity) == HealthConnectClient.SDK_AVAILABLE
            )
            "takePrivacyRequest" -> {
                result.success(privacyRequested)
                privacyRequested = false
            }
            "grantedKinds" -> scope.launch {
                try {
                    result.success(grantedKinds())
                } catch (error: Exception) {
                    result.error("failed", error.message, null)
                }
            }
            "requestAccess" -> {
                val permissions = permissionsFor(call.argument<List<String>>("kinds").orEmpty())
                scope.launch {
                    try {
                        val granted = client.permissionController.getGrantedPermissions()
                        if (granted.containsAll(permissions)) {
                            result.success(true)
                        } else {
                            pendingRequest = result
                            permissionLauncher.launch(permissions)
                        }
                    } catch (error: Exception) {
                        result.error("failed", error.message, null)
                    }
                }
            }
            "overnight" -> {
                val windows = call.argument<List<List<Number>>>("windows").orEmpty().map {
                    Instant.ofEpochMilli(it[0].toLong()) to Instant.ofEpochMilli(it[1].toLong())
                }
                scope.launch {
                    try {
                        result.success(overnight(windows))
                    } catch (error: Exception) {
                        result.error("failed", error.message, null)
                    }
                }
            }
            "read" -> {
                val kind = call.argument<String>("kind")
                val from = call.argument<Number>("from")?.toLong()
                val to = call.argument<Number>("to")?.toLong()
                if (kind == null || from == null || to == null) {
                    result.error("badArguments", null, null)
                    return
                }
                scope.launch {
                    try {
                        result.success(
                            read(kind, Instant.ofEpochMilli(from), Instant.ofEpochMilli(to))
                        )
                    } catch (error: Exception) {
                        result.error("failed", error.message, null)
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun permissionsFor(kinds: List<String>): Set<String> = kinds.flatMap { kind ->
        when (kind) {
            "sleep" -> listOf(SleepSessionRecord::class)
            "weight" -> listOf(WeightRecord::class)
            // A session's distance is recorded apart from the session.
            "workouts" -> listOf(ExerciseSessionRecord::class, DistanceRecord::class)
            "water" -> listOf(HydrationRecord::class)
            "overnight" -> overnightTypes
            else -> emptyList()
        }
    }.map { HealthPermission.getReadPermission(it) }.toSet()

    /** What is read over a sleep; HRV is RMSSD here and stays RMSSD. */
    private val overnightTypes = listOf(
        HeartRateRecord::class,
        RespiratoryRateRecord::class,
        OxygenSaturationRecord::class,
        HeartRateVariabilityRmssdRecord::class,
        SkinTemperatureRecord::class,
    )

    /**
     * Each measure's range over each window, as rows the Dart side reads.
     * A measure not allowed is left out rather than failing the rest.
     */
    private suspend fun overnight(windows: List<Pair<Instant, Instant>>): List<Map<String, Any>> {
        if (windows.isEmpty()) return emptyList()
        val granted = client.permissionController.getGrantedPermissions()
        fun allowed(type: KClass<out Record>) = HealthPermission.getReadPermission(type) in granted
        val rows = mutableListOf<Map<String, Any>>()
        for ((index, window) in windows.withIndex()) {
            val (from, to) = window
            fun add(measure: String, values: List<Double>) {
                if (values.isEmpty()) return
                rows += mapOf(
                    "window" to index,
                    "measure" to measure,
                    "min" to values.min(),
                    "max" to values.max(),
                    "avg" to values.average(),
                    "count" to values.size,
                )
            }
            fun inWindow(time: Instant) = !time.isBefore(from) && time.isBefore(to)
            if (allowed(HeartRateRecord::class)) {
                add("heartRate", readAll(HeartRateRecord::class, from, to).flatMap { record ->
                    record.samples.filter { inWindow(it.time) }.map { it.beatsPerMinute.toDouble() }
                })
            }
            if (allowed(RespiratoryRateRecord::class)) {
                add("respiratoryRate", readAll(RespiratoryRateRecord::class, from, to)
                    .filter { inWindow(it.time) }.map { it.rate })
            }
            if (allowed(OxygenSaturationRecord::class)) {
                add("oxygenSaturation", readAll(OxygenSaturationRecord::class, from, to)
                    .filter { inWindow(it.time) }.map { it.percentage.value })
            }
            if (allowed(HeartRateVariabilityRmssdRecord::class)) {
                add("hrvRmssd", readAll(HeartRateVariabilityRmssdRecord::class, from, to)
                    .filter { inWindow(it.time) }.map { it.heartRateVariabilityMillis })
            }
            if (allowed(SkinTemperatureRecord::class)) {
                // Health Connect keeps skin temperature as changes from a
                // baseline; that is what is shown.
                add("skinTemperatureChange", readAll(SkinTemperatureRecord::class, from, to)
                    .flatMap { record ->
                        record.deltas.filter { inWindow(it.time) }.map { it.delta.inCelsius }
                    })
            }
        }
        return rows
    }

    private suspend fun read(kind: String, from: Instant, to: Instant): List<Map<String, Any>> =
        when (kind) {
            "sleep" -> readAll(SleepSessionRecord::class, from, to).flatMap(::sleepRows)
            "weight" -> readAll(WeightRecord::class, from, to).map {
                mapOf(
                    "id" to it.metadata.id,
                    "at" to it.time.toEpochMilli(),
                    "kg" to it.weight.inKilograms,
                )
            }
            "water" -> readAll(HydrationRecord::class, from, to).map {
                mapOf(
                    "id" to it.metadata.id,
                    "at" to it.startTime.toEpochMilli(),
                    "ml" to it.volume.inMilliliters,
                )
            }
            "workouts" -> readAll(ExerciseSessionRecord::class, from, to).map { session ->
                val row = mutableMapOf<String, Any>(
                    "id" to session.metadata.id,
                    "start" to session.startTime.toEpochMilli(),
                    "end" to session.endTime.toEpochMilli(),
                    "activity" to activity(session.exerciseType),
                    "native" to "ExerciseSessionRecord.${session.exerciseType}",
                )
                distanceMetres(session.startTime, session.endTime)?.let { row["distance"] = it }
                row
            }
            else -> emptyList()
        }

    private suspend fun <T : Record> readAll(type: KClass<T>, from: Instant, to: Instant): List<T> {
        val records = mutableListOf<T>()
        var pageToken: String? = null
        do {
            val response = client.readRecords(
                ReadRecordsRequest(type, TimeRangeFilter.between(from, to), pageToken = pageToken)
            )
            records += response.records
            pageToken = response.pageToken
        } while (pageToken != null)
        return records
    }

    private suspend fun distanceMetres(start: Instant, end: Instant): Double? =
        client.aggregate(
            AggregateRequest(setOf(DistanceRecord.DISTANCE_TOTAL), TimeRangeFilter.between(start, end))
        )[DistanceRecord.DISTANCE_TOTAL]?.inMeters

    /**
     * A session without stages was all asleep; with them, each stage is a
     * sample. Light is shown beside Apple's core sleep but keeps its name.
     */
    private fun sleepRows(session: SleepSessionRecord): List<Map<String, Any>> {
        val metadata = session.metadata
        if (session.stages.isEmpty()) {
            return listOf(
                sleepRow(metadata, session.startTime, session.endTime, "asleep", "SESSION")
            )
        }
        return session.stages.mapNotNull { stage ->
            val names = when (stage.stage) {
                SleepSessionRecord.STAGE_TYPE_SLEEPING -> "asleep" to "STAGE_TYPE_SLEEPING"
                SleepSessionRecord.STAGE_TYPE_LIGHT -> "core" to "STAGE_TYPE_LIGHT"
                SleepSessionRecord.STAGE_TYPE_DEEP -> "deep" to "STAGE_TYPE_DEEP"
                SleepSessionRecord.STAGE_TYPE_REM -> "rem" to "STAGE_TYPE_REM"
                SleepSessionRecord.STAGE_TYPE_AWAKE -> "awake" to "STAGE_TYPE_AWAKE"
                SleepSessionRecord.STAGE_TYPE_AWAKE_IN_BED -> "awake" to "STAGE_TYPE_AWAKE_IN_BED"
                SleepSessionRecord.STAGE_TYPE_OUT_OF_BED -> "awake" to "STAGE_TYPE_OUT_OF_BED"
                else -> null
            }
            names?.let { (stageName, native) ->
                sleepRow(metadata, stage.startTime, stage.endTime, stageName, native)
            }
        }
    }

    private fun sleepRow(
        metadata: Metadata,
        start: Instant,
        end: Instant,
        stage: String,
        native: String,
    ): Map<String, Any> {
        val origin = metadata.dataOrigin.packageName
        // The watch or ring when the writer says; the app otherwise.
        val device = listOfNotNull(metadata.device?.manufacturer, metadata.device?.model)
            .joinToString(" ")
        return mapOf(
            "start" to start.toEpochMilli(),
            "end" to end.toEpochMilli(),
            "stage" to stage,
            "native" to "SleepSessionRecord.$native",
            "source" to origin,
            "sourceName" to device.ifEmpty { appLabel(origin) },
            "manual" to (metadata.recordingMethod == Metadata.RECORDING_METHOD_MANUAL_ENTRY),
        )
    }

    /** What the user calls the app that wrote a record, or its package name. */
    private fun appLabel(packageName: String): String = try {
        val manager = activity.packageManager
        manager.getApplicationLabel(manager.getApplicationInfo(packageName, 0)).toString()
    } catch (error: PackageManager.NameNotFoundException) {
        // Uninstalled since it wrote the record, or hidden from this app.
        packageName
    }

    /** The app's activity type ids; anything else is "other". */
    private fun activity(type: Int): String = when (type) {
        ExerciseSessionRecord.EXERCISE_TYPE_RUNNING,
        ExerciseSessionRecord.EXERCISE_TYPE_RUNNING_TREADMILL -> "running"
        ExerciseSessionRecord.EXERCISE_TYPE_WALKING -> "walking"
        ExerciseSessionRecord.EXERCISE_TYPE_HIKING -> "hiking"
        ExerciseSessionRecord.EXERCISE_TYPE_BIKING,
        ExerciseSessionRecord.EXERCISE_TYPE_BIKING_STATIONARY -> "cycling"
        ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_POOL,
        ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_OPEN_WATER -> "swimming"
        ExerciseSessionRecord.EXERCISE_TYPE_ROWING,
        ExerciseSessionRecord.EXERCISE_TYPE_ROWING_MACHINE -> "rowing"
        ExerciseSessionRecord.EXERCISE_TYPE_ELLIPTICAL -> "elliptical"
        ExerciseSessionRecord.EXERCISE_TYPE_STAIR_CLIMBING,
        ExerciseSessionRecord.EXERCISE_TYPE_STAIR_CLIMBING_MACHINE -> "stairs"
        ExerciseSessionRecord.EXERCISE_TYPE_BASKETBALL -> "basketball"
        ExerciseSessionRecord.EXERCISE_TYPE_BADMINTON -> "badminton"
        ExerciseSessionRecord.EXERCISE_TYPE_YOGA -> "yoga"
        else -> "other"
    }
}
