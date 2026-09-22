package com.example.mishirube

import androidx.activity.ComponentActivity
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HydrationRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.WeightRecord
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
        return listOf("sleep", "weight", "workouts", "water").filter { kind ->
            val needed = when (kind) {
                "workouts" -> HealthPermission.getReadPermission(ExerciseSessionRecord::class)
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
            else -> emptyList()
        }
    }.map { HealthPermission.getReadPermission(it) }.toSet()

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

    /** A session without stages was all asleep; with them, each stage is a sample. */
    private fun sleepRows(session: SleepSessionRecord): List<Map<String, Any>> {
        if (session.stages.isEmpty()) {
            return listOf(sleepRow(session.startTime, session.endTime, "asleep"))
        }
        return session.stages.mapNotNull { stage ->
            val name = when (stage.stage) {
                SleepSessionRecord.STAGE_TYPE_SLEEPING,
                SleepSessionRecord.STAGE_TYPE_LIGHT,
                SleepSessionRecord.STAGE_TYPE_DEEP,
                SleepSessionRecord.STAGE_TYPE_REM -> "asleep"
                SleepSessionRecord.STAGE_TYPE_AWAKE,
                SleepSessionRecord.STAGE_TYPE_AWAKE_IN_BED,
                SleepSessionRecord.STAGE_TYPE_OUT_OF_BED -> "awake"
                else -> null
            }
            name?.let { sleepRow(stage.startTime, stage.endTime, it) }
        }
    }

    private fun sleepRow(start: Instant, end: Instant, stage: String) = mapOf<String, Any>(
        "start" to start.toEpochMilli(),
        "end" to end.toEpochMilli(),
        "stage" to stage,
    )

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
