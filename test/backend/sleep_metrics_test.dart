import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/engines/caffeine.dart';
import 'package:mishirube/backend/engines/sleep_metrics.dart';
import 'package:mishirube/domain/domain.dart';

final _night = DateTime(2026, 9, 23, 23);

SleepSample _at(int from, int to, SleepStage stage) => SleepSample(
  start: _night.add(Duration(minutes: from)),
  end: _night.add(Duration(minutes: to)),
  stage: stage,
);

SleepEntry _slept(int day, {required int bed, required int wake, int? hours}) {
  final woke = DateTime(2026, 9, day, wake ~/ 60, wake % 60);
  final started = DateTime(2026, 9, day - 1).add(Duration(minutes: bed));
  return SleepEntry(
    id: '$day',
    sleptAt: woke,
    startedAt: started,
    duration: hours == null ? woke.difference(started) : Duration(hours: hours),
  );
}

void main() {
  group('continuity', () {
    test('in bed gives latency and efficiency; awake stretches count', () {
      final continuity = continuityOf([
        _at(0, 480, SleepStage.inBed),
        _at(20, 200, SleepStage.core),
        _at(200, 210, SleepStage.awake),
        _at(210, 213, SleepStage.core),
        _at(213, 215, SleepStage.awake),
        _at(215, 470, SleepStage.deep),
      ]);

      expect(continuity.latency, const Duration(minutes: 20));
      expect(continuity.efficiency, closeTo(438 / 480, 0.001));
      expect(continuity.awake, const Duration(minutes: 12));
      expect(continuity.awakenings, 1, reason: 'two minutes is a stir');
    });

    test('without in bed there is no latency and no efficiency', () {
      final continuity = continuityOf([
        _at(0, 200, SleepStage.asleep),
        _at(230, 480, SleepStage.asleep),
      ]);

      expect(continuity.latency, isNull);
      expect(continuity.efficiency, isNull, reason: 'not 100%');
      expect(continuity.awake, const Duration(minutes: 30));
      expect(continuity.awakenings, 1);
    });
  });

  group('regularity', () {
    test('bedtimes either side of midnight are close, not twelve hours', () {
      final regularity = regularityOf([
        _slept(21, bed: 23 * 60 + 30, wake: 7 * 60),
        _slept(22, bed: 24 * 60 + 30, wake: 7 * 60),
        _slept(23, bed: 24 * 60, wake: 7 * 60),
      ])!;

      expect(regularity.bedtimeSpread.inMinutes, 24);
      expect(regularity.wakeSpread, Duration.zero);
    });

    test('two nights are not a pattern', () {
      expect(
        regularityOf([
          _slept(21, bed: 23 * 60, wake: 7 * 60),
          _slept(22, bed: 23 * 60, wake: 7 * 60),
        ]),
        isNull,
      );
    });
  });

  group('shortfall', () {
    const need = Duration(hours: 8);

    test('short and extra are summed apart, never netted', () {
      final days = sleepDaysOf(
        [
          _slept(21, bed: 0, wake: 0, hours: 6),
          _slept(22, bed: 0, wake: 0, hours: 9),
          _slept(23, bed: 0, wake: 0, hours: 6),
        ],
        DateTime(2026, 9, 21),
        3,
      );
      final sum = shortfallOf(days, need);

      expect(sum.short, const Duration(hours: 4));
      expect(sum.extra, const Duration(hours: 1));
      expect(sum.missing, 0);
    });

    test('a day without a night is unknown, not a day without sleep', () {
      final days = sleepDaysOf(
        [
          _slept(21, bed: 0, wake: 0, hours: 6),
          SleepEntry(
            id: 'nap',
            sleptAt: DateTime(2026, 9, 22, 14),
            duration: const Duration(hours: 1),
            kind: SleepKind.nap,
          ),
        ],
        DateTime(2026, 9, 21),
        3,
      );

      expect(
        [for (final day in days) day.slept],
        [const Duration(hours: 6), null, null],
        reason: 'a nap alone does not make the day known',
      );
      final sum = shortfallOf(days, need);
      expect(sum.short, const Duration(hours: 2));
      expect(sum.recorded, 1);
      expect(sum.missing, 2);
    });

    test('naps add minute for minute; time in bed is not sleep', () {
      final days = sleepDaysOf(
        [
          _slept(21, bed: 0, wake: 0, hours: 6),
          SleepEntry(
            id: 'nap',
            sleptAt: DateTime(2026, 9, 21, 14),
            duration: const Duration(minutes: 40),
            kind: SleepKind.nap,
          ),
          SleepEntry(
            id: 'bed',
            sleptAt: DateTime(2026, 9, 22, 7),
            duration: const Duration(hours: 9),
            measure: SleepMeasure.inBed,
          ),
        ],
        DateTime(2026, 9, 21),
        2,
      );

      expect(days.first.slept, const Duration(hours: 6, minutes: 40));
      expect(days.last.slept, isNull);
    });
  });

  test('tonight works back from the usual waking', () {
    final nights = [
      for (final (day, wake) in [(21, 6 * 60 + 30), (22, 7 * 60), (23, 9 * 60)])
        _slept(day, bed: 23 * 60, wake: wake),
    ];
    final evening = tonight(
      nights,
      const Duration(hours: 8),
      now: DateTime(2026, 9, 24, 20),
    )!;
    expect(evening.wake, DateTime(2026, 9, 25, 7));
    expect(evening.bedtime, DateTime(2026, 9, 24, 23));

    final lateNight = tonight(
      nights,
      const Duration(hours: 8),
      now: DateTime(2026, 9, 25, 1),
    )!;
    expect(lateNight.wake, DateTime(2026, 9, 25, 7), reason: 'still tonight');
  });

  group('comparing nights', () {
    // Twenty nights ending on the 2nd to the 21st, odd days 8 h, even 6 h.
    List<SleepEntry> twenty() => [
      for (var day = 1; day <= 20; day++)
        _slept(day + 1, bed: 0, wake: 0, hours: day.isEven ? 6 : 8),
    ];

    test('says nothing below ten nights a side but still counts them', () {
      final nights = twenty();
      final few = compareNights(
        nights.take(18).toList(),
        (night) => night.sleptAt.day.isOdd,
      );
      expect(few.withCount, 9);
      expect(few.withoutCount, 9);
      expect(few.isEnough, isFalse);
      expect(few.difference, isNull);

      final enough = compareNights(nights, (night) => night.sleptAt.day.isEven);
      expect(enough.withCount, 10);
      expect(enough.isEnough, isTrue);
      expect(enough.difference, const Duration(hours: 2));
    });

    test('a night the thing is not known for is left out', () {
      final comparison = compareNights(
        twenty(),
        (night) => night.sleptAt.day <= 10 ? null : night.sleptAt.day.isOdd,
      );
      expect(comparison.withCount + comparison.withoutCount, 11);
      expect(comparison.isEnough, isFalse);
    });

    test('takes another outcome, and skips nights without it', () {
      final nights = [
        ...twenty(),
        for (var day = 21; day <= 24; day++)
          _slept(day + 1, bed: 0, wake: 0, hours: 7),
      ];
      final comparison = compareNights(
        nights,
        (night) => night.sleptAt.day.isOdd,
        outcome: (night) => night.sleptAt.day == 5
            ? null
            : Duration(minutes: night.sleptAt.day.isOdd ? 10 : 30),
      );
      expect(comparison.withCount, 11);
      expect(comparison.withoutCount, 12);
      expect(comparison.difference, const Duration(minutes: -20));
    });

    test('equal sides show no difference rather than hiding', () {
      final comparison = compareNights([
        for (var day = 1; day <= 20; day++)
          _slept(day + 1, bed: 0, wake: 0, hours: 7),
      ], (night) => night.sleptAt.day.isOdd);
      expect(comparison.difference, Duration.zero);
    });
  });

  group('caffeine at the usual bedtime', () {
    final morning = DateTime(2026, 9, 20);
    final coffee = [
      CaffeineIntake(at: DateTime(2026, 9, 19, 14), milligrams: 107),
    ];

    test('an evening bedtime is on the evening before the morning', () {
      // 107 mg at 14:00, 22:00 bedtime: 8 h = 1.6 half-lives, 35.3 mg.
      final remaining = caffeineAtUsualBedtime(
        coffee,
        morning,
        const Duration(hours: 22),
      )!;
      expect(remaining, closeTo(35.3, 0.1));
      expect(remaining, greaterThanOrEqualTo(caffeineBedtimeReferenceMg));
    });

    test('a bedtime after midnight is on the morning itself', () {
      // 01:00 on the 20th is 11 h later: 23.3 mg.
      expect(
        caffeineAtUsualBedtime(coffee, morning, const Duration(hours: 1))!,
        closeTo(23.3, 0.1),
      );
    });

    test('caffeine after the usual bedtime or a day before is not counted', () {
      final intakes = [
        CaffeineIntake(at: DateTime(2026, 9, 19, 23), milligrams: 200),
        CaffeineIntake(at: DateTime(2026, 9, 18, 20), milligrams: 400),
      ];
      expect(
        caffeineAtUsualBedtime(intakes, morning, const Duration(hours: 22)),
        0,
      );
    });

    test('is null without a usual bedtime', () {
      expect(caffeineAtUsualBedtime(coffee, morning, null), isNull);
    });
  });
}
