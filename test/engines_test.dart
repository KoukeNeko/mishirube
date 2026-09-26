import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/engines/activity_metrics.dart';
import 'package:mishirube/backend/engines/insight_engine.dart';
import 'package:mishirube/backend/engines/trend_findings.dart';
import 'package:mishirube/backend/engines/caffeine.dart';
import 'package:mishirube/backend/engines/meal_type_suggestion.dart';
import 'package:mishirube/backend/engines/nutrition_summary.dart';
import 'package:mishirube/backend/engines/nutrition_targets.dart';
import 'package:mishirube/backend/engines/progression_engine.dart';
import 'package:mishirube/backend/seed/demo_content.dart';
import 'package:mishirube/backend/engines/food_portion.dart';
import 'package:mishirube/features/nutrition/plate_screen.dart';
import 'package:mishirube/features/trends/muscle_map.dart';
import 'package:mishirube/backend/engines/streak_engine.dart';
import 'package:mishirube/backend/engines/substitution_engine.dart';
import 'package:mishirube/backend/engines/training_metrics.dart';
import 'package:mishirube/backend/engines/trend_detail.dart';
import 'package:mishirube/backend/engines/trend_engine.dart';
import 'package:mishirube/backend/engines/trend_insights.dart';
import 'package:mishirube/backend/engines/workout_review.dart';
import 'package:mishirube/backend/engines/workout_text.dart';
import 'package:mishirube/backend/engines/exercise_search.dart';
import 'package:mishirube/backend/seed/exercise_catalogue.dart';
import 'package:mishirube/domain/domain.dart';

import 'support/chat_workout.dart';
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

    test('a missing macro is counted, not added as zero', () {
      final summary = summariseDay([
        _meal('早餐'),
        // A packet that printed energy and nothing else.
        MealEvent(
          id: 'bar',
          name: '能量棒',
          timeLabel: '15:00',
          kcal: 200,
          qualityTag: '已確認',
          dishes: const [],
        ),
      ]);

      expect(summary.proteinGrams, 30, reason: 'the sum of what is known');
      expect(
        summary.mealsWithoutProtein,
        1,
        reason:
            'and how much of the day it could not see — 30 g alone '
            'would read as the day, when it is only a floor',
      );
      expect(summary.mealsWithoutCarb, 1);
      expect(summary.mealsWithoutFat, 1);
      expect(summary.mealsWithoutFibre, 1);
      expect(summary.mealsWithoutFigures, 0, reason: 'energy was printed');
      expect(summary.recordCount, 2);
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

  group('activity metrics', () {
    ActivitySample sample(
      ActivityMetric metric,
      DateTime start,
      double value,
    ) => ActivitySample(
      metric: metric,
      start: start,
      end: start.add(const Duration(hours: 1)),
      value: value,
    );

    test('a counted day adds its hours; a measured one averages', () {
      final day = DateTime(2026, 9, 20);
      expect(
        dailyValues([
          sample(ActivityMetric.steps, day.add(const Duration(hours: 8)), 400),
          sample(ActivityMetric.steps, day.add(const Duration(hours: 23)), 100),
          sample(
            ActivityMetric.steps,
            day.add(const Duration(days: 1, hours: 7)),
            250,
          ),
        ]),
        [(day, 500.0), (DateTime(2026, 9, 21), 250.0)],
      );
      expect(
        dailyValues([
          sample(ActivityMetric.restingHeartRate, day, 58),
          sample(
            ActivityMetric.restingHeartRate,
            day.add(const Duration(hours: 12)),
            62,
          ),
        ]),
        [(day, 60.0)],
      );
    });

    test('a day with no reading is left out, not counted as zero', () {
      final values = dailyValues([
        sample(ActivityMetric.steps, DateTime(2026, 9, 18, 9), 3000),
        sample(ActivityMetric.steps, DateTime(2026, 9, 20, 9), 5000),
      ]);
      expect([for (final (day, _) in values) day.day], [18, 20]);
    });

    test('a usual range needs two weeks of days', () {
      final days = [
        for (var i = 0; i < 20; i++)
          (DateTime(2026, 9, 1 + i), 5000.0 + i * 100),
      ];
      expect(usualRangeOf(days.take(13).toList()), isNull);
      expect(usualRangeOf(days), (low: 5500.0, high: 6400.0));
    });
  });

  group('trend findings', () {
    final today = DateTime(2026, 9, 19, 20);

    /// [value] on each of [days] days ending [endingDaysAgo] before today.
    List<(DateTime, double)> daily(
      int days,
      double value, {
      int endingDaysAgo = 0,
    }) => [
      for (var i = 0; i < days; i++)
        (
          DateTime(today.year, today.month, today.day - endingDaysAgo - i, 7),
          value,
        ),
    ];

    test('training weeks start at the first workout, not at zero', () {
      final line = trainingLine([
        DateTime(today.year, today.month, today.day - 3),
        DateTime(today.year, today.month, today.day - 10),
      ], today)!;
      expect(line.weekly.first, greaterThan(0));
      expect(line.weekly.length, lessThanOrEqualTo(3));
    });

    test('sleep is set against twelve weeks once there are that many', () {
      final nights = [...daily(28, 450), ...daily(84, 410, endingDaysAgo: 28)];
      expect(sleepLine(nights, today)!.change, '比前 12 週多 40 分');
      expect(
        sleepLine([
          ...daily(20, 450),
          ...daily(20, 410, endingDaysAgo: 28),
        ], today)!.change,
        '比前 4 週多 40 分',
        reason: 'too few nights for twelve weeks: the four before stand in',
      );
    });

    test('steps are set against the year once there is half a year', () {
      final year = [
        ...daily(90, 11000),
        ...daily(275, 9000, endingDaysAgo: 90),
      ];
      expect(activityLine(year, today)!.value, '每天 11,000 步');
      expect(activityLine(year, today)!.change, startsWith('近 90 天比過去一年多'));
    });

    test('a relation needs five workouts on each side of the median', () {
      final nights = <DateTime, double>{};
      final workouts = <(DateTime, String, double)>[];
      for (var i = 0; i < 12; i++) {
        final day = DateTime(2026, 9, 1 + i);
        final isLong = i.isEven;
        nights[day] = isLong ? 480 : 360;
        workouts.add((
          day.add(const Duration(hours: 18)),
          '下肢 A',
          isLong ? 5500 : 4500,
        ));
      }
      final relation = sleepAndTrainingInsight(nights, workouts)!;
      expect(relation.statement, '前一晚睡得較久的訓練，訓練量平均多 20%。');
      expect(relation.evidence, contains('關聯，不代表因果'));
      expect(
        sleepAndTrainingInsight(nights, workouts.take(8).toList()),
        isNull,
        reason: 'four a side',
      );
    });
  });

  group('trend insights', () {
    // A Saturday evening.
    final today = DateTime(2026, 9, 19, 20);
    DateTime day(int ago, [int hour = 12]) =>
        DateTime(today.year, today.month, today.day - ago, hour);

    test('energy burned is worked out from intake and the weight trend', () {
      final food = [for (var i = 1; i <= 20; i++) (day(i), 2000.0)];
      // 0.05 kg lost a day: 0.35 kg a week.
      final weights = [
        for (var i = 0; i < 21; i++) (day(20 - i, 7), 80 - 0.05 * i),
      ];
      final energy = energyBalance(
        completeDays: food,
        trendWeights: weights,
        today: today,
      )!;
      expect(energy.intake, 2000);
      expect(energy.expenditure, 2385, reason: '2000 + 0.05 × 7700');
      expect(energy.balance, -385);
      expect(energy.weeklyChangeKg, closeTo(-0.35, 0.001));
      expect(energy.forecastKg, closeTo(79 - 0.05 * 56, 0.01));
      expect(energy.isIntakeLikelyUnderlogged, isFalse);

      expect(
        energyBalance(
          completeDays: food,
          trendWeights: weights,
          today: today,
          basalKcal: 2500,
        )!.isIntakeLikelyUnderlogged,
        isTrue,
        reason: 'burning less than at rest means food went unrecorded',
      );
      expect(
        energyBalance(
          completeDays: food.take(10).toList(),
          trendWeights: weights,
          today: today,
        ),
        isNull,
        reason: 'ten food days',
      );
    });

    test('weekends that eat more take back part of the deficit', () {
      final food = [
        for (var i = 0; i < 28; i++)
          if (day(i).weekday >= DateTime.saturday)
            (day(i), 2600.0)
          else
            (day(i), 2000.0),
      ];
      final gap = weekendIntake(food, today)!;
      expect(gap.difference, 600);
      const energy = EnergyBalance(
        expenditure: 2400,
        intake: 2170,
        weeklyChangeKg: 0,
        weightKg: 80,
        forecastKg: 80,
        foodDays: 21,
        weighings: 21,
        isIntakeLikelyUnderlogged: false,
      );
      // Weekends add 2 × 600 against a weekday deficit of 5 × 400.
      expect(weekendOffset(energy, gap), closeTo(0.6, 0.001));
      expect(
        weekendIntake([for (var i = 0; i < 28; i++) (day(i), 2000.0)], today),
        isNull,
      );
    });

    test('waking later at weekends is said from 45 minutes', () {
      final woke = [
        for (var i = 0; i < 28; i++)
          day(i).weekday >= DateTime.saturday
              ? DateTime(today.year, today.month, today.day - i, 9)
              : DateTime(today.year, today.month, today.day - i, 7, 20),
      ];
      final gap = weekendWake(woke, today)!;
      expect(gap.difference, 100);
      expect(
        weekendWake([for (var i = 0; i < 28; i++) day(i, 7)], today),
        isNull,
      );
    });

    test('protein is judged per kilogram, trained days apart', () {
      final grams = [
        for (var i = 1; i <= 20; i++) (day(i), i.isEven ? 120.0 : 60.0),
      ];
      final protein = proteinIntake(
        completeDayGrams: grams,
        weightKg: 75,
        trainingDays: {
          for (var i = 2; i <= 20; i += 2)
            DateTime(today.year, today.month, today.day - i),
        },
        today: today,
      )!;
      expect(protein.perKg, closeTo(1.2, 0.001));
      expect(protein.shortGrams, 30, reason: '(1.6 − 1.2) × 75');
      expect(protein.trainingDayPerKg, closeTo(1.6, 0.001));
      expect(protein.restDayPerKg, closeTo(0.8, 0.001));
    });

    test('muscles short of ten sets and lopsided pairs are named', () {
      final balance = trainingBalance([
        (MuscleGroup.chest, 18),
        (MuscleGroup.quads, 12),
        (MuscleGroup.lats, 6),
        (MuscleGroup.hamstrings, 4),
      ], 8)!;
      expect(balance.short.first, (MuscleGroup.hamstrings, 4));
      expect(balance.enough.map((entry) => entry.$1), [
        MuscleGroup.chest,
        MuscleGroup.quads,
      ]);
      expect(balance.imbalances.map((entry) => entry.$1), [
        MusclePair.pushPull,
        MusclePair.quadsHamstrings,
      ]);
      expect(trainingBalance(const [(MuscleGroup.chest, 12)], 2), isNull);
    });
  });

  group('trend detail', () {
    // A Saturday.
    final today = DateTime(2026, 9, 19, 20);
    DateTime day(int ago) =>
        DateTime(today.year, today.month, today.day - ago, 8);

    test('weeks are averaged, gaps stay gaps, and the levels are placed', () {
      final daily = [
        for (var ago = 0; ago < 16 * 7; ago++)
          if (ago ~/ 7 != 6) (day(ago), ago < 28 ? 480.0 : 420.0),
      ];
      final detail = trendDetail(
        daily,
        today,
        weeks: 16,
        aggregate: WeekAggregate.mean,
      );
      expect(detail.values, hasLength(16));
      expect(detail.values.last, 480);
      expect(detail.values[16 - 1 - 6], isNull, reason: 'a week not logged');
      expect(detail.recent!.value, 480);
      expect((detail.recent!.fromWeek, detail.recent!.toWeek), (12, 15));
      expect(detail.baseline!.value, 420);
      expect((detail.baseline!.fromWeek, detail.baseline!.toWeek), (0, 11));
      expect(detail.normal, isNotNull);
      expect(detail.daysWithRecords.last, 7);
    });

    test('a count is zero in a quiet week once counting began', () {
      final starts = [(day(0), 1.0), (day(2), 1.0), (day(20), 1.0)];
      final detail = trendDetail(
        starts,
        today,
        weeks: 6,
        aggregate: WeekAggregate.sum,
      );
      expect(detail.values, [null, null, null, 1, 0, 2]);
      expect(detail.normal, isNull, reason: 'too few weeks');
      final saturday = today.weekday - 1;
      expect(
        detail.weekdays[saturday],
        closeTo(1 / 3, 0.001),
        reason: 'one Saturday in the three weeks since the first',
      );
    });
  });

  group('workout text', () {
    test('a list from a chat reads into exercises and their sets', () {
      final lines = parseWorkoutText('''
今天的課表：
1. 槓鈴深蹲 4×8 60kg
- 臥推：3 組 10 下 40 公斤
• Pull-up 3x8
（4）平板支撐
休息 90 秒
''');
      expect(
        [for (final line in lines) line.name],
        ['槓鈴深蹲', '臥推', 'Pull-up', '平板支撐', '休息'],
      );
      final squat = lines[0];
      expect((squat.sets, squat.reps, squat.weightKg), (4, 8, 60.0));
      final bench = lines[1];
      expect((bench.sets, bench.reps, bench.weightKg), (3, 10, 40.0));
      expect((lines[2].sets, lines[2].reps, lines[2].weightKg), (3, 8, null));
      expect(lines[3].sets, isNull, reason: 'no figures given');
    });

    test('a table from a chat reads row by row, the talk around it not', () {
      final lines = parseWorkoutText(chatWorkout);
      expect(
        [for (final line in lines) line.name],
        ['順序', '啞鈴划船', '單手啞鈴划船', '啞鈴二頭彎舉', '錘式彎舉', '腕彎舉', '反向腕彎舉', '棒式'],
        reason: 'the heading row is dropped later, matching nothing',
      );
      final figures = [
        for (final line in lines.skip(1)) (line.sets, line.reps, line.weightKg),
      ];
      expect(figures, [
        (3, 10, 12.0),
        (3, 8, 29.0),
        (3, 10, 8.5),
        (2, 8, 8.5),
        (2, 12, 7.5),
        (2, 15, 2.5),
        (2, null, null),
      ], reason: 'a range is read at its low end; a hold has no reps');
      expect(
        parseWorkoutText(chatWorkout.replaceAll('    ', '\t')).length,
        lines.length,
        reason: 'tabs read as the spaces do',
      );
    });

    test('a shared log reads each exercise with its own sets', () {
      final lines = parseWorkoutText(sharedWorkoutLog);
      final exercises = [
        for (final line in lines)
          if (line.loads.isNotEmpty) line,
      ];
      expect(
        [for (final line in exercises) line.name],
        ['啞鈴划船', '單臂啞鈴划船', '啞鈴二頭肌彎舉', '啞鈴槌式彎舉', '啞鈴腕彎舉', '反向啞鈴腕彎舉'],
      );
      expect(exercises[3].loads, [
        (weightKg: 9.0, reps: 10),
        (weightKg: 9.0, reps: 10),
        (weightKg: 9.0, reps: 7),
      ]);
      expect(exercises[4].loads.first, (weightKg: 7.5, reps: 12));
      expect(
        [
          for (final line in lines)
            if (line.loads.isEmpty) line.sets,
        ],
        everyElement(isNull),
        reason: 'the date and sign-off lines give no figures to keep',
      );
    });

    test('names as a chat writes them find the library\'s exercises', () {
      final library = parseExerciseCatalogue(
        jsonDecode(File(exerciseCatalogueFile).readAsStringSync())
            as Map<String, dynamic>,
      );
      expect(
        [
          for (final line in parseWorkoutText(chatWorkout))
            closestExercise([line.name], library)?.name,
        ],
        [null, '俯身啞鈴划船', '單臂啞鈴划船', '啞鈴彎舉', '錘式彎舉', '腕彎舉', '反向腕彎舉', '棒式'],
      );
      expect(
        [
          for (final line in parseWorkoutText(sharedWorkoutLog))
            if (line.loads.isNotEmpty)
              closestExercise([line.name], library)?.name,
        ],
        ['俯身啞鈴划船', '單臂啞鈴划船', '啞鈴彎舉', '錘式彎舉', '腕彎舉', '反向腕彎舉'],
        reason: 'the names Taiwanese apps use, 槌 for 錘 included',
      );
    });
  });

  group('water', () {
    MealEvent drink(String name, int millilitres, {String tag = '已確認'}) =>
        MealEvent(
          id: '$name$millilitres',
          name: name,
          timeLabel: '10:00',
          qualityTag: tag,
          dishes: const [],
          kind: ConsumptionKind.beverage,
          millilitres: millilitres,
        );

    test('only the water shortcut counts as water', () {
      final water = summariseWater([
        drink('水', 250, tag: waterQualityTag),
        drink('拿鐵', 350),
        // A saved food someone called 水 comes through a portion.
        drink('水', 500).copyWith(
          dishes: const [
            DishEntry(name: '水', quantityLabel: '500 ml', subtitle: '自訂食物'),
          ],
        ),
        drink('水', 300, tag: waterQualityTag),
      ]);

      expect(water.millilitres, 550);
      expect(water.times, 2);
      expect(water.lastTimeLabel, '10:00');
    });

    test('no water is none, not an empty number pretending', () {
      final water = summariseWater([drink('拿鐵', 350)]);

      expect(water.millilitres, 0);
      expect(water.lastTimeLabel, isNull);
    });
  });

  group('meal type suggestion', () {
    DateTime at(int hour, [int minute = 0]) =>
        DateTime(2026, 9, 19, hour, minute);

    test('says nothing until the user has shown a habit', () {
      expect(
        suggestMealType(const [], at(12)),
        isNull,
        reason:
            'no rule of thumb from the clock: noon is not lunch for '
            'everybody',
      );
      expect(
        suggestMealType([(at(12, 10), MealType.lunch)], at(12)),
        isNull,
        reason: 'once is not a habit',
      );
    });

    test('offers what the user usually calls this hour', () {
      final history = [
        (at(15, 0), MealType.lunch),
        (at(15, 40), MealType.lunch),
        (at(8, 0), MealType.breakfast),
      ];

      expect(
        suggestMealType(history, at(15, 20)),
        MealType.lunch,
        reason: 'somebody who eats lunch at three gets lunch at three',
      );
      expect(suggestMealType(history, at(19)), isNull);
    });

    test('a tie is a guess, so it is not offered', () {
      final history = [
        (at(10), MealType.breakfast),
        (at(10, 30), MealType.breakfast),
        (at(10, 10), MealType.snack),
        (at(10, 20), MealType.snack),
      ];

      expect(suggestMealType(history, at(10, 15)), isNull);
    });

    test('a night-shift meal either side of midnight is one habit', () {
      final history = [
        (at(23, 40), MealType.dinner),
        (at(0, 20), MealType.dinner),
      ];

      expect(suggestMealType(history, at(0, 5)), MealType.dinner);
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
      expect(insight.statement, contains('每週約 0.4 kg 的速度下降'));
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

      final overview = store.backend.insights.trends();

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

      final report = store.backend.insights.volumeReport()!;

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

      final overview = store.backend.insights.trends();

      expect(overview.insights, isEmpty);
      expect(overview.weight.latest, isNull);
      expect(overview.foodDaysTracked, 0);
      expect(store.backend.insights.volumeReport(), isNull);
    });
  });

  group('journal', () {
    test('a night of sleep reaches the trends and the log', () {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true);
      addTearDown(store.dispose);
      expect(
        store.backend.insights.trends().averageSleep,
        isNull,
        reason: 'no nights logged yet, which is not zero sleep',
      );

      store
        ..backend.journal.recordSleep(
          const Duration(hours: 7, minutes: 30),
          score: 4,
        )
        ..backend.journal.recordSleep(const Duration(hours: 6, minutes: 30));

      expect(
        store.backend.insights.trends().averageSleep,
        const Duration(hours: 7),
      );
      final today = store.backend.timeline.month(DateTime(2026, 9)).days.first;
      expect(today.entries.map((entry) => entry.title), contains('睡眠 7:30'));
      expect(
        today.entries.firstWhere((entry) => entry.title == '睡眠 7:30').detail,
        '品質 4 / 5',
      );
    });

    test('a weight and a check-in are stored and read back', () {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true)
        ..backend.journal.recordWeight(71.8, note: '早晨空腹')
        ..backend.journal.recordWellness(WellnessKind.energy, 4, note: '睡得好');
      addTearDown(store.dispose);

      final today = store.backend.timeline.month(DateTime(2026, 9)).days.first;
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
      final before = store.backend.insights.trends().workoutsThisWeek;

      store.discardWorkout();

      expect(store.activeWorkout, isNull);
      expect(store.backend.insights.trends().workoutsThisWeek, before);
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
      expect(
        workout.currentExercise.sets.first,
        warmup,
        reason: 'a warm-up comes before the work it prepares for',
      );
      store
        ..completeNextSet()
        ..completeNextSet();

      expect(warmup.weightKg, startingWeight(working, SetType.warmup));
      expect(warmup.type, SetType.warmup);
      expect(volumeKg(workout.currentExercise.sets), working * 5);
      expect(
        store.backend.storage.workouts
            .byId(workout.id, (id) => store.exercises.first)!
            .currentExercise
            .sets
            .first
            .type,
        SetType.warmup,
        reason: 'the set type survives a restart',
      );
    });

    test('a warm-up ramp climbs to the working weight in plates', () {
      expect(warmupRamp(100, Equipment.barbell), [
        (20, 10),
        (40, 5),
        (60, 3),
        (80, 1),
      ]);
      expect(warmupRamp(40, Equipment.barbell), [
        (20, 10),
        (22.5, 3),
        (30, 1),
      ], reason: '40% is under the bar, so it is dropped');
      expect(warmupRamp(20, Equipment.barbell), isEmpty);
      expect(warmupRamp(30, Equipment.dumbbell), [
        (10, 5),
        (17.5, 3),
        (22.5, 1),
      ], reason: 'no bar to start from');
    });

    test('the warm-up chip adds the ramp once, then one set at a time', () {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true)
        ..startWorkout();
      addTearDown(store.dispose);
      final sets = store.activeWorkout!.currentExercise.sets;
      final working = sets.first.weightKg;

      final ramp = store.addWarmups();
      expect(ramp, isNotEmpty);
      expect(sets.take(ramp.length), ramp, reason: 'ahead of the work');
      expect(ramp.every((set) => set.weightKg < working), isTrue);
      expect(store.addWarmups(), hasLength(1));
    });

    test('added sets start from the working sets, not a warm-up', () {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true)
        ..startWorkout();
      addTearDown(store.dispose);
      final sets = store.activeWorkout!.currentExercise.sets;
      final working = sets.last;

      store.addSet(SetType.warmup);
      final drop = store.addSet(SetType.drop)!;
      final extra = store.addSet(SetType.working)!;

      expect(drop.weightKg, startingWeight(working.weightKg, SetType.drop));
      expect(sets.last, extra);
      expect(
        (extra.weightKg, extra.reps),
        (working.weightKg, working.reps),
        reason: 'one more working set repeats the last',
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
      Workload? workload,
    }) {
      day = day.subtract(const Duration(days: 3));
      return ExerciseAttempt(
        date: day,
        weightKg: weightKg,
        reps: reps,
        workingSets: sets,
        rir: rir,
        workload: workload,
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

    test('a workout rated too hard is not followed by more weight', () {
      final suggestion = suggestProgression(
        planned: plan,
        recent: [attempt(reps: 5, workload: Workload.tooHard)],
      )!;

      expect(suggestion.move, ProgressionMove.hold);
      expect(suggestion.targetWeightKg, 90);
      expect(suggestion.reason, contains('太吃力'));
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

  group('plates', () {
    test('the heaviest plates first, per side of a 20 kg bar', () {
      expect(platesPerSide(100), [25, 15]);
      expect(platesPerSide(62.5), [20, 1.25]);
      expect(platesPerSide(20), isEmpty, reason: 'the bare bar');
    });

    test('a weight the plates cannot make says so', () {
      expect(platesPerSide(15), isNull);
      expect(platesPerSide(21), isNull);
    });
  });

  group('muscle weeks', () {
    test('sets land on the primary muscles, week by week', () {
      final now = DateTime(2026, 9, 24);
      const squat = ExerciseDefinition(
        id: 'squat',
        name: '深蹲',
        equipment: Equipment.barbell,
        primaryMuscles: [MuscleGroup.quads, MuscleGroup.glutes],
        secondaryMuscles: [MuscleGroup.hamstrings],
        pattern: MovementPattern.squat,
      );
      const curl = ExerciseDefinition(
        id: 'curl',
        name: '彎舉',
        equipment: Equipment.dumbbell,
        primaryMuscles: [MuscleGroup.arms],
        pattern: MovementPattern.isolation,
      );
      final weeks = weeklySetsPerMuscle(
        [
          (squat, [(now, 4), (now.subtract(const Duration(days: 7)), 3)]),
          (curl, [(now.subtract(const Duration(days: 60)), 3)]),
        ],
        now: now,
        weeks: 4,
      );

      expect(weeks.map((entry) => entry.$1), [
        MuscleGroup.quads,
        MuscleGroup.glutes,
      ], reason: 'secondary work and weeks outside the span do not count');
      expect(weeks.first.$2.map((bar) => bar.$2), [0, 0, 3, 4]);
    });
  });

  group('personal records', () {
    test('the heaviest lift keeps the day it was first made', () {
      const squat = ExerciseDefinition(
        id: 'squat',
        name: '深蹲',
        equipment: Equipment.barbell,
        primaryMuscles: [MuscleGroup.quads],
        pattern: MovementPattern.squat,
      );
      ExerciseHistoryEntry entry(int day, double kg, int reps) =>
          ExerciseHistoryEntry(
            date: DateTime(2026, 9, day),
            weightKg: kg,
            reps: reps,
            oneRepMaxKg: estimateOneRepMax(kg, reps),
          );
      final bests = bestsOf(
        squat,
        ExerciseHistory(
          // Newest first, as the history is kept.
          recent: [entry(20, 100, 5), entry(16, 90, 10), entry(12, 100, 3)],
          sessionCount: 3,
        ),
      )!;

      expect(bests.heaviest.date.day, 12);
      expect(bests.bestEstimate!.date.day, 16, reason: '90 × 10 is 120');
      expect(bests.latest.day, 16);
      expect(
        bestsOf(squat, ExerciseHistory.empty),
        isNull,
        reason: 'no session, nothing to show',
      );
    });
  });

  group('workout review', () {
    WorkoutSet done(double kg, int reps, {SetType type = SetType.working}) =>
        WorkoutSet(
          weightKg: kg,
          reps: reps,
          previousWeightKg: kg,
          previousReps: reps,
          type: type,
          isDone: true,
        );
    final earlier = [
      ExerciseHistoryEntry(
        date: DateTime(2026, 9, 16),
        weightKg: 100,
        reps: 5,
        oneRepMaxKg: estimateOneRepMax(100, 5),
      ),
    ];

    test('a record is heavier, or more reps at a weight already lifted', () {
      expect(isPersonalRecordSet(done(102.5, 1), earlier), isTrue);
      expect(isPersonalRecordSet(done(100, 6), earlier), isTrue);
      expect(isPersonalRecordSet(done(100, 5), earlier), isFalse);
      expect(isPersonalRecordSet(done(90, 8), earlier), isFalse);
    });

    test('a first session, a warm-up or an unfinished set is no record', () {
      expect(isPersonalRecordSet(done(100, 5), const []), isFalse);
      expect(
        isPersonalRecordSet(done(120, 1, type: SetType.warmup), earlier),
        isFalse,
      );
      final pending = WorkoutSet(
        weightKg: 120,
        reps: 1,
        previousWeightKg: 100,
        previousReps: 5,
      );
      expect(isPersonalRecordSet(pending, earlier), isFalse);
    });

    test('totals, the best record set and last time of the template', () {
      const squat = ExerciseDefinition(
        id: 'squat',
        name: '深蹲',
        equipment: Equipment.barbell,
        primaryMuscles: [MuscleGroup.quads],
        pattern: MovementPattern.squat,
      );
      WorkoutSession session(List<WorkoutSet> sets) => WorkoutSession(
        id: 'w',
        routineName: '下肢',
        startedAt: DateTime(2026, 9, 20),
        exercises: [ExerciseSession(exercise: squat, sets: sets)],
      );
      final review = reviewWorkout(
        session([
          done(60, 5, type: SetType.warmup),
          done(100, 6),
          done(102.5, 3),
        ]),
        earlier: {'squat': earlier},
        previous: session([done(100, 5), done(100, 5)]),
      );

      expect(review.sets, 3);
      expect(review.volumeKg, 100 * 6 + 102.5 * 3, reason: 'no warm-up');
      expect(review.previousVolumeKg, 1000);
      expect(review.records, 1);
      expect(
        review.exercises.single.record!.reps,
        6,
        reason: '100 × 6 estimates higher than 102.5 × 3',
      );
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
        );

    test('a set counts for each primary muscle, not the secondary ones', () {
      final load = setsByMuscle([
        (of('squat', [MuscleGroup.quads, MuscleGroup.glutes]), 6),
        (of('curl', [MuscleGroup.arms]), 4),
      ]);

      expect(load, [
        (MuscleGroup.glutes, 6),
        (MuscleGroup.quads, 6),
        (MuscleGroup.arms, 4),
      ], reason: 'a tie keeps the order muscles are listed in');
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

  group('caffeine', () {
    final clock = FakeClock();

    CaffeineIntake intake(double mg, Duration ago) =>
        CaffeineIntake(at: clock.now().subtract(ago), milligrams: mg);

    test('one dose halves over the assumed half-life', () {
      final remaining = estimatedCaffeineRemaining([
        intake(100, const Duration(hours: 5)),
      ], now: clock.now());

      expect(remaining, closeTo(50, 0.01));
    });

    test('doses add up and each decays from its own time', () {
      final remaining = estimatedCaffeineRemaining([
        intake(100, const Duration(hours: 10)),
        intake(80, Duration.zero),
      ], now: clock.now());

      expect(remaining, closeTo(25 + 80, 0.01));
    });

    test('the half-life is the only assumption, and it changes a lot', () {
      final doses = [intake(100, const Duration(hours: 8))];

      expect(
        estimatedCaffeineRemaining(doses, now: clock.now()),
        closeTo(33, 1),
        reason: 'the default 5 hours',
      );
      expect(
        estimatedCaffeineRemaining(doses, now: clock.now(), halfLifeHours: 1.5),
        closeTo(2.5, 0.5),
        reason: 'a fast metaboliser',
      );
      expect(
        estimatedCaffeineRemaining(doses, now: clock.now(), halfLifeHours: 9.5),
        closeTo(56, 1),
        reason: 'a slow one — the same cup, twenty times the estimate',
      );
    });

    test('caffeine not yet drunk is not counted', () {
      final remaining = estimatedCaffeineRemaining([
        CaffeineIntake(
          at: clock.now().add(const Duration(hours: 1)),
          milligrams: 200,
        ),
      ], now: clock.now());

      expect(remaining, 0);
    });

    test('intakes come from what the meals recorded', () {
      final at = clock.now();
      final intakes = caffeineIntakes([
        (
          at,
          const MealEvent(
            id: 'coffee',
            name: '黑咖啡',
            timeLabel: '09:00',
            qualityTag: '自訂食物',
            dishes: [],
            nutrients: {Nutrient.caffeine: 95},
          ),
        ),
        (
          at,
          const MealEvent(
            id: 'rice',
            name: '白飯',
            timeLabel: '12:00',
            qualityTag: '自訂食物',
            dishes: [],
          ),
        ),
      ]);

      expect(intakes, hasLength(1));
      expect(intakes.single.milligrams, 95);
    });
  });

  test('a plate total names what it left out instead of marking it', () {
    FoodPortion one(double? kcal, NutrientValueType type) => FoodPortion(
      FoodItem(id: '$kcal$type', name: 'x', kcal: kcal, valueType: type),
      1,
    );
    const declared = NutrientValueType.declared;
    expect(
      plateKcalLabel([one(100, declared), one(6, NutrientValueType.max)]),
      '106',
    );
    expect(plateMissingLabel([one(100, declared)]), isNull);
    expect(
      plateMissingLabel([one(100, declared), one(null, declared)]),
      '1 項沒有熱量',
    );
    expect(plateKcalLabel([one(100, declared), one(null, declared)]), '100');
  });

  test(
    'energy is worked out part by part, carbohydrate less what it holds',
    () {
      const meal = MealEvent(
        id: 'cocktail',
        name: '調酒',
        timeLabel: '21:00',
        qualityTag: '手動',
        dishes: [],
        carbGrams: 88,
        proteinGrams: 5,
        fatGrams: 2,
        fibreGrams: 4,
        nutrients: {Nutrient.polyols: 10, Nutrient.alcohol: 13},
      );
      final energy = energyParts(meal);
      expect(energy.carb, (88 - 4 - 10) * 4, reason: 'less fibre and polyols');
      expect(energy.protein, 20);
      expect(energy.fat, 18);
      expect(energy.fibre, 8);
      expect(energy.polyols, 24);
      expect(energy.alcohol, 91);
      expect(
        energyParts(
          const MealEvent(
            id: 'unknown',
            name: '不知道',
            timeLabel: '12:00',
            qualityTag: '手動',
            dishes: [],
          ),
        ),
        (
          carb: null,
          protein: null,
          fat: null,
          fibre: null,
          polyols: null,
          alcohol: null,
        ),
      );
    },
  );

  test('a meal of several items is their sum, main figures all or none', () {
    MealEvent item(String id, {int? kcal, int? protein, double? alcohol}) =>
        MealEvent(
          id: id,
          name: id,
          timeLabel: '20:00',
          qualityTag: '手動',
          dishes: const [],
          kcal: kcal,
          proteinGrams: protein,
          nutrients: {Nutrient.alcohol: ?alcohol},
          groupId: 'g',
        );
    final total = mealTotal([
      item('披薩', kcal: 800, protein: 30),
      item('啤酒', kcal: 142, alcohol: 13),
    ]);
    expect(total.kcal, 942);
    expect(
      total.proteinGrams,
      isNull,
      reason: 'the beer gave none: a sum would say less than was eaten',
    );
    expect(
      total.nutrients[Nutrient.alcohol],
      13,
      reason: 'what is known adds up; the pizza has none on record',
    );
    expect(total.name, '披薩、啤酒');
  });

  group('nutrition targets', () {
    test('resting energy is Mifflin-St Jeor', () {
      // 70 kg, 175 cm, 30 years: 700 + 1093.75 - 150, +5 or -161.
      expect(
        restingEnergyKcal(weightKg: 70, heightCm: 175, age: 30, sex: Sex.male),
        1649,
      );
      expect(
        restingEnergyKcal(
          weightKg: 70,
          heightCm: 175,
          age: 30,
          sex: Sex.female,
        ),
        1483,
      );
    });

    test('an energy target from the body splits into the macros', () {
      final targets = nutritionTargets(
        const NutritionTargetSettings(goal: WeightGoal.lose),
        weightKg: 70,
        heightCm: 175,
        age: 30,
        sex: Sex.male,
      );
      // 1649 x 1.55 = 2556 to keep weight; losing 0.5 % of 70 kg a
      // week is 0.35 kg x 7,700 kcal / 7 days = 385 kcal a day less.
      expect(targets.maintenanceKcal, 2556);
      expect(targets.kcal, 2171);
      expect(targets.proteinGrams, 154, reason: '2.2 g per kg, losing fat');
      expect(targets.fatGrams, 60, reason: '25 % of energy');
      expect(
        targets.carbGrams,
        254,
        reason: 'the rest of the energy: (2171 - 154 x 4 - 60 x 9) / 4',
      );
      expect(targets.fibreGrams, 30, reason: '14 g per 1,000 kcal');
      expect(targets.missing, isEmpty);
    });

    test('the goal moves energy by a share of body weight a week', () {
      int? kcal(NutritionTargetSettings settings, double weightKg) =>
          nutritionTargets(
            settings,
            weightKg: weightKg,
            heightCm: 175,
            age: 30,
            sex: Sex.male,
          ).kcal;
      int? difference(NutritionTargetSettings settings, double weightKg) =>
          kcal(settings, weightKg)! -
          kcal(const NutritionTargetSettings(), weightKg)!;

      expect(
        difference(const NutritionTargetSettings(goal: WeightGoal.gain), 70),
        193,
        reason: '0.25 % of 70 kg a week',
      );
      expect(
        difference(const NutritionTargetSettings(goal: WeightGoal.lose), 100),
        -550,
        reason: 'the same rate is a bigger deficit for a bigger body',
      );
      expect(
        difference(
          const NutritionTargetSettings(
            goal: WeightGoal.lose,
            weeklyPercent: -0.25,
          ),
          100,
        ),
        -275,
      );
      expect(
        difference(
          const NutritionTargetSettings(
            goal: WeightGoal.gain,
            weeklyPercent: -0.5,
          ),
          70,
        ),
        193,
        reason: 'a losing rate is not a gaining one: the default stands',
      );
    });

    test('maintenance the records show replaces the equation', () {
      NutritionTargets targets({int? measured, double? heightCm = 175}) =>
          nutritionTargets(
            const NutritionTargetSettings(goal: WeightGoal.lose),
            weightKg: 70,
            heightCm: heightCm,
            age: 30,
            sex: Sex.male,
            measuredMaintenanceKcal: measured,
          );

      final shown = targets(measured: 2800);
      expect(shown.maintenanceKcal, 2800);
      expect(shown.maintenanceSource, MaintenanceSource.measured);
      expect(shown.kcal, 2800 - 385, reason: 'the goal moves it the same');

      final underlogged = targets(measured: 1500);
      expect(
        underlogged.maintenanceSource,
        MaintenanceSource.formula,
        reason: 'below the 1,649 kcal of rest is food left out, not the body',
      );
      expect(underlogged.maintenanceKcal, 2556);

      final noHeight = targets(measured: 2800, heightCm: null);
      expect(noHeight.kcal, 2415, reason: 'the records need only the weight');
      expect(noHeight.missing, isEmpty);
    });

    test('protein follows the goal unless it was set', () {
      int? protein(NutritionTargetSettings settings) =>
          nutritionTargets(settings, weightKg: 70).proteinGrams;
      expect(protein(const NutritionTargetSettings()), 112, reason: '1.6');
      expect(
        protein(const NutritionTargetSettings(goal: WeightGoal.gain)),
        126,
        reason: '1.8',
      );
      expect(
        protein(
          const NutritionTargetSettings(
            goal: WeightGoal.lose,
            proteinPerKg: 1.6,
          ),
        ),
        112,
        reason: 'set by hand, the goal no longer moves it',
      );
    });

    test('without the body there is no energy target, and it says why', () {
      final targets = nutritionTargets(
        const NutritionTargetSettings(),
        weightKg: 70,
      );
      expect(targets.kcal, isNull);
      expect(targets.carbGrams, isNull);
      expect(targets.proteinGrams, 112, reason: 'protein needs only weight');
      expect(targets.missing, [
        TargetInput.height,
        TargetInput.birthYear,
        TargetInput.sex,
      ]);
    });

    test('a typed-in energy target needs no body', () {
      final targets = nutritionTargets(
        const NutritionTargetSettings(customKcal: 2200),
      );
      expect(targets.kcal, 2200);
      expect(targets.missing, isEmpty);
      expect(targets.restingKcal, isNull);
    });
  });
}
