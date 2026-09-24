import 'dart:math' as math;

import '../../domain/domain.dart';

/// Bumped whenever a rule below changes.
const sleepMetricsVersion = 1;

/// An awake stretch this long or longer inside a sleep counts as waking
/// up; shorter ones are the stirring every night has.
const awakeningMinimum = Duration(minutes: 5);

/// Longer than this between getting into bed and falling asleep is taken
/// as reading in bed, not as trying to sleep, and gives no latency.
const _longestLatency = Duration(hours: 2);

/// Nights needed before regularity, a baseline or a comparison says
/// anything: fewer are anecdotes.
const minimumNightsForRegularity = 3;
const minimumNightsForBaseline = 7;
const minimumNightsPerSide = 5;

/// How one sleep held together, from one source's stretches. Each figure
/// is null when the source did not record what it needs: a watch that
/// never says "in bed" gives no efficiency, rather than 100%.
class SleepContinuity {
  const SleepContinuity({
    required this.latency,
    required this.efficiency,
    required this.awake,
    required this.awakenings,
  });

  /// From getting into bed to first falling asleep.
  final Duration? latency;

  /// Time asleep over time in bed, 0–1.
  final double? efficiency;

  /// Time awake between first falling asleep and last waking.
  final Duration? awake;

  /// Awake stretches of [awakeningMinimum] or more in that time.
  final int? awakenings;
}

/// [stretches] of one source, "in bed" included when it recorded it.
SleepContinuity continuityOf(List<SleepSample> stretches) {
  final asleep = [
    for (final stretch in stretches)
      if (stretch.stage.isAsleep) stretch,
  ]..sort((a, b) => a.start.compareTo(b.start));
  final inBed = [
    for (final stretch in stretches)
      if (stretch.stage == SleepStage.inBed) stretch,
  ]..sort((a, b) => a.start.compareTo(b.start));
  if (asleep.isEmpty) {
    return const SleepContinuity(
      latency: null,
      efficiency: null,
      awake: null,
      awakenings: null,
    );
  }
  final fellAsleep = asleep.first.start;
  final wokeUp = asleep
      .map((s) => s.end)
      .reduce((a, b) => a.isAfter(b) ? a : b);
  final asleepTime = _covered(asleep);

  Duration? latency;
  double? efficiency;
  if (inBed.isNotEmpty) {
    final bedStart = inBed.first.start;
    final bedEnd = [
      ...inBed.map((s) => s.end),
      wokeUp,
    ].reduce((a, b) => a.isAfter(b) ? a : b);
    final beforeSleep = fellAsleep.difference(bedStart);
    if (!beforeSleep.isNegative && beforeSleep <= _longestLatency) {
      latency = beforeSleep;
    }
    final span = bedEnd.difference(
      bedStart.isBefore(fellAsleep) ? bedStart : fellAsleep,
    );
    if (span > Duration.zero) {
      efficiency = math.min(1, asleepTime.inSeconds / span.inSeconds);
    }
  }

  final awakeStretches = [
    for (final stretch in stretches)
      if (stretch.stage == SleepStage.awake &&
          stretch.start.isAfter(fellAsleep) &&
          stretch.end.isBefore(wokeUp))
        stretch,
  ];
  // A source that stages sleep says when it was awake; one that only
  // says asleep leaves gaps between its stretches instead.
  final gaps = <Duration>[
    for (var i = 1; i < asleep.length; i++)
      if (asleep[i].start.isAfter(asleep[i - 1].end))
        asleep[i].start.difference(asleep[i - 1].end),
  ];
  final awakeSpans = awakeStretches.isNotEmpty
      ? [for (final stretch in awakeStretches) stretch.length]
      : gaps;
  return SleepContinuity(
    latency: latency,
    efficiency: efficiency,
    awake: awakeSpans.fold<Duration>(Duration.zero, (sum, d) => sum + d),
    awakenings: awakeSpans.where((d) => d >= awakeningMinimum).length,
  );
}

Duration _covered(List<SleepSample> sorted) {
  var total = Duration.zero;
  DateTime? reached;
  for (final stretch in sorted) {
    final start = reached != null && reached.isAfter(stretch.start)
        ? reached
        : stretch.start;
    if (stretch.end.isAfter(start)) total += stretch.end.difference(start);
    if (reached == null || stretch.end.isAfter(reached)) reached = stretch.end;
  }
  return total;
}

/// How much bedtimes and wake times move from night to night: the
/// standard deviation of each, in minutes of clock time. Not the Sleep
/// Regularity Index, which needs every hour of the day recorded.
class SleepRegularity {
  const SleepRegularity({
    required this.nights,
    required this.bedtimeSpread,
    required this.wakeSpread,
  });

  final int nights;
  final Duration bedtimeSpread;
  final Duration wakeSpread;
}

/// Regularity over [nights] that say when they began; null below
/// [minimumNightsForRegularity] of them.
SleepRegularity? regularityOf(List<SleepEntry> nights) {
  final timed = [
    for (final night in nights)
      if (night.startedAt case final start?) (start, night.sleptAt),
  ];
  if (timed.length < minimumNightsForRegularity) return null;
  return SleepRegularity(
    nights: timed.length,
    bedtimeSpread: _clockSpread([for (final (bed, _) in timed) bed], 12),
    wakeSpread: _clockSpread([for (final (_, wake) in timed) wake], 0),
  );
}

/// Minutes of [time] past [fromHour], so times either side of midnight
/// sit in one unbroken stretch when counted from noon.
int clockMinutes(DateTime time, int fromHour) =>
    (time.hour * 60 + time.minute - fromHour * 60) % Duration.minutesPerDay;

Duration _clockSpread(List<DateTime> times, int fromHour) {
  final minutes = [for (final time in times) clockMinutes(time, fromHour)];
  final mean = minutes.reduce((a, b) => a + b) / minutes.length;
  final variance =
      minutes.map((m) => (m - mean) * (m - mean)).reduce((a, b) => a + b) /
      minutes.length;
  return Duration(minutes: math.sqrt(variance).round());
}

/// How far [nights] fell short of [goal] in total, net of nights that
/// went over it: positive is less sleep than the goal. A model of the
/// goal, not a debt the body keeps. Nights not recorded are left out,
/// rather than counted as none.
Duration shortfall(List<SleepEntry> nights, Duration goal) =>
    nights.fold(Duration.zero, (sum, night) => sum + (goal - night.duration));

/// When to go to bed tonight to sleep [goal] and wake as usual: the
/// usual waking is the middle one of [nights]. Null with too few nights
/// to have a usual.
({DateTime bedtime, DateTime wake})? tonight(
  List<SleepEntry> nights,
  Duration goal, {
  required DateTime now,
}) {
  if (nights.length < minimumNightsForRegularity) return null;
  final wakes = [for (final night in nights) clockMinutes(night.sleptAt, 0)]
    ..sort();
  final usual = wakes[wakes.length ~/ 2];
  // The next usual waking: later today when it is still night.
  var wake = DateTime(
    now.year,
    now.month,
    now.day,
  ).add(Duration(minutes: usual));
  if (!wake.isAfter(now)) wake = wake.add(const Duration(days: 1));
  return (bedtime: wake.subtract(goal), wake: wake);
}

/// The usual range of a nightly reading: the mean give or take one
/// standard deviation of [values]; null below [minimumNightsForBaseline].
({double low, double high})? baselineOf(List<double> values) {
  if (values.length < minimumNightsForBaseline) return null;
  final mean = values.reduce((a, b) => a + b) / values.length;
  final deviation = math.sqrt(
    values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
        values.length,
  );
  return (low: mean - deviation, high: mean + deviation);
}

/// Nights after days with something against nights after days without
/// it: how long they slept, and how many there were of each. It says the
/// two go together in these records, not that one causes the other.
class SleepComparison {
  const SleepComparison({
    required this.withCount,
    required this.withoutCount,
    required this.withAverage,
    required this.withoutAverage,
  });

  final int withCount;
  final int withoutCount;
  final Duration withAverage;
  final Duration withoutAverage;

  Duration get difference => withAverage - withoutAverage;
}

/// [nights] split by whether the day before each had the thing
/// ([hadIt] is given the night's morning); null unless both sides have
/// [minimumNightsPerSide] nights.
SleepComparison? compareNights(
  List<SleepEntry> nights,
  bool Function(DateTime morning) hadIt,
) {
  final withIt = <Duration>[];
  final without = <Duration>[];
  for (final night in nights) {
    final morning = DateTime(
      night.sleptAt.year,
      night.sleptAt.month,
      night.sleptAt.day,
    );
    (hadIt(morning) ? withIt : without).add(night.duration);
  }
  if (withIt.length < minimumNightsPerSide ||
      without.length < minimumNightsPerSide) {
    return null;
  }
  Duration average(List<Duration> all) =>
      all.fold(Duration.zero, (sum, d) => sum + d) ~/ all.length;
  return SleepComparison(
    withCount: withIt.length,
    withoutCount: without.length,
    withAverage: average(withIt),
    withoutAverage: average(without),
  );
}
