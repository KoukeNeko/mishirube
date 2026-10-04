import 'dart:math' as math;

import '../../domain/domain.dart';
import 'caffeine.dart';

/// Bumped whenever a rule below changes.
const sleepMetricsVersion = 3;

/// An awake stretch this long or longer inside a sleep counts as waking
/// up; shorter ones are the stirring every night has.
const awakeningMinimum = Duration(minutes: 5);

/// Longer than this between getting into bed and falling asleep is taken
/// as reading in bed, not as trying to sleep, and gives no latency.
const _longestLatency = Duration(hours: 2);

/// Nights needed before regularity or a baseline says anything: fewer
/// are anecdotes.
const minimumNightsForRegularity = 3;

/// Nights each side of a factor needs before its difference is shown;
/// 5 is under what a personal average of sleep time needs to settle
/// (research/92e A.5), and even 10 only describes, it does not test.
const minimumNightsPerSide = 10;

/// How one sleep held together, from one source's stretches. Each figure
/// is null when the source did not record what it needs: a watch that
/// never says "in bed" gives no efficiency, rather than 100%.
class SleepContinuity {
  const SleepContinuity({
    required this.latency,
    required this.efficiency,
    required this.awake,
    required this.awakenings,
    this.inBedAt,
  });

  /// When the source says the person got into bed; null when it recorded
  /// no time in bed.
  final DateTime? inBedAt;

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
    inBedAt: inBed.firstOrNull?.start,
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

/// Where bedtimes and wake times sit and how much they move from night
/// to night: the average of each as a time after midnight, and its
/// standard deviation in minutes of clock time.
class SleepRegularity {
  const SleepRegularity({
    required this.nights,
    required this.bedtime,
    required this.wake,
    required this.bedtimeSpread,
    required this.wakeSpread,
  });

  final int nights;
  final Duration bedtime;
  final Duration wake;
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
    bedtime: _clockMean([for (final (bed, _) in timed) bed], 12),
    wake: _clockMean([for (final (_, wake) in timed) wake], 0),
    bedtimeSpread: _clockSpread([for (final (bed, _) in timed) bed], 12),
    wakeSpread: _clockSpread([for (final (_, wake) in timed) wake], 0),
  );
}

/// Day pairs the Sleep Regularity Index needs before it says anything.
const minimumDayPairsForRegularityIndex = 7;

/// Nights on work days and on free days each, before social jetlag is
/// worked out.
const minimumNightsForSocialJetlag = 2;

/// The stretch of the day the index compares state by state.
const _epoch = Duration(minutes: 5);

/// The nights that say when they began and ended, measured by a device
/// or typed in with both times; a length typed alone says neither.
List<SleepEntry> _timedNights(List<SleepEntry> sleeps) => [
  for (final sleep in sleeps)
    if (sleep.kind == SleepKind.night &&
        sleep.measure == SleepMeasure.asleep &&
        sleep.startedAt != null)
      sleep,
];

DateTime _dayOf(DateTime time) => DateTime(time.year, time.month, time.day);

/// The Sleep Regularity Index (Phillips et al., 2017): how often the
/// same clock time is asleep (or awake) on one day and the next, from
/// −100 (always opposite) through 0 (chance) to 100 (identical days),
/// over 5-minute stretches. Only days whose whole 24 hours are known
/// count: the night that ended that morning and the one that began that
/// evening both say when they began and ended. Null below
/// [minimumDayPairsForRegularityIndex] pairs of such days.
int? sleepRegularityIndex(List<SleepEntry> sleeps) {
  final nights = _timedNights(sleeps);
  final ends = {for (final night in nights) _dayOf(night.sleptAt)};
  bool isKnown(DateTime day) =>
      ends.contains(day) && ends.contains(day.add(const Duration(days: 1)));
  final spans = [for (final night in nights) (night.startedAt!, night.sleptAt)];
  bool isAsleep(DateTime at) =>
      spans.any((span) => !at.isBefore(span.$1) && at.isBefore(span.$2));
  final epochs = Duration.minutesPerDay ~/ _epoch.inMinutes;
  var pairs = 0;
  var same = 0;
  for (final day in ends) {
    final next = DateTime(day.year, day.month, day.day + 1);
    if (!isKnown(day) || !isKnown(next)) continue;
    pairs++;
    for (var epoch = 0; epoch < epochs; epoch++) {
      final minute = epoch * _epoch.inMinutes + _epoch.inMinutes ~/ 2;
      final today = DateTime(day.year, day.month, day.day, 0, minute);
      final tomorrow = DateTime(next.year, next.month, next.day, 0, minute);
      if (isAsleep(today) == isAsleep(tomorrow)) same++;
    }
  }
  if (pairs < minimumDayPairsForRegularityIndex) return null;
  return (-100 + 200 * same / (pairs * epochs)).round();
}

/// Social jetlag (Roenneberg et al., 2012): how far the middle of sleep
/// on free days (nights ending on Saturday or Sunday) sits from that on
/// work days, later on free days when positive, without the correction
/// for sleep caught up on free days. Days are told apart by the weekday
/// alone, so someone working weekends is read the wrong way round. Null
/// without [minimumNightsForSocialJetlag] of each.
Duration? socialJetlag(List<SleepEntry> sleeps) {
  final free = <int>[];
  final work = <int>[];
  for (final night in _timedNights(sleeps)) {
    final start = night.startedAt!;
    final middle = start.add(night.sleptAt.difference(start) ~/ 2);
    final weekday = night.sleptAt.weekday;
    (weekday == DateTime.saturday || weekday == DateTime.sunday ? free : work)
        .add(clockMinutes(middle, 12));
  }
  if (free.length < minimumNightsForSocialJetlag ||
      work.length < minimumNightsForSocialJetlag) {
    return null;
  }
  double mean(List<int> minutes) =>
      minutes.reduce((a, b) => a + b) / minutes.length;
  return Duration(minutes: (mean(free) - mean(work)).round());
}

/// Each week's usual night as one stretch of the clock, for the weeks
/// starting on [weekStarts]: the average time its nights began, in
/// minutes after noon, and that plus their average time from falling
/// asleep to waking, so a night across midnight stays one stretch and
/// waking may pass the next noon. A night belongs to the week of the
/// morning it ended, as in `trendDetail`. Null for a week without a
/// night that says when it began.
List<(double, double)?> weeklySchedule(
  List<SleepEntry> sleeps,
  List<DateTime> weekStarts,
) {
  final byWeek = List.generate(weekStarts.length, (_) => <SleepEntry>[]);
  for (final night in _timedNights(sleeps)) {
    final day = _dayOf(night.sleptAt);
    for (final (week, start) in weekStarts.indexed) {
      if (!day.isBefore(start) &&
          day.isBefore(DateTime(start.year, start.month, start.day + 7))) {
        byWeek[week].add(night);
        break;
      }
    }
  }
  return [
    for (final nights in byWeek)
      if (nights.isEmpty)
        null
      else
        () {
          double mean(Iterable<int> minutes) =>
              minutes.reduce((a, b) => a + b) / nights.length;
          final bedtime = mean([
            for (final night in nights) clockMinutes(night.startedAt!, 12),
          ]);
          final length = mean([
            for (final night in nights)
              night.sleptAt.difference(night.startedAt!).inMinutes,
          ]);
          return (bedtime, bedtime + length);
        }(),
  ];
}

/// Minutes of [time] past [fromHour], so times either side of midnight
/// sit in one unbroken stretch when counted from noon.
int clockMinutes(DateTime time, int fromHour) =>
    (time.hour * 60 + time.minute - fromHour * 60) % Duration.minutesPerDay;

/// The average of [times] as a time after midnight, counted from
/// [fromHour] so times either side of midnight average to it.
Duration _clockMean(List<DateTime> times, int fromHour) {
  final minutes = [for (final time in times) clockMinutes(time, fromHour)];
  final mean = minutes.reduce((a, b) => a + b) / minutes.length;
  return Duration(
    minutes: (mean.round() + fromHour * 60) % Duration.minutesPerDay,
  );
}

Duration _clockSpread(List<DateTime> times, int fromHour) {
  final minutes = [for (final time in times) clockMinutes(time, fromHour)];
  final mean = minutes.reduce((a, b) => a + b) / minutes.length;
  final variance =
      minutes.map((m) => (m - mean) * (m - mean)).reduce((a, b) => a + b) /
      minutes.length;
  return Duration(minutes: math.sqrt(variance).round());
}

/// The night a day's sleep is read against until the user sets a goal:
/// a choice, not a finding. The AASM/SRS consensus says only "7 hours or
/// more" for adults; the studies that looked for a need land near 8.
const defaultSleepNeed = Duration(hours: 8);

/// One day's sleep: time asleep that night and in the day's naps, or
/// null when no night asleep was recorded. A day without a record is
/// unknown, not a day without sleep.
class SleepDay {
  const SleepDay(this.day, this.slept);

  /// Midnight of the morning the night ended on.
  final DateTime day;
  final Duration? slept;
}

/// The days from [first] for [count] days, each with its sleep from
/// [sleeps]. Only time asleep counts: time in bed is not sleep, and a
/// nap is added minute for minute, with no exchange rate.
List<SleepDay> sleepDaysOf(List<SleepEntry> sleeps, DateTime first, int count) {
  final asleep = <DateTime, Duration>{};
  final hadNight = <DateTime>{};
  for (final sleep in sleeps) {
    if (sleep.measure != SleepMeasure.asleep) continue;
    final day = DateTime(
      sleep.sleptAt.year,
      sleep.sleptAt.month,
      sleep.sleptAt.day,
    );
    asleep.update(
      day,
      (sum) => sum + sleep.duration,
      ifAbsent: () => sleep.duration,
    );
    if (sleep.kind == SleepKind.night) hadNight.add(day);
  }
  final days = <SleepDay>[];
  for (var i = 0; i < count; i++) {
    final day = DateTime(first.year, first.month, first.day + i);
    days.add(SleepDay(day, hadNight.contains(day) ? asleep[day] : null));
  }
  return days;
}

/// How [days] went against [need]: the time short of it and the time
/// over it, summed apart. They are not netted, because sleeping longer
/// does not pay back a short night hour for hour, and nothing decays,
/// because no study gives a rate. A sum of the goal's shortfall, not a
/// debt the body keeps.
class SleepShortfall {
  const SleepShortfall({
    required this.short,
    required this.extra,
    required this.recorded,
    required this.days,
  });

  final Duration short;
  final Duration extra;

  /// Days with a night asleep recorded, of [days].
  final int recorded;
  final int days;

  int get missing => days - recorded;
}

SleepShortfall shortfallOf(List<SleepDay> days, Duration need) {
  var short = Duration.zero;
  var extra = Duration.zero;
  var recorded = 0;
  for (final SleepDay(:slept) in days) {
    if (slept == null) continue;
    recorded++;
    if (slept < need) short += need - slept;
    if (slept > need) extra += slept - need;
  }
  return SleepShortfall(
    short: short,
    extra: extra,
    recorded: recorded,
    days: days.length,
  );
}

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

/// Nights with something against nights without it: an outcome measure
/// (how long they slept, or how long falling asleep took), averaged on
/// each side, and how many nights each side has. It says the two go
/// together in these records, not that one causes the other.
class SleepComparison {
  const SleepComparison({
    required this.withCount,
    required this.withoutCount,
    required this.withAverage,
    required this.withoutAverage,
  });

  final int withCount;
  final int withoutCount;

  /// Null when that side has no night.
  final Duration? withAverage;
  final Duration? withoutAverage;

  /// Whether both sides have [minimumNightsPerSide] nights.
  bool get isEnough =>
      withCount >= minimumNightsPerSide && withoutCount >= minimumNightsPerSide;

  /// With minus without; null until [isEnough].
  Duration? get difference => isEnough ? withAverage! - withoutAverage! : null;
}

/// The morning a night ended on, as midnight.
DateTime morningOf(SleepEntry night) =>
    DateTime(night.sleptAt.year, night.sleptAt.month, night.sleptAt.day);

/// The evening before [morning]: the day whose events a night follows.
DateTime eveningBefore(DateTime morning) =>
    DateTime(morning.year, morning.month, morning.day - 1);

/// Total sleep time of a night, the outcome [compareNights] reads unless
/// told otherwise.
Duration? totalSleepOf(SleepEntry night) => night.duration;

/// [nights] split by [hadIt]: true puts a night with the thing, false
/// without it, null leaves it out of the comparison (the thing is not
/// known for that night). [outcome] is what each side is averaged on,
/// total sleep unless given; a night it returns null for is left out.
/// The sides' counts come back even when too few to say anything, so
/// the screen can show how many nights it has.
SleepComparison compareNights(
  List<SleepEntry> nights,
  bool? Function(SleepEntry night) hadIt, {
  Duration? Function(SleepEntry night) outcome = totalSleepOf,
}) {
  final withIt = <Duration>[];
  final without = <Duration>[];
  for (final night in nights) {
    final measured = outcome(night);
    final had = hadIt(night);
    if (measured == null || had == null) continue;
    (had ? withIt : without).add(measured);
  }
  Duration? average(List<Duration> all) => all.isEmpty
      ? null
      : all.fold(Duration.zero, (sum, d) => sum + d) ~/ all.length;
  return SleepComparison(
    withCount: withIt.length,
    withoutCount: without.length,
    withAverage: average(withIt),
    withoutAverage: average(without),
  );
}

/// The estimated caffeine left at the person's usual bedtime before
/// [night]'s morning, from the intakes of the 24 hours before it; null
/// when [usualBedtime] (a time after midnight, as [regularityOf] gives
/// it) is not known. A usual bedtime before noon is after midnight, so
/// it falls on the morning itself, otherwise on the evening before. The
/// usual bedtime, not the night's own, so a late night caffeine caused
/// does not move the night to the low side.
double? caffeineAtUsualBedtime(
  Iterable<CaffeineIntake> intakes,
  DateTime morning,
  Duration? usualBedtime,
) {
  if (usualBedtime == null) return null;
  final day = usualBedtime < const Duration(hours: 12)
      ? morning
      : eveningBefore(morning);
  final bedtime = day.add(usualBedtime);
  return estimatedCaffeineRemaining([
    for (final intake in intakes)
      if (bedtime.difference(intake.at) <= const Duration(hours: 24)) intake,
  ], now: bedtime);
}

/// A night with when its person got into bed and how long falling asleep
/// took: only nights that have both can be set against a bath.
typedef BedNight = ({SleepEntry night, DateTime inBedAt, Duration latency});

/// Baths that ended up to this long before getting into bed are the ones
/// a night is read against; a product rule (research/92f A3).
const bathLookBack = Duration(hours: 6);

/// Minutes between a bath's end and getting into bed in which it counts as
/// a bath before sleep, ends included. The window is a product rule, not
/// a finding: Tai 2021 saw a link between these minutes and shorter
/// falling asleep, in other people.
const bathWindowMinutes = (from: 61, to: 180);

/// [nights] with a bath against nights without one, on how long falling
/// asleep took ([compareNights] on latency). Research/92f A3:
///
/// - No bath ended 0–360 minutes before getting into bed: without.
/// - Any known cold bath in that time: neither side.
/// - Every bath in it ended 61–180 minutes before: with. Warm, hot and
///   unrecorded water count alike.
/// - Otherwise: neither side.
///
/// A night before the first bath on record, [firstBathAt], is left out:
/// nothing was being recorded yet. With [excludeUnrecorded] a night with a
/// bath of unrecorded water is left out too; that is only for checking
/// how much the rule leans on them, and no screen shows it.
BathComparison compareBathNights(
  List<BedNight> nights,
  List<BathEntry> baths, {
  required DateTime? firstBathAt,
  bool excludeUnrecorded = false,
}) {
  final groups = <String, bool?>{};
  final unrecordedOnly = <String>{};
  for (final (:night, :inBedAt, latency: _) in nights) {
    if (firstBathAt == null || inBedAt.isBefore(firstBathAt)) continue;
    final before = [
      for (final bath in baths)
        if (!inBedAt.isBefore(bath.bathedAt) &&
            inBedAt.difference(bath.bathedAt) <= bathLookBack)
          (bath, inBedAt.difference(bath.bathedAt).inMinutes),
    ];
    if (before.isEmpty) {
      groups[night.id] = false;
    } else if (before.any((entry) => entry.$1.water == BathWater.cold) ||
        (excludeUnrecorded && before.any((entry) => entry.$1.water == null)) ||
        before.any(
          (entry) =>
              entry.$2 < bathWindowMinutes.from ||
              entry.$2 > bathWindowMinutes.to,
        )) {
      groups[night.id] = null;
    } else {
      groups[night.id] = true;
      if (before.every((entry) => entry.$1.water == null)) {
        unrecordedOnly.add(night.id);
      }
    }
  }
  final latencies = {for (final bed in nights) bed.night.id: bed.latency};
  final comparison = compareNights(
    [for (final bed in nights) bed.night],
    (night) => groups[night.id],
    outcome: (night) => latencies[night.id],
  );
  return BathComparison(
    comparison: comparison,
    unrecordedOnlyCount: unrecordedOnly
        .where((id) => groups[id] == true)
        .length,
  );
}

/// A [SleepComparison] of baths, with how many of the nights counted as
/// having one rest on baths whose water was not recorded.
class BathComparison {
  const BathComparison({
    required this.comparison,
    required this.unrecordedOnlyCount,
  });

  final SleepComparison comparison;
  final int unrecordedOnlyCount;

  /// Whether more than half the nights with a bath have no water recorded
  /// on any bath, which the screen says beside the figure.
  bool get isMostlyUnrecorded => unrecordedOnlyCount * 2 > comparison.withCount;
}
