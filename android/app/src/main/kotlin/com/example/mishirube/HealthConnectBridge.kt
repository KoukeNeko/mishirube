package com.example.mishirube

import android.content.pm.PackageManager
import androidx.activity.ComponentActivity
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.HealthConnectFeatures
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.aggregate.AggregateMetric
import android.location.Geocoder
import androidx.health.connect.client.contracts.ExerciseRouteRequestContract
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.CyclingPedalingCadenceRecord
import androidx.health.connect.client.records.ExerciseRoute
import androidx.health.connect.client.records.ExerciseRouteResult
import androidx.health.connect.client.records.PowerRecord
import androidx.health.connect.client.records.SpeedRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ElevationGainedRecord
import androidx.health.connect.client.records.FloorsClimbedRecord
import androidx.health.connect.client.records.WheelchairPushesRecord
import androidx.health.connect.client.records.RestingHeartRateRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.Vo2MaxRecord
import androidx.health.connect.client.records.BasalMetabolicRateRecord
import androidx.health.connect.client.records.BoneMassRecord
import androidx.health.connect.client.records.LeanBodyMassRecord
import androidx.health.connect.client.records.BodyFatRecord
import androidx.health.connect.client.records.HeightRecord
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
import androidx.health.connect.client.request.AggregateGroupByDurationRequest
import androidx.health.connect.client.request.AggregateGroupByPeriodRequest
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.Period
import java.time.ZoneId
import kotlin.reflect.KClass
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlin.coroutines.resume

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

    /** Waiting on the user to let the app read another app's route. */
    private var pendingRoute: ((ExerciseRoute?) -> Unit)? = null

    // Another app's route needs the user's say-so each time, asked from
    // the page that shows it; registered while the activity is created.
    private val routeLauncher = activity.registerForActivityResult(
        ExerciseRouteRequestContract()
    ) { route ->
        pendingRoute?.invoke(route)
        pendingRoute = null
    }

    /** Asks Dart to show the privacy page now. */
    fun showPrivacy() {
        channel.invokeMethod("showPrivacy", null)
    }

    /** The kinds whose read permission is granted; a workout needs its session. */
    private suspend fun grantedKinds(): List<String> {
        val granted = client.permissionController.getGrantedPermissions()
        return listOf("sleep", "weight", "body", "workouts", "water", "overnight", "activity").filter { kind ->
            val needed = when (kind) {
                // Steps stand for the rest: each allowed one is read.
                "activity" -> HealthPermission.getReadPermission(StepsRecord::class)
                "workouts" -> HealthPermission.getReadPermission(ExerciseSessionRecord::class)
                // Height stands for the rest: each allowed one is read.
                "body" -> HealthPermission.getReadPermission(HeightRecord::class)
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
                            permissionLauncher.launch(permissions + historyPermission())
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
            "workoutDetail" -> {
                val id = call.argument<String>("id")
                if (id == null) {
                    result.error("badArguments", null, null)
                    return
                }
                scope.launch {
                    try {
                        result.success(workoutDetail(id))
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
                val daily = call.argument<Boolean>("daily") ?: false
                scope.launch {
                    try {
                        result.success(
                            read(kind, Instant.ofEpochMilli(from), Instant.ofEpochMilli(to), daily)
                        )
                    } catch (error: Exception) {
                        result.error("failed", error.message, null)
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Reading past the 30 days before access was first given, asked with
     * the rest where Health Connect offers it, so trends reach further
     * back than the day the app was installed. Not required: without it
     * the app reads what it may.
     */
    private fun historyPermission(): Set<String> =
        if (client.features.getFeatureStatus(
                HealthConnectFeatures.FEATURE_READ_HEALTH_DATA_HISTORY,
            ) == HealthConnectFeatures.FEATURE_STATUS_AVAILABLE
        ) {
            setOf(HealthPermission.PERMISSION_READ_HEALTH_DATA_HISTORY)
        } else {
            emptySet()
        }

    private fun permissionsFor(kinds: List<String>): Set<String> = kinds.flatMap { kind ->
        when (kind) {
            "sleep" -> listOf(SleepSessionRecord::class)
            "weight" -> listOf(WeightRecord::class)
            // A session's distance is recorded apart from the session.
            // A session's figures are recorded apart from the session.
            "workouts" -> listOf(
                ExerciseSessionRecord::class,
                DistanceRecord::class,
                HeartRateRecord::class,
                SpeedRecord::class,
                PowerRecord::class,
                CyclingPedalingCadenceRecord::class,
                ActiveCaloriesBurnedRecord::class,
                TotalCaloriesBurnedRecord::class,
                ElevationGainedRecord::class,
                StepsRecord::class,
            )
            "water" -> listOf(HydrationRecord::class)
            "overnight" -> overnightTypes
            "body" -> bodyTypes
            "activity" -> activityTypes
            else -> emptyList()
        }
    }.map { HealthPermission.getReadPermission(it) }.toSet()

    /** Body figures Health Connect keeps; there is no skeletal muscle. */
    private val bodyTypes = listOf(
        HeightRecord::class,
        BodyFatRecord::class,
        LeanBodyMassRecord::class,
        BoneMassRecord::class,
        BasalMetabolicRateRecord::class,
    )

    /** Each allowed body figure in the app's metric and unit. */
    private suspend fun bodyRows(from: Instant, to: Instant): List<Map<String, Any>> {
        val granted = client.permissionController.getGrantedPermissions()
        fun allowed(type: KClass<out Record>) = HealthPermission.getReadPermission(type) in granted
        fun row(id: String, at: Instant, metric: String, value: Double) =
            mapOf("id" to id, "at" to at.toEpochMilli(), "metric" to metric, "value" to value)
        val rows = mutableListOf<Map<String, Any>>()
        if (allowed(HeightRecord::class)) {
            rows += readAll(HeightRecord::class, from, to).map {
                row(it.metadata.id, it.time, "height", it.height.inMeters * 100)
            }
        }
        if (allowed(BodyFatRecord::class)) {
            // Already 0–100 here, unlike Apple Health's fraction.
            rows += readAll(BodyFatRecord::class, from, to).map {
                row(it.metadata.id, it.time, "bodyFat", it.percentage.value)
            }
        }
        if (allowed(LeanBodyMassRecord::class)) {
            rows += readAll(LeanBodyMassRecord::class, from, to).map {
                row(it.metadata.id, it.time, "leanMass", it.mass.inKilograms)
            }
        }
        if (allowed(BoneMassRecord::class)) {
            rows += readAll(BoneMassRecord::class, from, to).map {
                row(it.metadata.id, it.time, "boneMass", it.mass.inKilograms)
            }
        }
        if (allowed(BasalMetabolicRateRecord::class)) {
            rows += readAll(BasalMetabolicRateRecord::class, from, to).map {
                row(
                    it.metadata.id,
                    it.time,
                    "basalMetabolicRate",
                    it.basalMetabolicRate.inKilocaloriesPerDay,
                )
            }
        }
        return rows
    }

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

    private suspend fun read(
        kind: String,
        from: Instant,
        to: Instant,
        daily: Boolean = false,
    ): List<Map<String, Any>> =
        when (kind) {
            "sleep" -> readAll(SleepSessionRecord::class, from, to).flatMap(::sleepRows)
            "body" -> bodyRows(from, to)
            "activity" -> activityRows(from, to, daily)
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

    /** Everyday movement and the fitness figures measured through the day. */
    private val activityTypes = listOf(
        StepsRecord::class,
        DistanceRecord::class,
        ActiveCaloriesBurnedRecord::class,
        FloorsClimbedRecord::class,
        ElevationGainedRecord::class,
        WheelchairPushesRecord::class,
        RestingHeartRateRecord::class,
        HeartRateVariabilityRmssdRecord::class,
        Vo2MaxRecord::class,
    )

    /**
     * Each allowed activity metric in the app's terms: counted ones as
     * hourly totals from Health Connect's aggregation, which keeps the
     * source the user ranked first where a phone and a watch overlap;
     * measured ones as each local day's average.
     */
    private suspend fun activityRows(
        from: Instant,
        to: Instant,
        daily: Boolean,
    ): List<Map<String, Any>> {
        val granted = client.permissionController.getGrantedPermissions()
        fun allowed(type: KClass<out Record>) = HealthPermission.getReadPermission(type) in granted
        val zone = ZoneId.systemDefault()
        val firstDay = from.atZone(zone).toLocalDate()
        val rows = mutableListOf<Map<String, Any>>()
        fun row(metric: String, start: Instant, end: Instant, value: Double) {
            rows += mapOf(
                "metric" to metric,
                "start" to start.toEpochMilli(),
                "end" to end.toEpochMilli(),
                "value" to value,
            )
        }

        val counted = buildList<Pair<String, AggregateMetric<*>>> {
            if (allowed(StepsRecord::class)) add("steps" to StepsRecord.COUNT_TOTAL)
            if (allowed(DistanceRecord::class)) add("distance" to DistanceRecord.DISTANCE_TOTAL)
            if (allowed(ActiveCaloriesBurnedRecord::class)) {
                add("activeEnergy" to ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL)
            }
            if (allowed(FloorsClimbedRecord::class)) {
                add("floors" to FloorsClimbedRecord.FLOORS_CLIMBED_TOTAL)
            }
            if (allowed(ElevationGainedRecord::class)) {
                add("elevationGained" to ElevationGainedRecord.ELEVATION_GAINED_TOTAL)
            }
            if (allowed(WheelchairPushesRecord::class)) {
                add("wheelchairPushes" to WheelchairPushesRecord.COUNT_TOTAL)
            }
            // Asked for with the body figures; read here when allowed.
            if (allowed(BasalMetabolicRateRecord::class)) {
                add("basalEnergy" to BasalMetabolicRateRecord.BASAL_CALORIES_TOTAL)
            }
        }
        if (counted.isNotEmpty()) {
            // A month at a time: one request returns every hour in it.
            var start = firstDay.atStartOfDay(zone).toInstant()
            while (start.isBefore(to)) {
                val end = minOf(start.plus(Duration.ofDays(30)), to)
                val buckets = client.aggregateGroupByDuration(
                    AggregateGroupByDurationRequest(
                        metrics = counted.map { it.second }.toSet(),
                        timeRangeFilter = TimeRangeFilter.between(start, end),
                        // By the hour, or by the day for years long past.
                        timeRangeSlicer = if (daily) Duration.ofDays(1) else Duration.ofHours(1),
                    )
                )
                for (bucket in buckets) {
                    for ((name, metric) in counted) {
                        @Suppress("UNCHECKED_CAST")
                        val total = bucket.result[metric as AggregateMetric<Any>]
                        val value = when (total) {
                            is Long -> total.toDouble()
                            is Double -> total
                            is androidx.health.connect.client.units.Length -> total.inMeters
                            is androidx.health.connect.client.units.Energy -> total.inKilocalories
                            else -> continue
                        }
                        row(name, bucket.startTime, bucket.endTime, value)
                    }
                }
                start = end
            }
        }

        // Each local day's average; heart rate is asked for with the
        // overnight figures and read here when allowed.
        for ((name, metric) in buildList {
            if (allowed(RestingHeartRateRecord::class)) {
                add("restingHeartRate" to RestingHeartRateRecord.BPM_AVG)
            }
            if (allowed(HeartRateRecord::class)) add("heartRate" to HeartRateRecord.BPM_AVG)
        }) {
            val days = client.aggregateGroupByPeriod(
                AggregateGroupByPeriodRequest(
                    metrics = setOf(metric),
                    timeRangeFilter = TimeRangeFilter.between(
                        firstDay.atStartOfDay(),
                        to.atZone(zone).toLocalDateTime(),
                    ),
                    timeRangeSlicer = Period.ofDays(1),
                )
            )
            for (day in days) {
                val bpm = day.result[metric] ?: continue
                row(
                    name,
                    day.startTime.atZone(zone).toInstant(),
                    day.endTime.atZone(zone).toInstant(),
                    bpm.toDouble(),
                )
            }
        }

        // Neither has an aggregate: each local day's readings averaged.
        fun daily(metric: String, readings: List<Pair<Instant, Double>>) {
            readings.groupBy { it.first.atZone(zone).toLocalDate() }
                .forEach { (date: LocalDate, values) ->
                    row(
                        metric,
                        date.atStartOfDay(zone).toInstant(),
                        date.plusDays(1).atStartOfDay(zone).toInstant(),
                        values.map { it.second }.average(),
                    )
                }
        }
        if (allowed(HeartRateVariabilityRmssdRecord::class)) {
            daily(
                "hrvRmssd",
                readAll(HeartRateVariabilityRmssdRecord::class, from, to)
                    .map { it.time to it.heartRateVariabilityMillis },
            )
        }
        if (allowed(Vo2MaxRecord::class)) {
            daily(
                "vo2Max",
                readAll(Vo2MaxRecord::class, from, to)
                    .map { it.time to it.vo2MillilitersPerMinuteKilogram },
            )
        }
        return rows
    }

    /**
     * Everything recorded during one exercise session, in the shape
     * lib/backend/health/health_source.dart reads: the session holds
     * its laps, segments and route; its figures are separate records,
     * read over its time and totalled by Health Connect.
     */
    private suspend fun workoutDetail(id: String): Map<String, Any>? {
        val session = try {
            client.readRecord(ExerciseSessionRecord::class, id).record
        } catch (error: Exception) {
            return null
        }
        val start = session.startTime
        val end = session.endTime
        val granted = client.permissionController.getGrantedPermissions()
        fun allowed(type: KClass<out Record>) = HealthPermission.getReadPermission(type) in granted
        fun offset(time: Instant) = (time.toEpochMilli() - start.toEpochMilli()).toDouble()
        val detail = mutableMapOf<String, Any>(
            "device" to (session.metadata.device?.model
                ?: appLabel(session.metadata.dataOrigin.packageName)),
        )

        val totals = client.aggregate(
            AggregateRequest(
                buildSet {
                    if (allowed(ActiveCaloriesBurnedRecord::class)) {
                        add(ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL)
                    }
                    if (allowed(TotalCaloriesBurnedRecord::class)) {
                        add(TotalCaloriesBurnedRecord.ENERGY_TOTAL)
                    }
                    if (allowed(DistanceRecord::class)) add(DistanceRecord.DISTANCE_TOTAL)
                    if (allowed(ElevationGainedRecord::class)) {
                        add(ElevationGainedRecord.ELEVATION_GAINED_TOTAL)
                    }
                    if (allowed(StepsRecord::class)) add(StepsRecord.COUNT_TOTAL)
                },
                TimeRangeFilter.between(start, end),
            )
        )
        detail["figures"] = buildMap {
            totals[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]?.let {
                put("activeEnergy", it.inKilocalories)
            }
            totals[TotalCaloriesBurnedRecord.ENERGY_TOTAL]?.let { put("totalEnergy", it.inKilocalories) }
            totals[DistanceRecord.DISTANCE_TOTAL]?.let { put("distance", it.inMeters) }
            totals[StepsRecord.COUNT_TOTAL]?.let { put("steps", it.toDouble()) }
        }
        totals[ElevationGainedRecord.ELEVATION_GAINED_TOTAL]?.let {
            detail["elevationGain"] = it.inMeters
        }

        val series = mutableMapOf<String, List<List<Double>>>()
        if (allowed(HeartRateRecord::class)) {
            series["heartRate"] = readAll(HeartRateRecord::class, start, end)
                .flatMap { it.samples }
                .filter { !it.time.isBefore(start) && !it.time.isAfter(end) }
                .map { listOf(offset(it.time), it.beatsPerMinute.toDouble()) }
            // What the heart did in the three minutes after.
            val after = end.plus(Duration.ofMinutes(3))
            series["recovery"] = readAll(HeartRateRecord::class, end, after)
                .flatMap { it.samples }
                .filter { !it.time.isBefore(end) && !it.time.isAfter(after) }
                .map {
                    listOf((it.time.toEpochMilli() - end.toEpochMilli()).toDouble(),
                        it.beatsPerMinute.toDouble())
                }
        }
        if (allowed(SpeedRecord::class)) {
            series["speed"] = readAll(SpeedRecord::class, start, end)
                .flatMap { it.samples }
                .map { listOf(offset(it.time), it.speed.inMetersPerSecond) }
        }
        if (allowed(PowerRecord::class)) {
            series["power"] = readAll(PowerRecord::class, start, end)
                .flatMap { it.samples }
                .map { listOf(offset(it.time), it.power.inWatts) }
        }
        if (allowed(CyclingPedalingCadenceRecord::class)) {
            series["cadence"] = readAll(CyclingPedalingCadenceRecord::class, start, end)
                .flatMap { it.samples }
                .map { listOf(offset(it.time), it.revolutionsPerMinute) }
        }
        detail["series"] = series.filterValues { it.isNotEmpty() }

        val route = when (val result = session.exerciseRouteResult) {
            is ExerciseRouteResult.Data -> result.exerciseRoute
            is ExerciseRouteResult.ConsentRequired -> askForRoute(id)
            else -> null
        }
        route?.route?.takeIf { it.size > 1 }?.let { locations ->
            detail["route"] = locations.zipWithNext().map { (from, to) ->
                val seconds = (to.time.toEpochMilli() - from.time.toEpochMilli()) / 1000.0
                val metres = FloatArray(1)
                android.location.Location.distanceBetween(
                    from.latitude, from.longitude, to.latitude, to.longitude, metres)
                listOf(
                    to.latitude, to.longitude, to.altitude?.inMeters ?: 0.0,
                    offset(to.time), if (seconds > 0) metres[0] / seconds else 0.0,
                )
            }
            placeOf(locations.first())?.let { detail["place"] = it }
        }

        detail["laps"] = session.laps.map {
            listOf("lap", offset(it.startTime), offset(it.endTime))
        } + session.segments.map {
            listOf("segment", offset(it.startTime), offset(it.endTime))
        }
        return detail
    }

    /** Asks the user to let the app read the route of session [id]. */
    private suspend fun askForRoute(id: String): ExerciseRoute? =
        suspendCancellableCoroutine { continuation ->
            pendingRoute = { continuation.resume(it) }
            routeLauncher.launch(id)
        }

    /** The city a route starts in, and nothing more precise. */
    private suspend fun placeOf(location: ExerciseRoute.Location): String? =
        withContext(Dispatchers.IO) {
            try {
                @Suppress("DEPRECATION")
                Geocoder(activity).getFromLocation(location.latitude, location.longitude, 1)
                    ?.firstOrNull()
                    ?.let { it.locality ?: it.subAdminArea }
            } catch (error: java.io.IOException) {
                // No network or no geocoder: the page goes without a place.
                null
            }
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
