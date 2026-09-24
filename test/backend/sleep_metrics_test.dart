import 'package:flutter_test/flutter_test.dart';
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

  test('the shortfall is net of nights over the goal', () {
    final nights = [
      _slept(21, bed: 0, wake: 0, hours: 6),
      _slept(22, bed: 0, wake: 0, hours: 9),
      _slept(23, bed: 0, wake: 0, hours: 6),
    ];
    expect(
      shortfall(nights, const Duration(hours: 8)),
      const Duration(hours: 3),
    );
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

  test('a baseline needs a week of nights', () {
    expect(baselineOf([50, 50, 50, 50, 50, 50]), isNull);
    final baseline = baselineOf([40, 60, 40, 60, 40, 60, 50, 50])!;
    expect(baseline.low, closeTo(50 - 8.66, 0.01));
    expect(baseline.high, closeTo(50 + 8.66, 0.01));
  });

  test('a comparison needs enough nights on both sides', () {
    final nights = [
      for (var day = 1; day <= 10; day++)
        _slept(day + 1, bed: 0, wake: 0, hours: day.isEven ? 6 : 8),
    ];
    final comparison = compareNights(nights, (morning) => morning.day.isOdd)!;
    expect(comparison.withCount, 5);
    expect(comparison.difference, const Duration(hours: -2));
    expect(compareNights(nights.take(6).toList(), (_) => true), isNull);
  });
}
