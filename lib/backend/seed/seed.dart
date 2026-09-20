import '../../domain/domain.dart';
import '../backend.dart';
import '../storage/database.dart';
import 'demo_content.dart';

const _seededKey = 'seeded_at';

/// Routine used for the demo's upper-body history.
const _upperBodyA = Routine(
  id: 'upper-a',
  name: '上肢 A',
  programName: '12 週肌力計畫',
  estimatedMinutes: 48,
  lastCompletedLabel: '',
  exercises: [
    PlannedExercise(
      exercise: DemoExercises.benchPress,
      sets: 4,
      reps: 5,
      targetWeightKg: 70,
      progressionLabel: '達標後 +2.5 kg',
    ),
    PlannedExercise(
      exercise: DemoExercises.barbellRow,
      sets: 3,
      reps: 8,
      targetWeightKg: 60,
      progressionLabel: '達標後 +2.5 kg',
    ),
    PlannedExercise(
      exercise: DemoExercises.overheadPress,
      sets: 3,
      reps: 6,
      targetWeightKg: 40,
      progressionLabel: '達標後 +2.5 kg',
    ),
    PlannedExercise(
      exercise: DemoExercises.latPulldown,
      sets: 3,
      reps: 10,
      targetWeightKg: 55,
      progressionLabel: '維持',
    ),
  ],
);

/// Days before the demo day on which each routine was trained. The recent
/// ones match the design's calendar; older ones repeat weekly.
final _lowerDaysAgo = [3, 7, 10, 14, 17, for (var d = 21; d <= 147; d += 7) d];
final _upperDaysAgo = [4, 8, for (var d = 24; d <= 136; d += 7) d];

/// Extra exercises logged on single days, as a real history would have.
const _oneOffs = {
  7: (DemoExercises.gobletSquat, 24.0, 12),
  14: (DemoExercises.frontSquat, 60.0, 6),
};

/// Days in the demo month with no record at all.
const _daysWithoutRecords = {7, 14};

/// Morning weights by days before the demo day.
const _weights = {
  16: 73.3,
  14: 73.2,
  11: 73.0,
  8: 72.9,
  4: 72.8,
  1: 72.6,
  0: 72.4,
};

/// Exercise outside the gym, on the days without a workout: days before
/// the demo day, the type, how long, and how far where that applies.
final _activities = [
  (1, 18, 40, ActivityTypes.cycling, 50, 18400.0),
  (2, 7, 10, ActivityTypes.running, 32, 5200.0),
  (6, 9, 0, ActivityTypes.walking, 40, 3400.0),
  (9, 7, 15, ActivityTypes.running, 28, 4600.0),
  (13, 21, 0, ActivityTypes.yoga, 30, null),
];

/// Fills an empty store with the design's demo data, dated relative to
/// [today] so the demo reads the same whenever the app is first opened.
/// Does nothing once the store has been seeded.
void seedDemoData(Backend backend, DateTime today) {
  final db = backend.db;
  if (db.setting(_seededKey) != null) return;
  final day = DateTime(today.year, today.month, today.day);
  DateTime at(int daysAgo, int hour, int minute) =>
      DateTime(day.year, day.month, day.day - daysAgo, hour, minute);

  db.transaction(() {
    for (final exercise in DemoExercises.catalog) {
      backend.storage.exercises.save(exercise, source: ChangeSource.seed);
    }
    for (final routine in [DemoRoutines.lowerBodyA, _upperBodyA]) {
      backend.storage.routines.save(
        routine,
        action: 'create',
        source: ChangeSource.seed,
      );
    }

    for (final (index, daysAgo) in _lowerDaysAgo.indexed) {
      _seedWorkout(backend, DemoRoutines.lowerBodyA, at(daysAgo, 18, 30), [
        // Each session back is 2.5 kg lighter, ending on the design's
        // "last time" values.
        (DemoExercises.backSquat, 95 - 2.5 * index, 5),
        (DemoExercises.romanianDeadlift, 77.5 - 2.5 * (index ~/ 2), 8),
        (DemoExercises.bulgarianSplitSquat, 20, 8),
        (DemoExercises.legCurl, 42.5 - 2.5 * (index ~/ 3), 12),
        (DemoExercises.standingCalfRaise, 60, 12),
        ?_oneOffs[daysAgo],
      ]);
    }
    for (final (index, daysAgo) in _upperDaysAgo.indexed) {
      _seedWorkout(backend, _upperBodyA, at(daysAgo, 18, 30), [
        (DemoExercises.benchPress, 70 - 2.5 * (index ~/ 2), 5),
        (DemoExercises.barbellRow, 60 - 2.5 * (index ~/ 3), 8),
        (DemoExercises.overheadPress, 40 - 2.5 * (index ~/ 4), 6),
        (DemoExercises.latPulldown, 55, 10),
      ]);
    }

    for (var daysAgo = today.day - 1; daysAgo >= 1; daysAgo--) {
      final date = at(daysAgo, 0, 0);
      if (_daysWithoutRecords.contains(date.day)) continue;
      if (daysAgo == 1) {
        _seedMeal(backend, _yesterdayLunch, at(1, 12, 20));
        continue;
      }
      _seedMeal(backend, _breakfast(daysAgo), at(daysAgo, 8, 5));
      _seedMeal(backend, _lunch(daysAgo), at(daysAgo, 12, 30));
      _seedMeal(backend, _dinner(daysAgo), at(daysAgo, 19, 10));
    }
    _seedMeal(backend, DemoNutrition.breakfast, at(0, 8, 10));

    for (final MapEntry(key: daysAgo, value: kg) in _weights.entries) {
      backend.storage.journal.addWeight(
        BodyWeight(
          id: 'seed-weight-$daysAgo',
          measuredAt: at(daysAgo, 7, 5 + daysAgo % 8),
          weightKg: kg,
          note: '早晨空腹 · 手動輸入',
        ),
        source: ChangeSource.seed,
      );
    }
    for (final (daysAgo, hour, minute, type, minutes, metres) in _activities) {
      backend.storage.activities.add(
        ActivitySession(
          id: 'seed-activity-$daysAgo',
          type: type,
          startedAt: at(daysAgo, hour, minute),
          duration: Duration(minutes: minutes),
          distanceMeters: metres,
        ),
        source: ChangeSource.seed,
      );
    }

    backend.storage.journal.addWellness(
      WellnessEntry(
        id: 'seed-energy-1',
        recordedAt: at(1, 22, 10),
        kind: WellnessKind.energy,
        score: 3,
        note: '久坐一整天，下背有點緊',
      ),
      source: ChangeSource.seed,
    );

    db.setSetting(_seededKey, today.toIso8601String());
  });
}

void _seedWorkout(
  Backend backend,
  Routine routine,
  DateTime startedAt,
  List<(ExerciseDefinition, double, int)> lifts,
) {
  final workout =
      WorkoutSession(
          id: 'seed-${routine.id}-${startedAt.millisecondsSinceEpoch}',
          routineId: routine.id,
          routineName: routine.name,
          startedAt: startedAt,
          exercises: [
            for (final (exercise, weight, reps) in lifts)
              ExerciseSession(
                exercise: exercise,
                sets: [
                  for (var i = 0; i < 3; i++)
                    WorkoutSet(
                      weightKg: weight,
                      reps: reps,
                      previousWeightKg: weight,
                      previousReps: reps,
                      rir: 2,
                      isDone: true,
                    ),
                ],
              ),
          ],
        )
        ..finishedAt = startedAt.add(const Duration(minutes: 55))
        ..currentExerciseIndex = lifts.length - 1;
  backend.storage.workouts.save(
    workout,
    action: 'create',
    source: ChangeSource.seed,
  );
}

void _seedMeal(Backend backend, MealEvent meal, DateTime eatenAt) {
  backend.storage.meals.insert(
    meal.copyWith(id: 'seed-${meal.id}-${eatenAt.millisecondsSinceEpoch}'),
    eatenAt: eatenAt,
    source: ChangeSource.seed,
  );
}

MealEvent _breakfast(int daysAgo) => MealEvent(
  id: 'breakfast',
  name: '早餐',
  timeLabel: '',
  kcal: 540 + daysAgo % 3 * 20,
  qualityTag: '已確認',
  proteinGrams: 27,
  carbGrams: 60,
  fatGrams: 17,
  dishes: const [
    DishEntry(name: '無糖豆漿', quantityLabel: '450 ml', subtitle: '包裝飲品 · 條碼'),
    DishEntry(name: '蛋餅', quantityLabel: '1 份', subtitle: '自訂食物'),
  ],
);

MealEvent _lunch(int daysAgo) => MealEvent(
  id: 'lunch',
  name: '午餐',
  timeLabel: '',
  kcal: 620 + daysAgo % 4 * 30,
  qualityTag: '份量為估計',
  isEstimated: true,
  proteinGrams: 38,
  carbGrams: 72,
  fatGrams: 20,
  dishes: const [
    DishEntry(name: '雞胸便當', quantityLabel: '1 個', subtitle: '份量為估計'),
  ],
);

MealEvent _dinner(int daysAgo) => MealEvent(
  id: 'dinner',
  name: '晚餐',
  timeLabel: '',
  kcal: 760 + daysAgo % 2 * 40,
  qualityTag: '已確認',
  isEstimated: true,
  proteinGrams: 42,
  carbGrams: 88,
  fatGrams: 24,
  dishes: const [
    DishEntry(name: '牛肉麵（大碗）', quantityLabel: '1 碗', subtitle: '份量為估計'),
    DishEntry(name: '燙青菜', quantityLabel: '1 份', subtitle: '自訂食物'),
  ],
);

final _yesterdayLunch = MealEvent(
  id: 'lunch',
  name: '午餐',
  timeLabel: '',
  kcal: 480,
  qualityTag: '份量為估計',
  isEstimated: true,
  proteinGrams: 30,
  carbGrams: 52,
  fatGrams: 16,
  dishes: const [DemoNutrition.sandwich],
);
