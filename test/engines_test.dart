import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/engines/insight_engine.dart';
import 'package:mishirube/backend/engines/nutrition_summary.dart';
import 'package:mishirube/backend/engines/progression_engine.dart';
import 'package:mishirube/app/theme.dart';
import 'package:mishirube/backend/seed/demo_content.dart';
import 'package:mishirube/features/trends/muscle_map.dart';
import 'package:mishirube/backend/engines/streak_engine.dart';
import 'package:mishirube/backend/engines/substitution_engine.dart';
import 'package:mishirube/backend/engines/training_metrics.dart';
import 'package:mishirube/backend/engines/trend_engine.dart';
import 'package:mishirube/domain/domain.dart';

import 'support/harness.dart';

MealEvent _meal(
  String name, {
  int kcal = 600,
  bool isEstimated = false,
  int fibreGrams = 4,
}) => MealEvent(
  id: name,
  name: name,
  timeLabel: '12:00',
  kcal: kcal,
  qualityTag: '已確認',
  isEstimated: isEstimated,
  proteinGrams: 30,
  carbGrams: 60,
  fatGrams: 20,
  fibreGrams: fibreGrams,
  dishes: const [],
);

BodyWeight _weight(DateTime at, double kg) =>
    BodyWeight(id: '$at', measuredAt: at, weightKg: kg);

void main() {
  final now = FakeClock().now();

  group('nutrition summary', () {
    test('fibre adds up with the rest of the day', () {
      final summary = summariseDay([
        _meal('早餐', fibreGrams: 5),
        _meal('午餐', fibreGrams: 7),
      ]);

      expect(summary.fibreGrams, 12);
      expect(
        summary.carbGrams,
        120,
        reason: 'fibre is part of the carbohydrate, not added to it',
      );
    });

    test('adds meals up and marks a short day incomplete', () {
      final summary = summariseDay([
        _meal('早餐', kcal: 500),
        _meal('午餐', kcal: 620, isEstimated: true),
      ]);

      expect(summary.kcal, 1120);
      expect(summary.mealCount, 2);
      expect(summary.hasEstimates, isTrue);
      expect(summary.isComplete, isFalse);
      expect(isFoodLogIncomplete(summary), isTrue);
    });

    test('a day still running is never called incomplete', () {
      final summary = summariseDay([_meal('早餐')], isOver: false);

      expect(isFoodLogIncomplete(summary), isFalse);
    });

    test('a day without meals is not flagged, only empty', () {
      final summary = summariseDay(const []);

      expect(summary.hasRecords, isFalse);
      expect(isFoodLogIncomplete(summary), isFalse);
    });
  });

  group('trend engine', () {
    test('reports a weekly rate from a falling series', () {
      final trend = weightTrend(
        [
          for (var day = 28; day >= 0; day -= 7)
            _weight(now.subtract(Duration(days: day)), 73 - (28 - day) * 0.05),
        ],
        now: now,
        window: const Duration(days: 28),
      );

      expect(trend.values, hasLength(5));
      expect(trend.changePerWeek, closeTo(-0.35, 0.001));
      expect(trend.latest, closeTo(71.6, 0.001));
    });

    test('too few measurements give no trend at all', () {
      final trend = weightTrend(
        [
          _weight(now.subtract(const Duration(days: 3)), 72.5),
          _weight(now, 72.4),
        ],
        now: now,
        window: const Duration(days: 28),
      );

      expect(trend.changePerWeek, isNull);
      expect(trend.values, hasLength(2));
    });

    test('counts events into whole weeks ending with this one', () {
      final bars = weeklyCounts(
        [
          now,
          now.subtract(const Duration(days: 1)),
          now.subtract(const Duration(days: 9)),
          now.subtract(const Duration(days: 40)),
        ],
        now: now,
        weeks: 4,
      );

      expect(bars.last, ('本週', 2));
      expect(bars[2].$2, 1);
      expect(bars.first.$2, 0, reason: 'the 40-day-old event is outside');
    });

    test('sums per-day amounts into the same weeks', () {
      final bars = weeklySums(
        [
          (now, 3),
          (now.subtract(const Duration(days: 2)), 4),
          (now.subtract(const Duration(days: 8)), 5),
        ],
        now: now,
        weeks: 2,
      );

      expect(bars.map((bar) => bar.$2), [5, 7]);
    });

    test('a normal week averages the finished weeks only', () {
      const bars = [('8/24', 90), ('8/31', 120), ('9/7', 60), ('本週', 200)];

      expect(typicalWeeklyAmount(bars), 90);
      expect(
        typicalWeeklyAmount(bars.sublist(1)),
        isNull,
        reason: 'two finished weeks do not make a normal',
      );
    });
  });

  group('insight engine', () {
    test('says weight is steady when the rate is tiny', () {
      const trend = MeasurementTrend(
        values: [72.4, 72.4, 72.5, 72.4],
        days: 28,
        changePerWeek: 0.02,
      );

      final insight = weightTrendInsight(trend, dayCount: 28)!;
      expect(insight.statement, contains('大致持平'));
      expect(insight.evidence, contains('依據 4 筆體重紀錄'));
      expect(insight.evidence.last, '近 4 週');
    });

    test('names the rate and says when the data is thin', () {
      const trend = MeasurementTrend(
        values: [73.6, 73.2, 72.8, 72.4],
        days: 28,
        changePerWeek: -0.4,
      );

      final insight = weightTrendInsight(trend, dayCount: 28)!;
      expect(insight.statement, contains('每週約 0.4 公斤的速度下降'));
      expect(insight.evidence, contains('資料不完整，只有 4 / 28 天有紀錄'));
    });

    test('a volume drop is reported, a steady week is not', () {
      const sessions = 12;
      final dropped = volumeTrendInsight(
        '槓鈴深蹲',
        const [('8/24', 12), ('8/31', 11), ('9/7', 9), ('本週', 8)],
        sessionCount: sessions,
        isMaxHolding: true,
      )!;
      expect(dropped.statement, contains('從 12 組掉到 8 組'));
      expect(dropped.statement, contains('沒有跟著掉'));
      expect(dropped.evidence, contains('不含熱身組'));

      expect(
        volumeTrendInsight(
          '槓鈴深蹲',
          const [('8/24', 10), ('本週', 10)],
          sessionCount: sessions,
          isMaxHolding: true,
        ),
        isNull,
      );
    });

    test('the weekly goal insight only speaks once there is a session', () {
      expect(weeklyTrainingInsight(const [('本週', 0)], goalPerWeek: 3), isNull);
      expect(
        weeklyTrainingInsight(const [('本週', 3)], goalPerWeek: 3)!.statement,
        contains('達成'),
      );
      expect(
        weeklyTrainingInsight(const [('本週', 1)], goalPerWeek: 3)!.statement,
        contains('還差 2 次'),
      );
    });
  });

  group('substitution engine', () {
    test('ranks the same movement first and explains each candidate', () {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true);
      addTearDown(store.dispose);
      final squat = store.exercises.firstWhere((e) => e.id == 'back-squat');

      final options = store.substitutesFor(squat);

      expect(options, hasLength(3));
      expect(
        options.every(
          (option) => option.exercise.pattern == MovementPattern.squat,
        ),
        isTrue,
      );
      expect(options.first.reasons.first, '同為深蹲模式');
      expect(
        options.map((option) => option.exercise.id),
        isNot(contains('back-squat')),
      );
      final gobletSquat = options.firstWhere(
        (option) => option.exercise.id == 'goblet-squat',
      );
      expect(gobletSquat.reasons, contains('啞鈴可用'));
      expect(gobletSquat.reasons, contains('換啞鈴，重量需重新設定'));
    });

    test('a timed exercise says the tracking changes', () {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true);
      addTearDown(store.dispose);
      final plank = store.exercises.firstWhere((e) => e.id == 'plank');

      final options = substitutesFor(plank, store.exercises);

      expect(options, isNotEmpty);
      expect(options.first.reasons, contains('記錄方式改為重量 + 次數'));
    });
  });

  group('insights over the stored records', () {
    test('the overview counts training, food days and weight', () {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true);
      addTearDown(store.dispose);

      final overview = store.trends();

      expect(overview.weight.values, isNotEmpty);
      expect(overview.weight.changePerWeek, isNotNull);
      expect(overview.weeklyWorkouts, hasLength(4));
      expect(overview.foodDaysTracked, greaterThan(0));
      expect(
        overview.foodDaysComplete,
        lessThanOrEqualTo(overview.foodDaysTracked),
      );
      expect(overview.averageSleep, isNull, reason: 'no sleep source yet');
      expect(overview.insights, isNotEmpty);
    });

    test('the volume report covers the most trained exercise', () {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true);
      addTearDown(store.dispose);

      final report = store.volumeReport()!;

      expect(report.weeklySets, hasLength(4));
      expect(report.sessionCount, greaterThanOrEqualTo(4));
      expect(report.history.estimatedOneRepMaxKg, isNotNull);
    });

    test('an empty store offers no insights instead of guessing', () {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true);
      addTearDown(store.dispose);
      for (final table in [
        'workout_sets',
        'workout_exercises',
        'workouts',
        'body_weights',
        'dish_components',
        'meal_dishes',
        'meals',
      ]) {
        store.backend.db.execute('DELETE FROM $table');
      }

      final overview = store.trends();

      expect(overview.insights, isEmpty);
      expect(overview.weight.latest, isNull);
      expect(overview.foodDaysTracked, 0);
      expect(store.volumeReport(), isNull);
    });
  });

  group('journal', () {
    test('a night of sleep reaches the trends and the log', () {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true);
      addTearDown(store.dispose);
      expect(
        store.trends().averageSleep,
        isNull,
        reason: 'no nights logged yet, which is not zero sleep',
      );

      store
        ..recordSleep(const Duration(hours: 7, minutes: 30), score: 4)
        ..recordSleep(const Duration(hours: 6, minutes: 30));

      expect(store.trends().averageSleep, const Duration(hours: 7));
      final today = store.monthRecords(DateTime(2026, 9)).days.first;
      expect(today.entries.map((entry) => entry.title), contains('睡眠 7:30'));
      expect(
        today.entries.firstWhere((entry) => entry.title == '睡眠 7:30').detail,
        '品質 4 / 5',
      );
    });

    test('a weight and a check-in are stored and read back', () {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true)
        ..recordWeight(71.8, note: '早晨空腹')
        ..recordWellness(WellnessKind.energy, 4, note: '睡得好');
      addTearDown(store.dispose);

      final today = store.monthRecords(DateTime(2026, 9)).days.first;
      expect(
        today.entries.map((entry) => entry.title),
        containsAll(['體重 71.8 kg', '精力 4 / 5']),
      );
      expect(
        store.backend.storage.journal
            .weightsBetween(DateTime(2026, 9), DateTime(2026, 10))
            .last
            .note,
        '早晨空腹',
      );
    });
  });

  group('exercise search', () {
    List<String> idsFor(String query, {ExerciseFilter? filter}) {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true);
      addTearDown(store.dispose);
      return [
        for (final exercise in store.searchExercises(
          query: query,
          filter: filter ?? const ExerciseFilter(),
        ))
          exercise.id,
      ];
    }

    test('normalises case, width, spacing and punctuation', () {
      for (final query in [
        'Bench Press',
        'bench press',
        'bench-press',
        'ＢＥＮＣＨ　ＰＲＥＳＳ',
      ]) {
        expect(
          idsFor(query).first,
          'bench-press',
          reason: '「$query」should find the same exercise',
        );
      }
    });

    test('finds an exercise by its Chinese name and by an alias', () {
      expect(idsFor('臥推'), contains('bench-press'));
      expect(idsFor('RDL').first, 'rdl');
    });

    test('an exact name outranks a longer name containing it', () {
      expect(idsFor('前蹲').first, 'front-squat');
      expect(idsFor('深蹲').first, 'back-squat');
    });

    test('a typo still finds the exercise', () {
      expect(idsFor('bnech press'), contains('bench-press'));
    });

    test('an unrelated word finds nothing rather than guessing', () {
      expect(idsFor('鋼琴'), isEmpty);
    });

    test('searching by equipment or muscle works too', () {
      expect(idsFor('壺鈴'), contains('kb-swing'));
      expect(idsFor('小腿'), contains('standing-calf-raise'));
    });

    test('filters narrow the results without changing the ranking', () {
      final barbellLegs = idsFor(
        '',
        filter: const ExerciseFilter(
          muscles: {MuscleGroup.quads},
          equipment: {Equipment.barbell},
        ),
      );

      expect(barbellLegs, contains('back-squat'));
      expect(barbellLegs, isNot(contains('goblet-squat')));
    });

    test('with no query the familiar exercises come first', () {
      final all = idsFor('');

      expect(all.first, 'back-squat', reason: 'recent, favourite and frequent');
      expect(all, hasLength(greaterThan(10)));
    });

    test('a hidden exercise leaves the pickers but keeps its history', () {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true);
      addTearDown(store.dispose);
      final squat = store.exercises.firstWhere((e) => e.id == 'back-squat');

      store.toggleHidden(squat);

      expect(
        store.searchExercises().map((e) => e.id),
        isNot(contains('back-squat')),
      );
      expect(store.exerciseHistory(squat).sessionCount, greaterThan(0));
      expect(
        store.backend.storage.exercises.byId('back-squat')!.isHidden,
        isTrue,
      );
    });

    test('editing an exercise keeps its history, tracking type aside', () {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true);
      addTearDown(store.dispose);
      final squat = store.exercises.firstWhere((e) => e.id == 'back-squat');
      final sessions = store.exerciseHistory(squat).sessionCount;

      store.updateExercise(
        ExerciseDefinition(
          id: squat.id,
          name: '背蹲舉',
          equipment: squat.equipment,
          primaryMuscles: squat.primaryMuscles,
          pattern: squat.pattern,
          trackingType: squat.trackingType,
        ),
      );

      final renamed = store.exercises.firstWhere((e) => e.id == squat.id);
      expect(renamed.name, '背蹲舉');
      expect(store.exerciseHistory(renamed).sessionCount, sessions);

      // The tracking type says how the old sets are read, so it is fixed
      // once there are any.
      expect(
        () => store.updateExercise(
          ExerciseDefinition(
            id: squat.id,
            name: '背蹲舉',
            equipment: squat.equipment,
            primaryMuscles: squat.primaryMuscles,
            pattern: squat.pattern,
            trackingType: TrackingType.duration,
          ),
        ),
        throwsA(isA<TrackingChangeRefused>()),
      );
      expect(
        store.exercises.firstWhere((e) => e.id == squat.id).trackingType,
        squat.trackingType,
      );
    });

    test('an exercise with no history can change how it is tracked', () {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true);
      addTearDown(store.dispose);
      final plank = store.exercises.firstWhere((e) => e.id == 'plank');
      expect(store.exerciseHistory(plank).sessionCount, 0);

      store.updateExercise(
        ExerciseDefinition(
          id: plank.id,
          name: plank.name,
          equipment: plank.equipment,
          primaryMuscles: plank.primaryMuscles,
          pattern: plank.pattern,
          trackingType: TrackingType.reps,
        ),
      );

      expect(
        store.exercises.firstWhere((e) => e.id == plank.id).trackingType,
        TrackingType.reps,
      );
    });

    test('a personal alias is searchable and leaves the catalog alone', () {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true);
      addTearDown(store.dispose);
      final squat = store.exercises.firstWhere((e) => e.id == 'back-squat');

      store.setPersonalAliases(squat, ['大腿日主項']);

      expect(
        store.searchExercises(query: '大腿日主項').map((e) => e.id),
        contains('back-squat'),
      );
      final stored = store.exercises.firstWhere((e) => e.id == 'back-squat');
      expect(stored.personalAliases, ['大腿日主項']);
      expect(
        stored.aliases,
        squat.aliases,
        reason: 'the catalog keeps its own names',
      );
    });

    test('duplicate candidates warn before a second history starts', () {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true);
      addTearDown(store.dispose);

      expect(
        store.duplicateCandidatesFor('DB Bench Press').map((e) => e.id),
        contains('db-bench'),
      );
      // Two catalog entries carry this alias; both are offered before a
      // third one is created.
      expect(
        store.duplicateCandidatesFor('啞鈴臥推').map((e) => e.id),
        containsAll(['db-bench', 'db-bench-custom']),
      );
    });
  });

  group('discarding a workout', () {
    test('it stops counting as training but stays in the audit trail', () {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true)
        ..startWorkout()
        ..completeNextSet();
      addTearDown(store.dispose);
      final id = store.activeWorkout!.id;
      final before = store.trends().workoutsThisWeek;

      store.discardWorkout();

      expect(store.activeWorkout, isNull);
      expect(store.trends().workoutsThisWeek, before);
      expect(
        store.backend.storage.workouts.byId(id, (id) => store.exercises.first),
        isNotNull,
        reason: 'the workout is kept, not deleted',
      );
      expect(
        store.backend.db
            .select(
              'SELECT action FROM audit_events WHERE entity_id = ? '
              'ORDER BY id',
              [id],
            )
            .map((row) => row['action']),
        ['start', 'complete_set', 'discard'],
      );
      // A new workout can start right away.
      store.startWorkout();
      expect(store.activeWorkout, isNotNull);
    });
  });

  group('added sets', () {
    test('plate rounding never suggests a weight a bar cannot hold', () {
      expect(roundToPlate(61.3), 60);
      expect(roundToPlate(60), 60);
      expect(roundToPlate(1), plateStepKg, reason: 'never below one step');
      expect(startingWeight(100, SetType.warmup), 60);
      expect(startingWeight(100, SetType.drop), 80);
      expect(startingWeight(100, SetType.failure), 100);
    });

    test('a warm-up set is logged but counts as no training volume', () {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true)
        ..startWorkout();
      addTearDown(store.dispose);
      final workout = store.activeWorkout!;
      final working = workout.currentExercise.sets.first.weightKg;

      final warmup = store.addSet(SetType.warmup)!;
      store
        ..toggleSet(workout.currentExercise.sets.length - 1)
        ..completeNextSet();

      expect(warmup.weightKg, startingWeight(working, SetType.warmup));
      expect(warmup.type, SetType.warmup);
      expect(volumeKg(workout.currentExercise.sets), working * 5);
      expect(
        store.backend.storage.workouts
            .byId(workout.id, (id) => store.exercises.first)!
            .currentExercise
            .sets
            .last
            .type,
        SetType.warmup,
        reason: 'the set type survives a restart',
      );
    });
  });

  group('progression engine', () {
    final plan = PlannedExercise(
      exercise: DemoExercises.backSquat,
      sets: 3,
      reps: 5,
      targetWeightKg: 90,
      progressionLabel: '維持',
      rir: 2,
    );
    var day = DateTime(2026, 9, 18);
    ExerciseAttempt attempt({
      required int reps,
      int sets = 3,
      double weightKg = 90,
      int? rir = 2,
    }) {
      day = day.subtract(const Duration(days: 3));
      return ExerciseAttempt(
        date: day,
        weightKg: weightKg,
        reps: reps,
        workingSets: sets,
        rir: rir,
      );
    }

    test('nothing to go on means nothing is said', () {
      expect(suggestProgression(planned: plan, recent: const []), isNull);
    });

    test('meeting the plan with something in reserve adds a step', () {
      final suggestion = suggestProgression(
        planned: plan,
        recent: [attempt(reps: 5)],
      )!;

      expect(suggestion.move, ProgressionMove.increase);
      expect(suggestion.targetWeightKg, 92.5);
      expect(suggestion.reason, contains('可以加'));
    });

    test('meeting it at the limit repeats the weight', () {
      final suggestion = suggestProgression(
        planned: plan,
        recent: [attempt(reps: 5, rir: 0)],
      )!;

      expect(suggestion.move, ProgressionMove.hold);
      expect(suggestion.targetWeightKg, 90);
    });

    test('fewer sets is not a reason to take weight off', () {
      final suggestion = suggestProgression(
        planned: plan,
        recent: [attempt(reps: 5, sets: 2), attempt(reps: 5, sets: 2)],
      )!;

      expect(suggestion.move, ProgressionMove.hold);
      expect(suggestion.targetWeightKg, 90);
      expect(suggestion.reason, contains('3 組'));
    });

    test('missing the reps twice running takes weight off', () {
      final suggestion = suggestProgression(
        planned: plan,
        recent: [attempt(reps: 3), attempt(reps: 4)],
      )!;

      expect(suggestion.move, ProgressionMove.deload);
      expect(suggestion.targetWeightKg, 80, reason: '90 × 0.9, to a plate');
    });

    test('one bad day is only a bad day', () {
      final suggestion = suggestProgression(
        planned: plan,
        recent: [attempt(reps: 3), attempt(reps: 5)],
      )!;

      expect(suggestion.move, ProgressionMove.hold);
    });
  });

  group('muscle load', () {
    ExerciseDefinition of(String id, List<MuscleGroup> primary) =>
        ExerciseDefinition(
          id: id,
          name: id,
          equipment: Equipment.barbell,
          primaryMuscles: primary,
          secondaryMuscles: const [MuscleGroup.core],
          pattern: MovementPattern.squat,
          trackingType: TrackingType.weightReps,
        );

    test('a set counts for each primary muscle, not the secondary ones', () {
      final load = setsByMuscle([
        (of('squat', [MuscleGroup.quads, MuscleGroup.glutes]), 6),
        (of('curl', [MuscleGroup.arms]), 4),
      ]);

      expect(load, [
        (MuscleGroup.quads, 6),
        (MuscleGroup.glutes, 6),
        (MuscleGroup.arms, 4),
      ]);
      expect(
        load.map((entry) => entry.$1),
        isNot(contains(MuscleGroup.core)),
        reason: 'assisting is not the same as being trained',
      );
    });

    test('the weekly rate drops muscles that round to nothing', () {
      final weekly = weeklySetsByMuscle([
        (of('squat', [MuscleGroup.quads]), 24),
        (of('calf', [MuscleGroup.calves]), 1),
      ], weeks: 4);

      expect(weekly, [(MuscleGroup.quads, 6)]);
    });
  });

  group('muscle map shading', () {
    test('nothing logged is not a small amount of work', () {
      // A resting muscle is its own neutral, distinct from the lightest
      // shade the scale can produce for actual training.
      expect(muscleShade(0), muscleShade(-1));
      expect(
        muscleShade(0).computeLuminance(),
        lessThan(muscleShade(1).computeLuminance()),
      );
    });

    test('more sets read lighter, up to a fixed top of scale', () {
      final light = muscleShade(muscleMapTopOfScale);
      expect(
        muscleShade(1).computeLuminance(),
        lessThan(muscleShade(muscleMapTopOfScale ~/ 2).computeLuminance()),
      );
      expect(
        muscleShade(muscleMapTopOfScale * 3),
        light,
        reason: 'the scale is fixed, so two weeks can be compared',
      );
    });
  });

  group('streak engine', () {
    // A Sunday, so the week in progress is nearly over.
    final now = DateTime(2026, 9, 20, 10);
    final monday = startOfWeek(now);
    DateTime day(int offsetFromMonday) =>
        monday.add(Duration(days: offsetFromMonday));

    List<WeeklyGoal> goalOf(int days) => [
      WeeklyGoal(id: 'goal', effectiveFrom: DateTime(2026), targetDays: days),
    ];

    List<WeekProgress> weeksOf(
      Set<DateTime> days, {
      List<WeeklyGoal>? goals,
      List<GoalPause> pauses = const [],
      int weeks = 4,
    }) => weekProgress(
      activeDays: days,
      goals: goals ?? goalOf(3),
      pauses: pauses,
      now: now,
      weeks: weeks,
    );

    test('a day counts once however much was done in it', () {
      final days = activeDays([
        day(0).add(const Duration(hours: 7)),
        day(0).add(const Duration(hours: 18)),
        day(0).add(const Duration(hours: 21)),
        day(2).add(const Duration(hours: 8)),
      ]);

      expect(days, hasLength(2));
      expect(weeksOf(days).last.activeDays, 2);
    });

    test('meeting the goal counts the week straight away', () {
      final weeks = weeksOf(activeDays([day(0), day(1), day(2)]));

      expect(weeks.last.isMet, isTrue);
      expect(streak(weeks).current, 1);
      expect(streak(weeks).isThisWeekPending, isFalse);
    });

    test('a week still running is pending, not broken', () {
      final weeks = weeksOf(
        activeDays([
          // Three met weeks, then two days so far this week.
          for (var w = 1; w <= 3; w++)
            for (var d = 0; d < 3; d++) day(d - w * 7),
          day(0),
          day(1),
        ]),
      );

      final run = streak(weeks);
      expect(weeks.last.isMet, isFalse);
      expect(weeks.last.isMissed, isFalse, reason: 'the week is not over');
      expect(run.current, 3, reason: 'the run stands until the week ends');
      expect(run.isThisWeekPending, isTrue);
    });

    test('a finished week that fell short ends the run', () {
      final weeks = weeksOf(
        activeDays([
          for (var d = 0; d < 3; d++) day(d - 21),
          // Last week: one day only.
          day(-7),
          for (var d = 0; d < 3; d++) day(d),
        ]),
      );

      final run = streak(weeks);
      expect(run.current, 1, reason: 'only this week');
      expect(run.previous, 1, reason: 'what there is to get back to');
      expect(run.best, 1);
    });

    test('a paused week neither extends nor breaks the run', () {
      final pauses = [
        GoalPause(id: 'ill', startedAt: day(-7), endedAt: day(-1)),
      ];
      final weeks = weeksOf(
        activeDays([
          for (var d = 0; d < 3; d++) day(d - 14),
          for (var d = 0; d < 3; d++) day(d),
        ]),
        pauses: pauses,
      );

      expect(weeks[weeks.length - 2].isPaused, isTrue);
      expect(weeks[weeks.length - 2].isMissed, isFalse);
      expect(streak(weeks).current, 2, reason: 'the two met weeks join up');
    });

    test('each week is judged by the goal in force then', () {
      final goals = [
        WeeklyGoal(id: 'old', effectiveFrom: DateTime(2026), targetDays: 2),
        WeeklyGoal(id: 'new', effectiveFrom: monday, targetDays: 5),
      ];
      final weeks = weeksOf(
        activeDays([
          for (var d = 0; d < 2; d++) day(d - 7),
          for (var d = 0; d < 2; d++) day(d),
        ]),
        goals: goals,
      );

      expect(weeks[weeks.length - 2].targetDays, 2);
      expect(
        weeks[weeks.length - 2].isMet,
        isTrue,
        reason: 'raising the goal does not rewrite last week',
      );
      expect(weeks.last.targetDays, 5);
      expect(weeks.last.isMet, isFalse);
    });
  });
}
