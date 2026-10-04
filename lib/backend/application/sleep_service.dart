import '../../domain/domain.dart';
import '../engines/activity_metrics.dart';
import '../engines/caffeine.dart';
import '../engines/nutrition_summary.dart';
import '../engines/sleep_metrics.dart';
import '../engines/sleep_nights.dart';
import '../storage/activity_sample_repository.dart';
import '../storage/database.dart';
import '../storage/journal_repository.dart';
import '../storage/meal_repository.dart';
import '../storage/workout_repository.dart';

/// A late meal: the hour of the day after which one counts.
const _lateMealHour = 21;

/// Nights that factors are compared over.
const _factorWindow = Duration(days: 90);

/// What [SleepService.factors] set nights against. Each is the nights
/// after days with the thing against the others; [SleepComparison.isEnough]
/// says whether the sides are big enough to show a difference.
class SleepFactors {
  const SleepFactors({
    required this.training,
    required this.caffeineAtBedtime,
    required this.lateMeal,
    required this.nap,
    required this.bath,
    required this.daylight,
  });

  final SleepComparison training;

  /// Null when the usual bedtime cannot be worked out.
  final SleepComparison? caffeineAtBedtime;

  final SleepComparison lateMeal;
  final SleepComparison nap;

  /// On how long falling asleep took, not total sleep; only nights with
  /// a time in bed have one.
  final BathComparison bath;

  /// Nights have no side where no day has a daylight reading, so it is
  /// then a comparison of no nights.
  final SleepComparison daylight;
}

/// One sleep as the sleep page shows it.
class SleepRecord {
  const SleepRecord({
    required this.entry,
    required this.origin,
    required this.stages,
    required this.sources,
    required this.shownSource,
    required this.readings,
    required this.continuity,
  });

  final SleepEntry entry;

  /// How the record reached the log: typed in here, or read from a
  /// health platform.
  final ChangeSource origin;

  /// The shown source's stretches, in time order, "in bed" left out when
  /// it recorded anything more specific. Empty for a length typed in.
  final List<SleepSample> stages;

  /// Every source that recorded this sleep.
  final List<SleepSummary> sources;

  /// The source [entry]'s figures come from; null for a length typed in.
  final SleepSummary? shownSource;

  final List<OvernightReading> readings;

  /// How the sleep held together, from the shown source; null for a
  /// length typed in.
  final SleepContinuity? continuity;

  /// Whether the source staged the sleep, so there is a chart to draw.
  bool get hasStages => stages.any((stage) => stage.stage.isDetailed);

  bool get isTypedIn => origin == ChangeSource.local;
}

/// The sleep page's reads, and the one choice it makes: which source a
/// sleep is shown from.
class SleepService {
  SleepService(
    this._db,
    this._journal,
    this._workouts,
    this._meals,
    this._activitySamples,
  );

  final AppDatabase _db;
  final JournalRepository _journal;
  final WorkoutRepository _workouts;
  final MealRepository _meals;
  final ActivitySampleRepository _activitySamples;

  static const _goalKey = 'sleep.goal_minutes';

  /// How long a night the user aims for; null until they set one.
  Duration? get goal => switch (int.tryParse(_db.setting(_goalKey) ?? '')) {
    final minutes? when minutes > 0 => Duration(minutes: minutes),
    _ => null,
  };

  void setGoal(Duration? goal) =>
      _db.setSetting(_goalKey, goal == null ? '' : '${goal.inMinutes}');

  static const _targetBedtimeKey = 'sleep.target_bedtime';
  static const _targetWakeKey = 'sleep.target_wake';

  /// When the user aims to fall asleep and to wake, in minutes after
  /// midnight; null until set. Off until the user picks the times: the
  /// evidence is for keeping to a schedule, not for any particular one
  /// (research/85).
  int? get targetBedtime => int.tryParse(_db.setting(_targetBedtimeKey) ?? '');
  int? get targetWake => int.tryParse(_db.setting(_targetWakeKey) ?? '');

  void setTargetBedtime(int? minutes) =>
      _db.setSetting(_targetBedtimeKey, minutes == null ? '' : '$minutes');

  void setTargetWake(int? minutes) =>
      _db.setSetting(_targetWakeKey, minutes == null ? '' : '$minutes');

  /// The night each day is read against: the goal, or [defaultSleepNeed]
  /// until one is set.
  Duration get need => goal ?? defaultSleepNeed;

  /// Each of the [count] days ending with [last], oldest first, with its
  /// time asleep.
  List<SleepDay> sleepDays(DateTime last, int count) {
    final first = DateTime(last.year, last.month, last.day - count + 1);
    return sleepDaysOf(
      _journal.sleepBetween(
        first,
        DateTime(last.year, last.month, last.day + 1),
      ),
      first,
      count,
    );
  }

  /// When to sleep tonight for the goal and wake as usual; null without
  /// a goal or enough recent nights to have a usual waking.
  ({DateTime bedtime, DateTime wake})? tonightPlan() {
    final goal = this.goal;
    if (goal == null) return null;
    final now = _db.now();
    final asleep = [
      for (final night in nights(
        now.subtract(const Duration(days: 14)),
        _db.nowInclusive,
      ))
        if (night.measure == SleepMeasure.asleep) night,
    ];
    return tonight(asleep, goal, now: now);
  }

  static const _reminderKey = 'sleep.reminder';

  /// How long before the suggested bedtime the reminder comes.
  static const reminderLead = Duration(minutes: 30);

  bool get isReminderOn => _db.setting(_reminderKey) == 'true';

  void setReminder(bool isOn) => _db.setSetting(_reminderKey, '$isOn');

  /// When the bedtime reminder should come each day; null when it is off
  /// or there is no bedtime to remind of.
  DateTime? reminderTime() {
    if (!isReminderOn) return null;
    return tonightPlan()?.bedtime.subtract(reminderLead);
  }

  /// The time in each stage averaged over the staged nights that ended
  /// in `[start, end)`, from each night's shown source, with how many
  /// nights that is; nights the source did not stage are left out.
  ({Map<SleepStage, Duration> stages, int nights}) averageStages(
    DateTime start,
    DateTime end,
  ) {
    final totals = <SleepStage, Duration>{};
    var staged = 0;
    for (final night in nights(start, end)) {
      final record = _recordOf(night);
      if (!record.hasStages) continue;
      staged++;
      for (final MapEntry(key: stage, value: time) in stageTotals(
        record.stages,
      ).entries) {
        totals.update(stage, (sum) => sum + time, ifAbsent: () => time);
      }
    }
    return (
      stages: {
        for (final MapEntry(key: stage, value: time) in totals.entries)
          stage: time ~/ staged,
      },
      nights: staged,
    );
  }

  /// Each staged night that ended in `[start, end)`, oldest first: its
  /// morning, the time in each stage from its shown source, and its
  /// efficiency when the source also recorded time in bed. Nights the
  /// source did not stage are left out.
  List<
    ({DateTime morning, Map<SleepStage, Duration> stages, double? efficiency})
  >
  nightlyStages(DateTime start, DateTime end) => [
    for (final night in nights(start, end))
      if (_recordOf(night) case final record when record.hasStages)
        (
          morning: night.sleptAt,
          stages: stageTotals(record.stages),
          efficiency: record.continuity?.efficiency,
        ),
  ];

  /// Each night's average of [measure] over `[start, end)` with the
  /// morning it belongs to, oldest first: what a night's reading is
  /// compared against, and its trend.
  List<(DateTime, double)> nightlyAverages(
    OvernightMeasure measure,
    DateTime start,
    DateTime end,
  ) => [
    for (final night in nights(start, end))
      for (final reading in _journal.sleepReadings(night.id))
        if (reading.measure == measure) (night.sleptAt, reading.average),
  ];

  /// Nights that ended in `[start, end)` with time asleep measured.
  List<SleepEntry> _asleepNights(DateTime start, DateTime end) => [
    for (final night in nights(start, end))
      if (night.measure == SleepMeasure.asleep) night,
  ];

  /// The usual bedtime over the last [_factorWindow] ([regularityOf]), as
  /// a time after midnight; null below [minimumNightsForRegularity]
  /// nights that say when they began. The one bedtime the caffeine
  /// factor and the caffeine page read caffeine against.
  Duration? usualBedtime() {
    final end = _db.nowInclusive;
    return regularityOf(_asleepNights(end.subtract(_factorWindow), end))
        ?.bedtime;
  }

  /// Nights asleep over the last [_factorWindow] set against what the day
  /// before held: training, estimated caffeine at the usual bedtime, a
  /// late meal, a nap and time in daylight. Total sleep is what each is
  /// compared on.
  SleepFactors factors() {
    final end = _db.nowInclusive;
    final start = end.subtract(_factorWindow);
    final asleep = _asleepNights(start, end);
    DateTime dayOf(DateTime time) => DateTime(time.year, time.month, time.day);
    // A night belongs to the evening before its morning.
    DateTime eveningOf(SleepEntry night) => eveningBefore(morningOf(night));

    final trained = {
      for (final started in _workouts.completedStarts(since: start))
        dayOf(started),
    };

    // Caffeine from the day before the window on, to reach back from its
    // first bedtime.
    final meals = _meals.between(start.subtract(const Duration(days: 2)), end);
    final mealsByDay = <DateTime, List<MealEvent>>{};
    final lateMeal = <DateTime>{};
    for (final (eatenAt, meal) in meals) {
      (mealsByDay[dayOf(eatenAt)] ??= []).add(meal);
      if (eatenAt.hour >= _lateMealHour) lateMeal.add(dayOf(eatenAt));
    }
    final intakes = caffeineIntakes(meals);
    final usualBedtime = regularityOf(asleep)?.bedtime;
    bool? caffeineAtBedtime(SleepEntry night) {
      final remaining = caffeineAtUsualBedtime(
        intakes,
        morningOf(night),
        usualBedtime,
      );
      if (remaining == null) return null;
      if (remaining >= caffeineBedtimeReferenceMg) return true;
      // Nothing seen is only "none" on a day that was logged in full.
      final day = mealsByDay[eveningOf(night)];
      return day != null && summariseDay(day).isComplete ? false : null;
    }

    final naps = [
      for (final entry in _journal.sleepBetween(
        start.subtract(const Duration(days: 1)),
        end,
      ))
        if (entry.kind == SleepKind.nap &&
            entry.measure == SleepMeasure.asleep &&
            entry.duration >= minNapSleep)
          entry,
    ];
    bool hadNap(SleepEntry night) {
      final evening = eveningOf(night);
      return naps.any(
        (nap) =>
            dayOf(nap.sleptAt) == evening &&
            (night.startedAt == null || !nap.sleptAt.isAfter(night.startedAt!)),
      );
    }

    // Today is still going, so its daylight is not a day yet.
    final lastDay = dayOf(end).subtract(const Duration(days: 1));
    final daylightByDay = {
      for (final (day, minutes) in dailyValues(
        _activitySamples.between(
          ActivityMetric.timeInDaylight,
          dayOf(start),
          lastDay.add(const Duration(days: 1)),
        ),
      ))
        day: minutes,
    };
    final sorted = daylightByDay.values.toList()..sort();
    final middle = sorted.length ~/ 2;
    // Without a reading no night has a side, so the median is not used.
    final median = sorted.isEmpty
        ? 0
        : sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
    final daylight = compareNights(asleep, (night) {
      final minutes = daylightByDay[eveningOf(night)];
      return minutes == null ? null : minutes > median;
    });

    // A bath's window reaches back from getting into bed.
    final baths = _journal.bathsBetween(
      start.subtract(bathLookBack + const Duration(days: 1)),
      end,
    );
    final bedNights = <BedNight>[];
    for (final night in asleep) {
      final continuity = _continuityOf(night);
      if (continuity case SleepContinuity(:final inBedAt?, :final latency?)) {
        bedNights.add((night: night, inBedAt: inBedAt, latency: latency));
      }
    }

    return SleepFactors(
      training: compareNights(
        asleep,
        (night) => trained.contains(eveningOf(night)),
      ),
      caffeineAtBedtime: usualBedtime == null
          ? null
          : compareNights(asleep, caffeineAtBedtime),
      lateMeal: compareNights(
        asleep,
        (night) => lateMeal.contains(eveningOf(night)),
      ),
      nap: compareNights(asleep, hadNap),
      bath: compareBathNights(
        bedNights,
        baths,
        firstBathAt: _journal.firstBathAt(),
      ),
      daylight: daylight,
    );
  }

  /// The sleeps logged against [day]: its night first, then its naps.
  List<SleepRecord> day(DateTime day) {
    final entries = _journal.sleepOn(day)
      ..sort((a, b) {
        if (a.kind != b.kind) return a.kind.index.compareTo(b.kind.index);
        return a.sleptAt.compareTo(b.sleptAt);
      });
    return [for (final entry in entries) _recordOf(entry)];
  }

  /// Time asleep in the naps logged against [day].
  Duration napTimeOn(DateTime day) => [
    for (final entry in _journal.sleepOn(day))
      if (entry.kind == SleepKind.nap) entry.duration,
  ].fold(Duration.zero, (sum, time) => sum + time);

  /// The latest night, when it ended today or yesterday; older than that
  /// it is not last night.
  SleepRecord? lastNight() {
    final start = today.subtract(const Duration(days: 1));
    final night = nights(start, _db.nowInclusive).lastOrNull;
    return night == null ? null : _recordOf(night);
  }

  /// Nights (not naps) that ended in `[start, end)`, oldest first.
  List<SleepEntry> nights(DateTime start, DateTime end) => [
    for (final entry in _journal.sleepBetween(start, end))
      if (entry.kind == SleepKind.night) entry,
  ];

  /// Shows [id] from [source], which must have recorded it. The choice is
  /// kept, so reading the platform again keeps showing that source.
  void chooseSource(String id, String source) {
    final row = _journal.sleepRow(id);
    if (row == null || row.isDeleted) return;
    final samples = _journal.sleepSegments(id);
    if (!samples.any((sample) => sample.source == source)) return;
    final summary = summarize(samples, source: source)!;
    final entry = row.entry;
    _journal.resyncSleep(
      SleepEntry(
        id: id,
        sleptAt: summary.end,
        duration: Duration(minutes: summary.length.inMinutes),
        score: entry.score,
        note: entry.note,
        startedAt: summary.start,
        // As the data gave it, not as the user set it.
        kind: row.derivedKind,
        measure: summary.measure,
        sourceName: summary.sourceName,
      ),
      source: ChangeSource.local,
      chosenSource: source,
    );
  }

  SleepRecord _recordOf(SleepEntry entry) {
    final samples = _journal.sleepSegments(entry.id);
    final origin = _journal.sourceOf(entry.id) ?? ChangeSource.local;
    final shown = _shownOf(entry, samples);
    return SleepRecord(
      entry: entry,
      origin: origin,
      stages: shown == null ? const [] : stagesOf(samples, shown.source),
      sources: sourcesOf(samples),
      shownSource: shown,
      readings: _journal.sleepReadings(entry.id),
      continuity: _continuityIn(samples, shown),
    );
  }

  /// The source [entry] is shown from, among those that recorded it.
  SleepSummary? _shownOf(SleepEntry entry, List<SleepSample> samples) =>
      samples.isEmpty
      ? null
      : summarize(samples, source: _journal.chosenSleepSource(entry.id));

  SleepContinuity? _continuityIn(
    List<SleepSample> samples,
    SleepSummary? shown,
  ) => shown == null
      ? null
      : continuityOf([
          for (final sample in samples)
            if (sample.source == shown.source) sample,
        ]);

  SleepContinuity? _continuityOf(SleepEntry entry) {
    final samples = _journal.sleepSegments(entry.id);
    return _continuityIn(samples, _shownOf(entry, samples));
  }

  /// Today, for a page that opens on the latest night.
  DateTime get today {
    final now = _db.now();
    return DateTime(now.year, now.month, now.day);
  }
}
