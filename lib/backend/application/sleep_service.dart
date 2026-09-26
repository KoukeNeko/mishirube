import '../../domain/domain.dart';
import '../engines/sleep_metrics.dart';
import '../engines/sleep_nights.dart';
import '../storage/database.dart';
import '../storage/journal_repository.dart';
import '../storage/meal_repository.dart';
import '../storage/workout_repository.dart';

/// A late meal, and caffeine late enough to still be around at bedtime:
/// the hours of the day after which each counts.
const _lateMealHour = 21;
const _lateCaffeineHour = 14;

/// Nights that factors are compared over.
const _factorWindow = Duration(days: 90);

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
  SleepService(this._db, this._journal, this._workouts, this._meals);

  final AppDatabase _db;
  final JournalRepository _journal;
  final WorkoutRepository _workouts;
  final MealRepository _meals;

  static const _goalKey = 'sleep.goal_minutes';

  /// How long a night the user aims for; null until they set one.
  Duration? get goal => switch (int.tryParse(_db.setting(_goalKey) ?? '')) {
    final minutes? when minutes > 0 => Duration(minutes: minutes),
    _ => null,
  };

  void setGoal(Duration? goal) =>
      _db.setSetting(_goalKey, goal == null ? '' : '${goal.inMinutes}');

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

  /// Nights asleep over the last [_factorWindow] set against what the day
  /// before held: training, caffeine late in the day, a late meal. Each
  /// is null until both sides have enough nights.
  ({
    SleepComparison? training,
    SleepComparison? lateCaffeine,
    SleepComparison? lateMeal,
  })
  factors() {
    final end = _db.nowInclusive;
    final start = end.subtract(_factorWindow);
    final asleep = [
      for (final night in nights(start, end))
        if (night.measure == SleepMeasure.asleep) night,
    ];
    DateTime dayOf(DateTime time) => DateTime(time.year, time.month, time.day);
    final trained = {
      for (final started in _workouts.completedStarts(since: start))
        dayOf(started),
    };
    final lateCaffeine = <DateTime>{};
    final lateMeal = <DateTime>{};
    for (final (eatenAt, meal) in _meals.between(start, end)) {
      if (eatenAt.hour >= _lateMealHour) lateMeal.add(dayOf(eatenAt));
      if (eatenAt.hour >= _lateCaffeineHour &&
          (meal.nutrients[Nutrient.caffeine] ?? 0) > 0) {
        lateCaffeine.add(dayOf(eatenAt));
      }
    }
    // A night belongs to the evening before its morning.
    DateTime eveningOf(DateTime morning) =>
        DateTime(morning.year, morning.month, morning.day - 1);
    return (
      training: compareNights(
        asleep,
        (morning) => trained.contains(eveningOf(morning)),
      ),
      lateCaffeine: compareNights(
        asleep,
        (morning) => lateCaffeine.contains(eveningOf(morning)),
      ),
      lateMeal: compareNights(
        asleep,
        (morning) => lateMeal.contains(eveningOf(morning)),
      ),
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
        kind: entry.kind,
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
    final shown = samples.isEmpty
        ? null
        : summarize(samples, source: _journal.chosenSleepSource(entry.id));
    return SleepRecord(
      entry: entry,
      origin: origin,
      stages: shown == null ? const [] : stagesOf(samples, shown.source),
      sources: sourcesOf(samples),
      shownSource: shown,
      readings: _journal.sleepReadings(entry.id),
      continuity: shown == null
          ? null
          : continuityOf([
              for (final sample in samples)
                if (sample.source == shown.source) sample,
            ]),
    );
  }

  /// Today, for a page that opens on the latest night.
  DateTime get today {
    final now = _db.now();
    return DateTime(now.year, now.month, now.day);
  }
}
