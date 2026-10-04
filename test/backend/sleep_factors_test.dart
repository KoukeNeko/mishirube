import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/storage/database.dart';
import 'package:mishirube/domain/domain.dart';

import '../support/harness.dart';

// The clock stands on 2026-09-19. Night k ended on the morning of the
// (19 − k)th at 07:00 and began at 23:00 on the evening before, which is
// the (18 − k)th.
DateTime _evening(int k) => DateTime(2026, 9, 18 - k);

void main() {
  late Backend backend;

  setUp(() => backend = Backend.inMemory(clock: FakeClock().now));
  tearDown(() => backend.close());

  void night(int k, {Duration slept = const Duration(hours: 7)}) {
    final woke = DateTime(2026, 9, 19 - k, 7);
    backend.journal.recordSleep(
      slept,
      at: woke,
      startedAt: _evening(k).add(const Duration(hours: 23)),
    );
  }

  void meal(String id, DateTime at, {double? caffeine}) =>
      backend.nutrition.logMeal(
        MealEvent(
          id: id,
          name: id,
          timeLabel: '',
          qualityTag: '',
          dishes: const [],
          kind: ConsumptionKind.food,
          nutrients: {Nutrient.caffeine: ?caffeine},
        ),
        eatenAt: at,
      );

  /// Three meals: a day the food log is complete for.
  void completeDay(int k) {
    for (final hour in [8, 12, 19]) {
      meal('full-$k-$hour', _evening(k).add(Duration(hours: hour)));
    }
  }

  void nap(int k, {required Duration length}) {
    final woke = _evening(k).add(const Duration(hours: 15));
    backend.journal.recordSleep(
      length,
      at: woke,
      startedAt: woke.subtract(length),
      kind: SleepKind.nap,
    );
  }

  group('caffeine at bedtime', () {
    test('compares caffeine left at the usual bedtime, complete days only', () {
      for (var k = 1; k <= 40; k++) {
        night(k, slept: Duration(hours: k <= 12 ? 6 : 8));
        // 100 mg at 17:00 leaves 43.5 mg at the usual 23:00 bedtime.
        if (k <= 12) {
          meal(
            'coffee-$k',
            _evening(k).add(const Duration(hours: 17)),
            caffeine: 100,
          );
        } else if (k <= 24) {
          completeDay(k);
        } else if (k > 32) {
          // One meal, no caffeine: could have missed a cup.
          meal('one-$k', _evening(k).add(const Duration(hours: 12)));
        }
      }

      final comparison = backend.sleep.factors().caffeineAtBedtime!;

      expect(comparison.withCount, 12);
      expect(
        comparison.withoutCount,
        12,
        reason: 'days with no meals or one meal are not "without"',
      );
      expect(comparison.difference, const Duration(hours: -2));
    });

    test('caffeine early enough to be gone by bedtime is not "with"', () {
      for (var k = 1; k <= 24; k++) {
        night(k);
        // 100 mg at 08:00 leaves 6.3 mg at 23:00, on a complete day.
        completeDay(k);
        meal(
          'morning-$k',
          _evening(k).add(const Duration(hours: 8)),
          caffeine: 100,
        );
      }

      final comparison = backend.sleep.factors().caffeineAtBedtime!;

      expect(comparison.withCount, 0);
      expect(comparison.withoutCount, 24);
      expect(comparison.isEnough, isFalse);
    });

    test('without a usual bedtime there is no comparison', () {
      for (var k = 1; k <= 2; k++) {
        night(k);
      }
      expect(backend.sleep.factors().caffeineAtBedtime, isNull);
    });
  });

  group('a nap that day', () {
    test('counts a nap of 20 minutes or more before the night', () {
      for (var k = 1; k <= 30; k++) {
        night(k, slept: Duration(hours: k <= 10 ? 8 : 7));
        if (k <= 10) nap(k, length: const Duration(minutes: 30));
        // Shorter than a nap is kept as: not a nap for this factor.
        if (k > 10 && k <= 14) nap(k, length: const Duration(minutes: 10));
      }

      final comparison = backend.sleep.factors().nap;

      expect(comparison.withCount, 10);
      expect(comparison.withoutCount, 20);
      expect(comparison.difference, const Duration(hours: 1));
    });

    test('can show that there is no difference', () {
      for (var k = 1; k <= 30; k++) {
        night(k);
        if (k % 2 == 0) nap(k, length: const Duration(minutes: 40));
      }

      final comparison = backend.sleep.factors().nap;

      expect(comparison.isEnough, isTrue);
      expect(comparison.difference, Duration.zero);
    });

    test('a nap after the night began is not "that day"', () {
      for (var k = 1; k <= 30; k++) {
        night(k);
        // Ends at 23:30, after the 23:00 bedtime.
        final woke = _evening(k).add(const Duration(hours: 23, minutes: 30));
        backend.journal.recordSleep(
          const Duration(minutes: 30),
          at: woke,
          startedAt: woke.subtract(const Duration(minutes: 30)),
          kind: SleepKind.nap,
        );
      }

      expect(backend.sleep.factors().nap.withCount, 0);
    });
  });

  group('daylight', () {
    void daylight(int k, double minutes) {
      final day = _evening(k);
      backend.storage.activitySamples.sync(
        [
          ActivitySample(
            metric: ActivityMetric.timeInDaylight,
            start: day,
            end: day.add(const Duration(days: 1)),
            value: minutes,
          ),
        ],
        idPrefix: 'test',
        source: ChangeSource.healthKit,
      );
    }

    test('has no nights on either side where nothing reads daylight', () {
      for (var k = 1; k <= 30; k++) {
        night(k);
      }
      final comparison = backend.sleep.factors().daylight;
      expect(comparison.withCount, 0);
      expect(comparison.withoutCount, 0);
      expect(comparison.isEnough, isFalse);
    });

    test('splits at the median of the days that have daylight', () {
      for (var k = 1; k <= 30; k++) {
        night(k, slept: Duration(hours: k.isOdd ? 6 : 8));
        // Median 40: odd days above it, even days below.
        daylight(k, k.isOdd ? 60 : 20);
      }

      final comparison = backend.sleep.factors().daylight;

      expect(comparison.withCount, 15);
      expect(comparison.withoutCount, 15);
      expect(comparison.difference, const Duration(hours: -2));
    });

    test('a night whose day has no daylight reading is left out', () {
      for (var k = 1; k <= 30; k++) {
        night(k, slept: Duration(hours: k.isOdd ? 6 : 8));
        if (k > 10) daylight(k, k.isOdd ? 60 : 20);
      }

      final comparison = backend.sleep.factors().daylight;

      expect(comparison.withCount + comparison.withoutCount, 20);
    });
  });

  test('every factor is there with too few nights, with its counts', () {
    for (var k = 1; k <= 4; k++) {
      night(k);
    }
    final factors = backend.sleep.factors();

    expect(factors.training.isEnough, isFalse);
    expect(factors.lateMeal.isEnough, isFalse);
    expect(factors.nap.isEnough, isFalse);
    expect(factors.nap.withoutCount, 4);
  });
}
