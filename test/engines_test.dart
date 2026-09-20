import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/engines/insight_engine.dart';
import 'package:mishirube/backend/engines/nutrition_summary.dart';
import 'package:mishirube/backend/engines/substitution_engine.dart';
import 'package:mishirube/backend/engines/trend_engine.dart';
import 'package:mishirube/domain/domain.dart';

import 'support/harness.dart';

MealEvent _meal(String name, {int kcal = 600, bool isEstimated = false}) =>
    MealEvent(
      id: name,
      name: name,
      timeLabel: '12:00',
      kcal: kcal,
      qualityTag: '已確認',
      isEstimated: isEstimated,
      proteinGrams: 30,
      carbGrams: 60,
      fatGrams: 20,
      dishes: const [],
    );

BodyWeight _weight(DateTime at, double kg) =>
    BodyWeight(id: '$at', measuredAt: at, weightKg: kg);

void main() {
  final now = FakeClock().now();

  group('nutrition summary', () {
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
}
