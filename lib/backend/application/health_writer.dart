import 'dart:isolate';

import '../../domain/domain.dart';
import '../health/health_source.dart';
import '../storage/activity_repository.dart';
import '../storage/activity_sample_repository.dart';
import '../storage/database.dart';
import '../storage/journal_repository.dart';
import '../storage/meal_repository.dart';
import 'health_service.dart';

/// A sleep read from a platform, as the record it becomes.
typedef PlannedSleep = ({
  String id,
  SleepEntry entry,
  List<SleepSample> samples,
});

/// What one read of a health platform brought back, ready to be written:
/// plain values, so it can be written on another isolate than the one it
/// was read on.
class HealthBatch {
  const HealthBatch({
    required this.kinds,
    required this.idPrefix,
    required this.changeSource,
    required this.sleeps,
    required this.sleepRange,
    required this.readings,
    required this.weights,
    required this.waists,
    required this.body,
    required this.workouts,
    required this.water,
    required this.foods,
    required this.moods,
    required this.activity,
  });

  final Set<HealthDataKind> kinds;

  /// What the platform's ids are prefixed with here, and how its records
  /// say they came: [HealthSource.idPrefix], [HealthSource.changeSource].
  final String idPrefix;
  final ChangeSource changeSource;

  final List<PlannedSleep> sleeps;

  /// The stretch whose sleeps this read covered in full, so a sleep the
  /// platform no longer produces inside it can be cleaned up; null when
  /// sleep was not read.
  final (DateTime, DateTime)? sleepRange;

  /// What was measured over each of [sleeps], in the same order; null
  /// when overnight readings were not read.
  final List<List<OvernightReading>>? readings;
  final List<HealthWeight> weights;
  final List<HealthWaist> waists;
  final List<HealthBodyReading> body;
  final List<HealthWorkout> workouts;

  /// Each glass as the record it becomes, and when it was drunk.
  final List<(MealEvent, DateTime)> water;

  /// Each food another app logged as the record it becomes, and when.
  final List<(MealEvent, DateTime)> foods;
  final List<WellnessEntry> moods;
  final List<ActivitySample> activity;
}

/// Writes a [HealthBatch] into the log, all or nothing. It holds only the
/// database and the repositories over it, so it can be made on whichever
/// isolate the writing happens on.
class HealthWriter {
  HealthWriter(this._db)
    : _journal = JournalRepository(_db),
      _activities = ActivityRepository(_db),
      _samples = ActivitySampleRepository(_db),
      _meals = MealRepository(_db);

  final AppDatabase _db;
  final JournalRepository _journal;
  final ActivityRepository _activities;
  final ActivitySampleRepository _samples;
  final MealRepository _meals;

  HealthImport write(HealthBatch batch) => _db.transaction(() {
    final kinds = batch.kinds;
    final source = batch.changeSource;
    final added = {for (final kind in kinds) kind: 0};
    final (nights, updated, skipped) = _importSleeps(batch);
    if (kinds.contains(HealthDataKind.sleep)) {
      added[HealthDataKind.sleep] = nights;
    }

    for (final weight in batch.weights) {
      final id = '${batch.idPrefix}-weight-${weight.id}';
      if (_db.hasRow('body_weights', id)) continue;
      _journal.addWeight(
        BodyWeight(id: id, measuredAt: weight.at, weightKg: weight.kg),
        source: source,
      );
      added.update(HealthDataKind.weight, (n) => n + 1);
    }
    for (final waist in batch.waists) {
      final id = '${batch.idPrefix}-waist-${waist.id}';
      if (_db.hasRow('body_measurements', id)) continue;
      _journal.addMeasurement(
        BodyMeasurement(
          id: id,
          measuredAt: waist.at,
          site: MeasurementSite.waist,
          centimetres: waist.cm,
        ),
        source: source,
      );
      added.update(HealthDataKind.waist, (n) => n + 1);
    }
    for (final reading in batch.body) {
      final id = '${batch.idPrefix}-body-${reading.id}';
      if (_db.hasRow('body_readings', id)) continue;
      _journal.addBodyReading(
        BodyReading(
          id: id,
          measuredAt: reading.at,
          metric: reading.metric,
          value: reading.value,
        ),
        source: source,
      );
      added.update(HealthDataKind.body, (n) => n + 1);
    }
    for (final workout in batch.workouts) {
      final id = '${batch.idPrefix}-workout-${workout.id}';
      if (_db.hasRow('activities', id) || !workout.end.isAfter(workout.start)) {
        continue;
      }
      _activities.add(
        ActivitySession(
          id: id,
          type: ActivityTypes.byId(workout.activity),
          startedAt: workout.start,
          duration: workout.end.difference(workout.start),
          distanceMeters: workout.distanceMeters,
          nativeType: workout.nativeType,
        ),
        source: source,
      );
      added.update(HealthDataKind.workouts, (n) => n + 1);
    }
    for (final (glass, at) in batch.water) {
      if (_db.hasRow('meals', glass.id)) continue;
      _meals.insert(glass, eatenAt: at, source: source);
      added.update(HealthDataKind.water, (n) => n + 1);
    }
    for (final (food, at) in batch.foods) {
      if (_db.hasRow('meals', food.id)) continue;
      _meals.insert(food, eatenAt: at, source: source);
      added.update(HealthDataKind.nutrition, (n) => n + 1);
    }
    for (final mood in batch.moods) {
      if (_db.hasRow('wellness_entries', mood.id)) continue;
      _journal.addWellness(mood, source: source);
      added.update(HealthDataKind.mood, (n) => n + 1);
    }

    if (kinds.contains(HealthDataKind.activity)) {
      added[HealthDataKind.activity] = _samples.sync(
        batch.activity,
        idPrefix: batch.idPrefix,
        source: source,
      );
    }

    return HealthImport(
      added: added,
      updated: updated,
      skipped: skipped,
      denied: null,
    );
  });

  /// Adds, updates or skips each sleep, with its stretches and what was
  /// measured over it; returns how many were added, updated and skipped.
  /// Afterwards the sleeps the platform stopped producing are removed.
  (int, int, int) _importSleeps(HealthBatch batch) {
    final source = batch.changeSource;
    var added = 0, updated = 0, skipped = 0;
    for (final (index, (:id, :entry, :samples)) in batch.sleeps.indexed) {
      final row = _journal.sleepRow(id);
      if (row != null && row.isDeleted) {
        // A night the user deleted stays deleted; one cleaned up as an
        // orphan comes back when the platform produces it again.
        if (_journal.lastDeletedBy(id) != source.name) continue;
        _journal.reviveSleep(id, source: source);
      }
      if (row != null) {
        if (!_sameFigures(row, entry)) {
          _journal.resyncSleep(entry, source: source);
          updated++;
        }
      } else {
        if (entry.kind == SleepKind.night) {
          // A night logged by hand is dated when it was logged, which
          // is usually soon after waking.
          final from = entry.sleptAt.subtract(const Duration(hours: 12));
          final to = entry.sleptAt.add(const Duration(hours: 12));
          if (_journal.hasSleepOtherThan(source, from, to)) {
            skipped++;
            continue;
          }
        }
        _journal.addSleep(entry, source: source);
        added++;
      }
      _journal.replaceSleepSegments(id, samples, source: source);
      if (batch.readings case final readings?) {
        _journal.replaceSleepReadings(id, readings[index], source: source);
      }
    }
    // An empty read proves nothing: Apple Health answers an allowance it
    // was refused with no samples, not with an error.
    if (batch.sleepRange case (final from, final to)
        when batch.sleeps.isNotEmpty) {
      _journal.removeOrphanSleeps(
        source: source,
        idPrefix: batch.idPrefix,
        from: from,
        to: to,
        producedIds: {for (final sleep in batch.sleeps) sleep.id},
      );
    }
    return (added, updated, skipped);
  }

  /// Whether the stored sleep already says what the platform now does.
  /// Kinds are compared as the data gave them, not as the user set them.
  static bool _sameFigures(
    ({
      bool isDeleted,
      SleepEntry entry,
      SleepKind derivedKind,
      String? chosenSource,
    })
    row,
    SleepEntry b,
  ) {
    final a = row.entry;
    return a.sleptAt == b.sleptAt &&
        a.duration == b.duration &&
        a.startedAt == b.startedAt &&
        row.derivedKind == b.kind &&
        a.measure == b.measure &&
        a.sourceName == b.sourceName;
  }
}

/// Writes [batch] into the store at [path] on an isolate of its own, as
/// of [at], so the isolate the screens draw on is not held up by it: a
/// month of sleep stages and hourly activity is a long transaction.
/// The screens' own connection is told of it by whoever awaits this.
Future<HealthImport> writeHealthBatchApart(
  String path,
  DateTime at,
  HealthBatch batch,
) => Isolate.run(() {
  final db = AppDatabase.connect(path, clock: () => at);
  try {
    return HealthWriter(db).write(batch);
  } finally {
    db.close();
  }
});
