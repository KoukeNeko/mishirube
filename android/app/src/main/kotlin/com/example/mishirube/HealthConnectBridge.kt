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
import androidx.health.connect.client.records.BodyWaterMassRecord
import androidx.health.connect.client.records.CyclingPedalingCadenceRecord
import androidx.health.connect.client.records.ExerciseRoute
import androidx.health.connect.client.records.ExerciseRouteResult
import androidx.health.connect.client.records.MealType
import androidx.health.connect.client.records.NutritionRecord
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
import androidx.health.connect.client.units.Mass
import androidx.health.connect.client.units.Energy
import androidx.health.connect.client.units.Length
import androidx.health.connect.client.units.Percentage
import androidx.health.connect.client.units.Power
import androidx.health.connect.client.units.Volume
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
        return listOf(
            "sleep", "weight", "body", "workouts", "water", "nutrition", "overnight", "activity",
        ).filter { kind ->
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
                val kinds = call.argument<List<String>>("kinds").orEmpty()
                val permissions = permissionsFor(kinds) + writePermissionsFor(kinds)
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
            "overnightSeries" -> {
                val from = call.argument<Number>("from")?.toLong()
                val to = call.argument<Number>("to")?.toLong()
                if (from == null || to == null) {
                    result.error("badArguments", null, null)
                    return
                }
                scope.launch {
                    try {
                        result.success(
                            overnightSeries(Instant.ofEpochMilli(from), Instant.ofEpochMilli(to)),
                        )
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
            "write" -> {
                val writes = call.argument<List<Map<String, Any?>>>("writes").orEmpty()
                scope.launch {
                    try {
                        write(writes)
                        result.success(null)
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
            "nutrition" -> listOf(NutritionRecord::class)
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
        BodyWaterMassRecord::class,
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
        // Kept here as a share of body weight, as a scale shows it: each
        // mass over the weighing taken with it, and left out without one.
        if (allowed(BodyWaterMassRecord::class) && allowed(WeightRecord::class)) {
            val weights = readAll(WeightRecord::class, from, to)
            rows += readAll(BodyWaterMassRecord::class, from, to).mapNotNull { water ->
                val weighing = weights
                    .minByOrNull { Duration.between(it.time, water.time).abs() }
                    ?.takeIf { Duration.between(it.time, water.time).abs() <= Duration.ofHours(1) }
                    ?: return@mapNotNull null
                row(
                    water.metadata.id,
                    water.time,
                    "bodyWater",
                    water.mass.inKilograms / weighing.weight.inKilograms * 100,
                )
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

    /** Heart rate and respiratory rate through one night, sample by sample, as
     *  [time, value] pairs keyed by measure, for the night's charts. */
    private suspend fun overnightSeries(from: Instant, to: Instant): Map<String, List<List<Double>>> {
        val granted = client.permissionController.getGrantedPermissions()
        fun allowed(type: KClass<out Record>) = HealthPermission.getReadPermission(type) in granted
        fun inWindow(time: Instant) = !time.isBefore(from) && time.isBefore(to)
        val series = mutableMapOf<String, List<List<Double>>>()
        if (allowed(HeartRateRecord::class)) {
            series["heartRate"] = readAll(HeartRateRecord::class, from, to)
                .flatMap { record -> record.samples.filter { inWindow(it.time) } }
                .sortedBy { it.time }
                .map { listOf(it.time.toEpochMilli().toDouble(), it.beatsPerMinute.toDouble()) }
        }
        if (allowed(RespiratoryRateRecord::class)) {
            series["respiratoryRate"] = readAll(RespiratoryRateRecord::class, from, to)
                .filter { inWindow(it.time) }
                .sortedBy { it.time }
                .map { listOf(it.time.toEpochMilli().toDouble(), it.rate) }
        }
        return series
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
            "nutrition" -> readAll(NutritionRecord::class, from, to).map(::foodRow)
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

    /**
     * One food entry in the app's fields and units: energy and the four
     * figures every meal has by field, the rest by `Nutrient` name.
     */
    private fun foodRow(food: NutritionRecord): Map<String, Any> {
        fun grams(mass: Mass?) = mass?.inGrams
        fun milligrams(mass: Mass?) = mass?.inGrams?.times(1_000)
        fun micrograms(mass: Mass?) = mass?.inGrams?.times(1_000_000)
        val nutrients = mapOf(
            "saturatedFat" to grams(food.saturatedFat),
            "transFat" to grams(food.transFat),
            "monounsaturatedFat" to grams(food.monounsaturatedFat),
            "polyunsaturatedFat" to grams(food.polyunsaturatedFat),
            "sugar" to grams(food.sugar),
            "sodium" to milligrams(food.sodium),
            "cholesterol" to milligrams(food.cholesterol),
            "caffeine" to milligrams(food.caffeine),
            "calcium" to milligrams(food.calcium),
            "phosphorus" to milligrams(food.phosphorus),
            "magnesium" to milligrams(food.magnesium),
            "iron" to milligrams(food.iron),
            "zinc" to milligrams(food.zinc),
            "potassium" to milligrams(food.potassium),
            "iodine" to micrograms(food.iodine),
            "selenium" to micrograms(food.selenium),
            "copper" to milligrams(food.copper),
            "manganese" to milligrams(food.manganese),
            "chromium" to micrograms(food.chromium),
            "molybdenum" to micrograms(food.molybdenum),
            "chloride" to milligrams(food.chloride),
            "vitaminA" to micrograms(food.vitaminA),
            "vitaminD" to micrograms(food.vitaminD),
            "vitaminE" to milligrams(food.vitaminE),
            "vitaminK" to micrograms(food.vitaminK),
            "vitaminC" to milligrams(food.vitaminC),
            "vitaminB1" to milligrams(food.thiamin),
            "vitaminB2" to milligrams(food.riboflavin),
            "niacin" to milligrams(food.niacin),
            "vitaminB6" to milligrams(food.vitaminB6),
            "vitaminB12" to micrograms(food.vitaminB12),
            "folate" to micrograms(food.folate),
            "pantothenicAcid" to milligrams(food.pantothenicAcid),
            "biotin" to micrograms(food.biotin),
        ).filterValues { it != null }
        val row = mutableMapOf<String, Any>(
            "id" to food.metadata.id,
            "at" to food.startTime.toEpochMilli(),
            "source" to food.metadata.dataOrigin.packageName,
            "nutrients" to nutrients,
        )
        food.name?.let { row["name"] = it }
        when (food.mealType) {
            MealType.MEAL_TYPE_BREAKFAST -> "breakfast"
            MealType.MEAL_TYPE_LUNCH -> "lunch"
            MealType.MEAL_TYPE_DINNER -> "dinner"
            MealType.MEAL_TYPE_SNACK -> "snack"
            else -> null
        }?.let { row["mealType"] = it }
        food.energy?.let { row["kcal"] = it.inKilocalories }
        grams(food.protein)?.let { row["protein"] = it }
        grams(food.totalCarbohydrate)?.let { row["carb"] = it }
        grams(food.totalFat)?.let { row["fat"] = it }
        grams(food.dietaryFiber)?.let { row["fibre"] = it }
        return row
    }

    /** What each kind writes, by the kinds the app reads. */
    private fun writePermissionsFor(kinds: List<String>): Set<String> = kinds.flatMap { kind ->
        when (kind) {
            "weight" -> listOf(WeightRecord::class)
            "body" -> bodyTypes
            "sleep" -> listOf(SleepSessionRecord::class)
            "workouts" -> listOf(ExerciseSessionRecord::class)
            "water" -> listOf(HydrationRecord::class)
            "nutrition" -> listOf(NutritionRecord::class)
            else -> emptyList()
        }
    }.map { HealthPermission.getWritePermission(it) }.toSet()

    /**
     * Stores or removes what the user logged in the app. Every record
     * carries the app's own id as its client id and the time it last
     * changed as its version, so writing it again after an edit replaces
     * it, and a deleted one is found by the same id. A type the user did
     * not allow writing, or one Health Connect has no record for (waist,
     * mood), is passed over.
     */
    private suspend fun write(writes: List<Map<String, Any?>>) {
        val granted = client.permissionController.getGrantedPermissions()
        fun canWrite(type: KClass<out Record>) = HealthPermission.getWritePermission(type) in granted
        val records = mutableListOf<Record>()
        val deletes = mutableMapOf<KClass<out Record>, MutableList<String>>()
        for (write in writes) {
            val kind = write["kind"] as? String ?: continue
            val id = write["id"] as? String ?: continue
            val version = (write["version"] as? Number)?.toLong() ?: continue
            val isDelete = write["delete"] as? Boolean ?: false
            fun time(key: String) = (write[key] as? Number)?.toLong()?.let(Instant::ofEpochMilli)
            fun number(key: String) = (write[key] as? Number)?.toDouble()
            fun offset(at: Instant) = ZoneId.systemDefault().rules.getOffset(at)
            fun remove(type: KClass<out Record>) {
                if (canWrite(type)) deletes.getOrPut(type) { mutableListOf() } += id
            }
            fun add(type: KClass<out Record>, record: () -> Record?) {
                if (canWrite(type)) record()?.let { records += it }
            }
            val metadata = Metadata.manualEntry(clientRecordId = id, clientRecordVersion = version)
            val at = time("at")
            when (kind) {
                "weight" -> if (isDelete) remove(WeightRecord::class) else add(WeightRecord::class) {
                    val kg = number("kg") ?: return@add null
                    WeightRecord(
                        time = at ?: return@add null,
                        zoneOffset = offset(at),
                        weight = Mass.kilograms(kg),
                        metadata = metadata,
                    )
                }
                "body" -> if (isDelete) {
                    bodyTypes.forEach(::remove)
                } else if (at != null) {
                    val value = number("value") ?: continue
                    when (write["metric"]) {
                        "height" -> add(HeightRecord::class) {
                            HeightRecord(at, offset(at), Length.meters(value / 100), metadata)
                        }
                        "bodyFat" -> add(BodyFatRecord::class) {
                            BodyFatRecord(at, offset(at), Percentage(value), metadata)
                        }
                        "leanMass" -> add(LeanBodyMassRecord::class) {
                            LeanBodyMassRecord(at, offset(at), Mass.kilograms(value), metadata)
                        }
                        "boneMass" -> add(BoneMassRecord::class) {
                            BoneMassRecord(at, offset(at), Mass.kilograms(value), metadata)
                        }
                        "basalMetabolicRate" -> add(BasalMetabolicRateRecord::class) {
                            BasalMetabolicRateRecord(
                                at, offset(at), Power.kilocaloriesPerDay(value), metadata,
                            )
                        }
                        // A share of weight here, a mass there: left out
                        // without the weighing it was taken with.
                        "bodyWater" -> add(BodyWaterMassRecord::class) {
                            val weight = number("weightKg") ?: return@add null
                            BodyWaterMassRecord(
                                at, offset(at), Mass.kilograms(weight * value / 100), metadata,
                            )
                        }
                    }
                }
                "sleep" -> if (isDelete) remove(SleepSessionRecord::class) else add(SleepSessionRecord::class) {
                    val start = time("start") ?: return@add null
                    val end = time("end")?.takeIf { it.isAfter(start) } ?: return@add null
                    SleepSessionRecord(
                        startTime = start,
                        startZoneOffset = offset(start),
                        endTime = end,
                        endZoneOffset = offset(end),
                        metadata = metadata,
                        // Time in bed only is the session with no stage in it.
                        stages = if (write["measure"] == "inBed") emptyList() else listOf(
                            SleepSessionRecord.Stage(start, end, SleepSessionRecord.STAGE_TYPE_SLEEPING),
                        ),
                    )
                }
                "water" -> if (isDelete) remove(HydrationRecord::class) else add(HydrationRecord::class) {
                    val ml = number("ml") ?: return@add null
                    HydrationRecord(
                        startTime = at ?: return@add null,
                        startZoneOffset = offset(at),
                        // A drink has to last a moment here.
                        endTime = at.plusSeconds(60),
                        endZoneOffset = offset(at),
                        volume = Volume.milliliters(ml),
                        metadata = metadata,
                    )
                }
                "food" -> if (isDelete) remove(NutritionRecord::class) else add(NutritionRecord::class) {
                    foodRecord(write, at ?: return@add null, offset(at), metadata)
                }
                "workout" -> if (isDelete) remove(ExerciseSessionRecord::class) else add(ExerciseSessionRecord::class) {
                    val start = time("start") ?: return@add null
                    val end = time("end")?.takeIf { it.isAfter(start) } ?: return@add null
                    ExerciseSessionRecord(
                        startTime = start,
                        startZoneOffset = offset(start),
                        endTime = end,
                        endZoneOffset = offset(end),
                        metadata = metadata,
                        exerciseType = exerciseType(write["activity"] as? String),
                        title = write["title"] as? String,
                    )
                }
            }
        }
        for ((type, ids) in deletes) {
            client.deleteRecords(type, recordIdsList = emptyList(), clientRecordIdsList = ids)
        }
        if (records.isNotEmpty()) client.insertRecords(records)
    }

    /** A meal as Health Connect keeps one, from the app's fields and units. */
    private fun foodRecord(
        write: Map<String, Any?>,
        at: Instant,
        offset: java.time.ZoneOffset,
        metadata: Metadata,
    ): NutritionRecord {
        val nutrients = write["nutrients"] as? Map<*, *> ?: emptyMap<String, Any>()
        fun amount(key: String) = (nutrients[key] as? Number)?.toDouble()
        fun grams(value: Double?) = value?.let(Mass::grams)
        fun milligrams(value: Double?) = value?.let(Mass::milligrams)
        fun micrograms(value: Double?) = value?.let(Mass::micrograms)
        fun number(key: String) = (write[key] as? Number)?.toDouble()
        return NutritionRecord(
            startTime = at,
            startZoneOffset = offset,
            endTime = at.plusSeconds(60),
            endZoneOffset = offset,
            metadata = metadata,
            name = write["name"] as? String,
            mealType = when (write["mealType"]) {
                "breakfast" -> MealType.MEAL_TYPE_BREAKFAST
                "lunch" -> MealType.MEAL_TYPE_LUNCH
                "dinner" -> MealType.MEAL_TYPE_DINNER
                "snack" -> MealType.MEAL_TYPE_SNACK
                else -> MealType.MEAL_TYPE_UNKNOWN
            },
            energy = number("kcal")?.let(Energy::kilocalories),
            protein = grams(number("protein")),
            totalCarbohydrate = grams(number("carb")),
            totalFat = grams(number("fat")),
            dietaryFiber = grams(number("fibre")),
            saturatedFat = grams(amount("saturatedFat")),
            transFat = grams(amount("transFat")),
            monounsaturatedFat = grams(amount("monounsaturatedFat")),
            polyunsaturatedFat = grams(amount("polyunsaturatedFat")),
            sugar = grams(amount("sugar")),
            sodium = milligrams(amount("sodium")),
            cholesterol = milligrams(amount("cholesterol")),
            caffeine = milligrams(amount("caffeine")),
            calcium = milligrams(amount("calcium")),
            phosphorus = milligrams(amount("phosphorus")),
            magnesium = milligrams(amount("magnesium")),
            iron = milligrams(amount("iron")),
            zinc = milligrams(amount("zinc")),
            potassium = milligrams(amount("potassium")),
            iodine = micrograms(amount("iodine")),
            selenium = micrograms(amount("selenium")),
            copper = milligrams(amount("copper")),
            manganese = milligrams(amount("manganese")),
            chromium = micrograms(amount("chromium")),
            molybdenum = micrograms(amount("molybdenum")),
            chloride = milligrams(amount("chloride")),
            vitaminA = micrograms(amount("vitaminA")),
            vitaminD = micrograms(amount("vitaminD")),
            vitaminE = milligrams(amount("vitaminE")),
            vitaminK = micrograms(amount("vitaminK")),
            vitaminC = milligrams(amount("vitaminC")),
            thiamin = milligrams(amount("vitaminB1")),
            riboflavin = milligrams(amount("vitaminB2")),
            niacin = milligrams(amount("niacin")),
            vitaminB6 = milligrams(amount("vitaminB6")),
            vitaminB12 = micrograms(amount("vitaminB12")),
            folate = micrograms(amount("folate")),
            pantothenicAcid = milligrams(amount("pantothenicAcid")),
            biotin = micrograms(amount("biotin")),
        )
    }

    /** Health Connect's type for one of the app's activity ids; the other
     *  way from [activity]. */
    private fun exerciseType(activity: String?): Int = when (activity) {
        "strength" -> ExerciseSessionRecord.EXERCISE_TYPE_STRENGTH_TRAINING
        "running" -> ExerciseSessionRecord.EXERCISE_TYPE_RUNNING
        "walking" -> ExerciseSessionRecord.EXERCISE_TYPE_WALKING
        "hiking" -> ExerciseSessionRecord.EXERCISE_TYPE_HIKING
        "cycling" -> ExerciseSessionRecord.EXERCISE_TYPE_BIKING
        "swimming" -> ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_POOL
        "rowing" -> ExerciseSessionRecord.EXERCISE_TYPE_ROWING
        "elliptical" -> ExerciseSessionRecord.EXERCISE_TYPE_ELLIPTICAL
        "stairs" -> ExerciseSessionRecord.EXERCISE_TYPE_STAIR_CLIMBING
        "basketball" -> ExerciseSessionRecord.EXERCISE_TYPE_BASKETBALL
        "badminton" -> ExerciseSessionRecord.EXERCISE_TYPE_BADMINTON
        "yoga" -> ExerciseSessionRecord.EXERCISE_TYPE_YOGA
        else -> ExerciseSessionRecord.EXERCISE_TYPE_OTHER_WORKOUT
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
            // What this app wrote is already in its own records.
            records += response.records.filter {
                it.metadata.dataOrigin.packageName != activity.packageName
            }
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
