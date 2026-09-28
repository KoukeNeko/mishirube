import '../../domain/domain.dart';
import '../health/health_source.dart';
import '../storage/activity_repository.dart';
import '../storage/database.dart';
import '../storage/health_export_query.dart';
import '../storage/journal_repository.dart';
import '../storage/meal_repository.dart';

/// The body figures a health platform has a place for; the rest (muscle,
/// visceral fat) have none on either.
const _writableBodyMetrics = {
  BodyMetric.height,
  BodyMetric.bodyFat,
  BodyMetric.leanMass,
  BodyMetric.boneMass,
  BodyMetric.basalMetabolicRate,
  BodyMetric.bodyWater,
};

/// What the user logged in the app, turned into writes for a health
/// platform: every record changed since the last write, as it is now.
class HealthExport {
  HealthExport(this._db)
    : _journal = JournalRepository(_db),
      _meals = MealRepository(_db),
      _activities = ActivityRepository(_db);

  final AppDatabase _db;
  final JournalRepository _journal;
  final MealRepository _meals;
  final ActivityRepository _activities;

  /// Each change after [since] (ms) as the writes it makes, with when it
  /// changed, oldest first. A change with no place on a platform, or
  /// nothing to say there, makes none.
  List<(List<HealthWrite>, int)> changesSince(int since) => [
    for (final change in healthChangesSince(_db, since))
      (_writesFor(change), change.updatedAt),
  ];

  List<HealthWrite> _writesFor(HealthChange change) {
    final id = change.id;
    // The version is when it last changed: every edit moves it on, so a
    // platform keeps the latest.
    final version = change.updatedAt;
    List<HealthWrite> removed(Iterable<HealthWriteKind> kinds) => [
      for (final kind in kinds)
        HealthWrite(kind: kind, id: id, version: version, isDelete: true),
    ];
    HealthWrite write(HealthWriteKind kind, Map<String, Object?> values) =>
        HealthWrite(kind: kind, id: id, version: version, values: values);
    int ms(DateTime at) => at.millisecondsSinceEpoch;

    switch (change.table) {
      case 'body_weights':
        if (change.isDeleted) return removed([HealthWriteKind.weight]);
        final weight = _journal.byId(id)! as BodyWeight;
        return [
          write(HealthWriteKind.weight, {
            'at': ms(weight.measuredAt),
            'kg': weight.weightKg,
          }),
        ];
      case 'body_measurements':
        if (change.isDeleted) return removed([HealthWriteKind.waist]);
        final waist = _journal.byId(id)! as BodyMeasurement;
        return [
          write(HealthWriteKind.waist, {
            'at': ms(waist.measuredAt),
            'cm': waist.centimetres,
          }),
        ];
      case 'body_readings':
        final metric = BodyMetric.values.asNameMap()[change.detail];
        if (!_writableBodyMetrics.contains(metric)) return const [];
        if (change.isDeleted) return removed([HealthWriteKind.body]);
        final reading = _journal.byId(id)! as BodyReading;
        return [
          write(HealthWriteKind.body, {
            'at': ms(reading.measuredAt),
            'metric': reading.metric.name,
            'value': reading.value,
            // Body water is a share of weight here and a mass on Health
            // Connect: the weighing taken with it turns one into the other.
            if (reading.metric == BodyMetric.bodyWater)
              'weightKg': _weighingNear(reading.measuredAt),
          }),
        ];
      case 'sleep_entries':
        if (change.isDeleted) return removed([HealthWriteKind.sleep]);
        final sleep = _journal.byId(id)! as SleepEntry;
        return [
          write(HealthWriteKind.sleep, {
            'start': ms(
              sleep.startedAt ?? sleep.sleptAt.subtract(sleep.duration),
            ),
            'end': ms(sleep.sleptAt),
            'measure': sleep.measure.name,
          }),
        ];
      case 'meals':
        // A deleted meal is no longer there to say whether it was water.
        if (change.isDeleted) {
          return removed([HealthWriteKind.food, HealthWriteKind.water]);
        }
        final meal = _meals.byId(id)!;
        final at = ms(_meals.eatenAtOf(id)!);
        if (meal.isWater) {
          if (meal.millilitres case final ml? when ml > 0) {
            return [
              write(HealthWriteKind.water, {'at': at, 'ml': ml}),
            ];
          }
          return const [];
        }
        final figures = {
          'kcal': meal.kcal,
          'protein': meal.proteinGrams,
          'carb': meal.carbGrams,
          'fat': meal.fatGrams,
          'fibre': meal.fibreGrams,
        }..removeWhere((_, value) => value == null);
        if (figures.isEmpty && meal.nutrients.isEmpty) return const [];
        return [
          write(HealthWriteKind.food, {
            'at': at,
            'name': meal.name,
            'mealType': ?meal.mealType?.name,
            ...figures,
            'nutrients': {
              for (final MapEntry(:key, :value) in meal.nutrients.entries)
                key.name: value,
            },
          }),
        ];
      case 'wellness_entries':
        if (change.isDeleted) return removed([HealthWriteKind.mood]);
        final mood = _journal.byId(id)! as WellnessEntry;
        return [
          write(HealthWriteKind.mood, {
            'at': ms(mood.recordedAt),
            // 1–5 as −1 to 1, the other way from moodScore.
            'valence': (mood.score - 3) / 2,
          }),
        ];
      case 'workouts':
        final span = change.isDeleted ? null : finishedWorkoutSpan(_db, id);
        if (span == null) return removed([HealthWriteKind.workout]);
        return [
          write(HealthWriteKind.workout, {
            'start': ms(span.start),
            'end': ms(span.end),
            'activity': 'strength',
            'title': span.name,
          }),
        ];
      case 'activities':
        final activity = change.isDeleted ? null : _activities.byId(id);
        if (activity == null) return removed([HealthWriteKind.workout]);
        return [
          write(HealthWriteKind.workout, {
            'start': ms(activity.startedAt),
            'end': ms(activity.startedAt.add(activity.duration)),
            'activity': activity.type.id,
          }),
        ];
      default:
        return const [];
    }
  }

  /// The weight weighed within an hour of [at], nearest first; null
  /// without one.
  double? _weighingNear(DateTime at) {
    const window = Duration(hours: 1);
    final weights = _journal.weightsBetween(
      at.subtract(window),
      at.add(window),
    );
    if (weights.isEmpty) return null;
    int apart(BodyWeight weight) =>
        weight.measuredAt.difference(at).inMilliseconds.abs();
    return (weights.toList()..sort((a, b) => apart(a).compareTo(apart(b))))
        .first
        .weightKg;
  }
}
