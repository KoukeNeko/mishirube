import '../../domain/domain.dart';
import '../engines/activity_metrics.dart';
import '../engines/body_metrics.dart';
import '../engines/insight_engine.dart';
import '../engines/nutrition_summary.dart';
import '../engines/training_metrics.dart';
import '../engines/trend_insights.dart';
import '../engines/trend_engine.dart';
import '../engines/trend_detail.dart';
import '../engines/trend_findings.dart';
import '../engines/workout_review.dart';
import '../storage/activity_sample_repository.dart';
import '../storage/database.dart';
import '../storage/exercise_repository.dart';
import '../storage/journal_repository.dart';
import '../storage/meal_repository.dart';
import '../storage/workout_repository.dart';

/// How far back 「全部」 reads.
const _earliestYear = 2000;

/// Steps' latest stretch and the year they are set against, in weeks.
const _quarterWeeks = 13;
const _yearWeeks = 52;

/// One area's figure week by week, what it is paired with (the scale
/// weight beside the trend, training volume beside workouts, protein
/// beside energy, resting heart rate beside steps), and for sleep when
/// the nights begin and end.
class AreaTrend {
  const AreaTrend({
    required this.domain,
    required this.detail,
    this.secondary,
    this.sleepTimes,
  });

  final TrendDomain domain;
  final TrendDetail detail;
  final TrendDetail? secondary;

  /// Average bedtime and waking over the latest four weeks, in minutes
  /// after midnight.
  final ({double bedtime, double wake})? sleepTimes;
}

/// Days of measured resting energy before it is trusted to catch food
/// missing from the records.
const _minimumBasalDays = 7;

/// Sessions per week the training goal asks for, until goals are editable.
const weeklyTrainingGoal = 3;

/// How many insights the Today screen shows at once.
const _todayInsightCount = 2;

/// Below this many sessions an exercise is not worth a volume insight.
const _minimumSessionsForVolume = 4;

/// What the trends overview needs, all derived from stored records.
class TrendsOverview {
  const TrendsOverview({
    required this.from,
    required this.to,
    required this.weight,
    required this.weeklyWorkouts,
    required this.foodDaysComplete,
    required this.foodDaysTracked,
    required this.averageSleep,
    required this.insights,
  });

  final DateTime from;
  final DateTime to;
  final MeasurementTrend weight;
  final List<WeeklyBar> weeklyWorkouts;

  /// Days in the window whose food log looks complete, out of the days
  /// with any food record at all.
  final int foodDaysComplete;
  final int foodDaysTracked;

  /// Null until sleep is recorded; the screen says so instead of showing 0.
  final Duration? averageSleep;
  final List<Insight> insights;

  int get workoutsThisWeek =>
      weeklyWorkouts.isEmpty ? 0 : weeklyWorkouts.last.$2;
}

/// What the Trends page works out (see `research/56-trends-insights.md`):
/// figures no single chart shows, each null when the records cannot
/// support it; a relation between sleep and training when they do; and
/// each area's long-run line.
class TrendsReport {
  const TrendsReport({
    required this.energy,
    required this.weekendIntake,
    required this.protein,
    required this.training,
    required this.weekendWake,
    required this.relation,
    required this.lines,
    required this.foodDays,
    required this.weighings,
  });

  final EnergyBalance? energy;
  final WeekendGap? weekendIntake;
  final ProteinIntake? protein;
  final TrainingBalance? training;
  final WeekendGap? weekendWake;
  final Insight? relation;
  final List<TrendLine> lines;

  /// Complete food days and weighings in the energy window, for saying
  /// how far short of an estimate the records are.
  final int foodDays;
  final int weighings;

  /// How much of the weekdays' deficit the weekends take back.
  double? get weekendShare => switch ((energy, weekendIntake)) {
    (final energy?, final intake?) => weekendOffset(energy, intake),
    _ => null,
  };
}

/// One exercise's training volume over a window, with the insight it
/// supports.
class VolumeReport {
  const VolumeReport({
    required this.exercise,
    required this.weeklySets,
    required this.sessionCount,
    required this.history,
    this.insight,
  });

  final ExerciseDefinition exercise;
  final List<WeeklyBar> weeklySets;
  final int sessionCount;
  final ExerciseHistory history;
  final Insight? insight;
}

/// Turns stored records into the figures and plain-language insights the
/// Today and Trends screens show. Nothing here is stored: recomputing from
/// the records keeps insights and the log from drifting apart.
class InsightsService {
  InsightsService(
    this._db,
    this._workouts,
    this._exercises,
    this._meals,
    this._journal,
    this._samples,
  );

  final AppDatabase _db;
  final WorkoutRepository _workouts;
  final ExerciseRepository _exercises;
  final MealRepository _meals;
  final JournalRepository _journal;
  final ActivitySampleRepository _samples;

  /// The most recent insights worth surfacing, strongest first.
  List<Insight> today({Duration window = const Duration(days: 28)}) {
    final overview = trends(window: window);
    return overview.insights.take(_todayInsightCount).toList();
  }

  TrendsOverview trends({Duration window = const Duration(days: 28)}) {
    final now = _db.now();
    final from = now.subtract(window);
    final until = _db.nowInclusive;
    final weeks = (window.inDays / DateTime.daysPerWeek).ceil();
    final weight = weightTrend(
      _journal.weightsBetween(from, until),
      now: now,
      window: window,
    );
    final weeklyWorkouts = weeklyCounts(
      _workouts.completedStarts(since: from),
      now: now,
      weeks: weeks,
    );
    final (complete, tracked) = _foodDays(from, until);
    final volume = _volumeReport(window);
    return TrendsOverview(
      from: from,
      to: now,
      weight: weight,
      weeklyWorkouts: weeklyWorkouts,
      foodDaysComplete: complete,
      foodDaysTracked: tracked,
      averageSleep: _averageSleep(from, until),
      insights: [
        ?volume?.insight,
        ?weightTrendInsight(weight, dayCount: window.inDays),
        ?weeklyTrainingInsight(weeklyWorkouts, goalPerWeek: weeklyTrainingGoal),
      ],
    );
  }

  /// What the body burned a day over the [energyWindowDays] up to [day],
  /// from the complete food days and the trend weight; null without
  /// enough of either. The Trends page shows it, and the daily targets
  /// take it as maintenance once the records support it.
  EnergyBalance? energyOn(DateTime day) {
    final now = _db.now();
    final end = DateTime(day.year, day.month, day.day + 1);
    final until = end.isBefore(_db.nowInclusive) ? end : _db.nowInclusive;
    // The weight's trend needs the months before the window to settle;
    // the food needs only the window.
    final weightsFrom = _dayOf(day)
        .subtract(const Duration(days: trendHistoryDays - 1));
    final foodFrom = _dayOf(day)
        .subtract(const Duration(days: energyWindowDays - 1));
    final (:kcal, protein: _, daysTracked: _) = _completeFoodDays(
      foodFrom,
      until,
      now,
    );
    final basal = dailyValues(
      _samples.between(
        ActivityMetric.basalEnergy,
        foodFrom.subtract(const Duration(days: 1)),
        until,
      ),
    );
    return energyBalance(
      completeDays: kcal,
      trendWeights: [
        for (final (at, _, value) in trendOf(
          _journal.weightsBetween(weightsFrom, until),
        ))
          (at, value),
      ],
      today: day,
      basalKcal: basal.length < _minimumBasalDays
          ? null
          : basal.fold(0.0, (sum, day) => sum + day.$2) / basal.length,
    );
  }

  /// The changes worth noticing, a relation between sleep and training
  /// when the records support one, and each area's long-run line, each
  /// read over the last [trendHistoryDays] against its own baseline.
  TrendsReport report() {
    final now = _db.now();
    final from = _dayOf(now)
        .subtract(const Duration(days: trendHistoryDays - 1));
    final until = _db.nowInclusive;
    final nights = [
      for (final entry in _journal.sleepBetween(from, until))
        if (entry.kind == SleepKind.night &&
            entry.measure == SleepMeasure.asleep)
          (entry.sleptAt, entry.duration.inMinutes.toDouble()),
    ];
    final weights = _journal.weightsBetween(from, until);
    final starts = _workouts.completedStarts(since: from);
    final steps = dailyValues(
      _samples.between(ActivityMetric.steps, from, until),
    );
    final (:kcal, :protein, :daysTracked) = _completeFoodDays(from, until, now);
    final trend = [for (final (at, _, value) in trendOf(weights)) (at, value)];
    final energy = energyOn(now);
    final energyStart = _dayOf(now)
        .subtract(const Duration(days: energyWindowDays - 1));
    final recentStart = now.subtract(const Duration(days: patternWindowDays));
    return TrendsReport(
      energy: energy,
      weekendIntake: weekendIntake(kcal, now),
      protein: trend.isEmpty
          ? null
          : proteinIntake(
              completeDayGrams: protein,
              weightKg: trend.last.$2,
              trainingDays: {for (final start in starts) _dayOf(start)},
              today: now,
            ),
      training: trainingBalance(
        muscleLoad(),
        starts.where((start) => start.isAfter(recentStart)).length,
      ),
      weekendWake: weekendWake([for (final (wokeAt, _) in nights) wokeAt], now),
      foodDays: kcal.where((day) => !day.$1.isBefore(energyStart)).length,
      weighings: trend.where((point) => !point.$1.isBefore(energyStart)).length,
      relation: sleepAndTrainingInsight({
        for (final (wokeAt, minutes) in nights) _dayOf(wokeAt): minutes,
      }, _workouts.completedVolumes(since: from)),
      lines: [
        ?bodyLine(weights, now),
        ?trainingLine(starts, now),
        ?sleepLine(nights, now),
        ?nutritionLine(kcal, daysTracked, now),
        ?activityLine(steps, now),
      ],
    );
  }

  /// One area's figure week by week over the last [weeks] weeks, or
  /// every week there are records for when [weeks] is null, with the
  /// figure the area pairs it with.
  AreaTrend areaTrend(TrendDomain domain, {int? weeks}) {
    final now = _db.now();
    final until = _db.nowInclusive;
    final from = weeks == null
        ? DateTime(_earliestYear)
        : _dayOf(now).subtract(Duration(days: weeks * DateTime.daysPerWeek));
    final (daily, aggregate, secondary) = switch (domain) {
      TrendDomain.body => () {
        final weights = _journal.weightsBetween(from, until);
        return (
          [for (final (at, _, value) in trendOf(weights)) (at, value)],
          WeekAggregate.mean,
          [for (final weight in weights) (weight.measuredAt, weight.weightKg)],
        );
      }(),
      TrendDomain.training => (
        [
          for (final start in _workouts.completedStarts(since: from))
            (start, 1.0),
        ],
        WeekAggregate.sum,
        [
          for (final (start, _, volume) in _workouts.completedVolumes(
            since: from,
          ))
            (start, volume),
        ],
      ),
      TrendDomain.sleep => (
        [
          for (final (wokeAt, minutes, _) in _nights(from, until))
            (wokeAt, minutes),
        ],
        WeekAggregate.mean,
        null,
      ),
      TrendDomain.nutrition => () {
        final (:kcal, :protein, daysTracked: _) = _completeFoodDays(
          from,
          until,
          now,
        );
        return (kcal, WeekAggregate.mean, protein);
      }(),
      TrendDomain.activity => (
        dailyValues(_samples.between(ActivityMetric.steps, from, until)),
        WeekAggregate.mean,
        dailyValues(
          _samples.between(ActivityMetric.restingHeartRate, from, until),
        ),
      ),
    };
    final span =
        weeks ??
        switch (daily
            .map((day) => day.$1)
            .fold<DateTime?>(
              null,
              (first, at) => first == null || at.isBefore(first) ? at : first,
            )) {
          final first? =>
            (_dayOf(now).difference(_dayOf(first)).inDays ~/
                    DateTime.daysPerWeek +
                1),
          null => 1,
        };
    // Steps are set against the year, as their long-run line is.
    final isYearly = domain == TrendDomain.activity;
    TrendDetail detailOf(
      List<(DateTime, double)> values,
      WeekAggregate aggregate,
    ) => trendDetail(
      values,
      now,
      weeks: span,
      aggregate: aggregate,
      recentWeeks: isYearly ? _quarterWeeks : trendWindowDays ~/ 7,
      baselineWeeks: isYearly ? _yearWeeks : 3 * trendWindowDays ~/ 7,
      baselineIncludesRecent: isYearly,
    );

    return AreaTrend(
      domain: domain,
      detail: detailOf(daily, aggregate),
      secondary: secondary == null
          ? null
          : detailOf(
              secondary,
              domain == TrendDomain.training
                  ? WeekAggregate.sum
                  : WeekAggregate.mean,
            ),
      sleepTimes: domain == TrendDomain.sleep
          ? _sleepTimes(
              _nights(
                now.subtract(const Duration(days: trendWindowDays)),
                until,
              ),
            )
          : null,
    );
  }

  /// Nights asleep from [from]: when each ended, how long it was, and
  /// when it began.
  List<(DateTime, double, DateTime)> _nights(DateTime from, DateTime until) => [
    for (final entry in _journal.sleepBetween(from, until))
      if (entry.kind == SleepKind.night && entry.measure == SleepMeasure.asleep)
        (
          entry.sleptAt,
          entry.duration.inMinutes.toDouble(),
          entry.startedAt ?? entry.sleptAt.subtract(entry.duration),
        ),
  ];

  /// The average bedtime and waking over [nights], in minutes after
  /// midnight; null without any. Averaged around noon, so 23:30 and
  /// 00:30 average to midnight rather than to noon.
  static ({double bedtime, double wake})? _sleepTimes(
    List<(DateTime, double, DateTime)> nights,
  ) {
    if (nights.isEmpty) return null;
    const day = Duration.minutesPerDay;
    double average(Iterable<DateTime> times) {
      final shifted = [
        for (final time in times)
          (time.hour * 60 + time.minute + day / 2) % day,
      ];
      return (shifted.reduce((a, b) => a + b) / shifted.length - day / 2) % day;
    }

    return (
      bedtime: average([for (final (_, _, began) in nights) began]),
      wake: average([for (final (woke, _, _) in nights) woke]),
    );
  }

  static DateTime _dayOf(DateTime time) =>
      DateTime(time.year, time.month, time.day);

  /// Energy and protein eaten on each complete day from [from], and how
  /// many days in the latest stretch have any food record. Today is
  /// never complete: it is not over.
  ({
    List<(DateTime, double)> kcal,
    List<(DateTime, double)> protein,
    int daysTracked,
  })
  _completeFoodDays(DateTime from, DateTime until, DateTime now) {
    final byDay = <DateTime, List<MealEvent>>{};
    for (final (eatenAt, meal) in _meals.between(from, until)) {
      (byDay[_dayOf(eatenAt)] ??= []).add(meal);
    }
    final today = _dayOf(now);
    final recentStart = today.subtract(
      const Duration(days: trendWindowDays - 1),
    );
    final kcal = <(DateTime, double)>[];
    final protein = <(DateTime, double)>[];
    for (final day in byDay.keys.toList()..sort()) {
      final summary = summariseDay(byDay[day]!, isOver: day.isBefore(today));
      if (!summary.isComplete) continue;
      kcal.add((day, summary.kcal.toDouble()));
      protein.add((day, summary.proteinGrams.toDouble()));
    }
    return (
      kcal: kcal,
      protein: protein,
      daysTracked: byDay.keys.where((day) => !day.isBefore(recentStart)).length,
    );
  }

  /// Working sets per muscle per week over [window], most trained first.
  /// Empty until something has been trained; an empty chart says more
  /// than a row of zeros.
  List<(MuscleGroup, int)> muscleLoad({
    Duration window = const Duration(days: 28),
  }) {
    final counts = _exercises.setCountsByExercise(_db.now().subtract(window));
    return weeklySetsByMuscle([
      for (final (id, sets) in counts)
        if (_exercises.byId(id) case final exercise?) (exercise, sets),
    ], weeks: (window.inDays / DateTime.daysPerWeek).ceil());
  }

  /// Working sets per muscle in each of the last [weeks] weeks.
  List<(MuscleGroup, List<WeeklyBar>)> muscleWeeks({int weeks = 8}) =>
      weeklySetsPerMuscle(
        [
          for (final exercise in _exercises.all())
            if (exercise.recordCount > 0)
              (exercise, _exercises.sessionSetCounts(exercise.id)),
        ],
        now: _db.now(),
        weeks: weeks,
      );

  /// Every exercise that has been trained, with its history, the most
  /// recently trained first.
  List<(ExerciseDefinition, ExerciseHistory)> exerciseHistories() => [
    for (final exercise in _exercises.all())
      if (exercise.recordCount > 0) (exercise, _exercises.history(exercise.id)),
  ]..sort((a, b) => b.$2.last!.date.compareTo(a.$2.last!.date));

  /// Every exercise's bests, the most recently set first.
  List<ExerciseBests> personalRecords() => [
    for (final exercise in _exercises.all())
      if (exercise.recordCount > 0)
        ?bestsOf(exercise, _exercises.history(exercise.id)),
  ]..sort((a, b) => b.latest.compareTo(a.latest));

  /// Volume for one exercise, or for the most trained one when [exerciseId]
  /// is null.
  VolumeReport? volumeReport({
    String? exerciseId,
    Duration window = const Duration(days: 28),
  }) => exerciseId == null
      ? _volumeReport(window)
      : _reportFor(_exercises.byId(exerciseId)!, window);

  /// The exercise worth reporting on: one whose volume changed enough to
  /// say something, otherwise simply the most trained one.
  VolumeReport? _volumeReport(Duration window) {
    final reports = [
      for (final exercise in _exercises.all())
        if (_reportFor(exercise, window) case final report?
            when report.sessionCount >= _minimumSessionsForVolume)
          report,
    ]..sort((a, b) => b.sessionCount.compareTo(a.sessionCount));
    if (reports.isEmpty) return null;
    return reports.firstWhere(
      (report) => report.insight != null,
      orElse: () => reports.first,
    );
  }

  VolumeReport? _reportFor(ExerciseDefinition exercise, Duration window) {
    final now = _db.now();
    final from = now.subtract(window);
    final sessions = _exercises
        .sessionSetCounts(exercise.id)
        .where((session) => !session.$1.isBefore(from))
        .toList();
    if (sessions.isEmpty) return null;
    final weeks = (window.inDays / DateTime.daysPerWeek).ceil();
    final weeklySets = weeklySums(sessions, now: now, weeks: weeks);
    final history = _exercises.history(exercise.id);
    return VolumeReport(
      exercise: exercise,
      weeklySets: weeklySets,
      sessionCount: sessions.length,
      history: history,
      insight: volumeTrendInsight(
        exercise.name,
        weeklySets,
        sessionCount: sessions.length,
        isMaxHolding: _isMaxHolding(history, from, now),
      ),
    );
  }

  /// Whether the estimated max in the second half of the window is at
  /// least as high as in the first half.
  bool _isMaxHolding(ExerciseHistory history, DateTime from, DateTime to) {
    final middle = from.add(to.difference(from) ~/ 2);
    double? best(bool Function(DateTime date) when) {
      double? value;
      for (final entry in history.recent) {
        if (!when(entry.date)) continue;
        final estimate = estimateOneRepMax(entry.weightKg, entry.reps);
        if (estimate != null && estimate > (value ?? 0)) value = estimate;
      }
      return value;
    }

    final earlier = best(
      (date) => date.isBefore(middle) && !date.isBefore(from),
    );
    final later = best((date) => !date.isBefore(middle));
    if (earlier == null || later == null) return true;
    return later >= earlier;
  }

  /// The mean night in the window, or null while nothing is logged: an
  /// average of no nights is not zero sleep.
  ///
  /// Only nights measured as time asleep count: a nap is not a night, and
  /// time in bed is not sleep.
  Duration? _averageSleep(DateTime from, DateTime to) {
    final nights = [
      for (final entry in _journal.sleepBetween(from, to))
        if (entry.kind == SleepKind.night &&
            entry.measure == SleepMeasure.asleep)
          entry,
    ];
    if (nights.isEmpty) return null;
    final total = nights.fold(
      Duration.zero,
      (sum, night) => sum + night.duration,
    );
    return total ~/ nights.length;
  }

  /// Days with a food record in the window, and how many of them look
  /// complete.
  (int, int) _foodDays(DateTime from, DateTime to) {
    final byDay = <DateTime, List<MealEvent>>{};
    for (final (eatenAt, meal) in _meals.between(from, to)) {
      final day = DateTime(eatenAt.year, eatenAt.month, eatenAt.day);
      (byDay[day] ??= []).add(meal);
    }
    final today = DateTime(to.year, to.month, to.day);
    var complete = 0;
    for (final MapEntry(key: day, value: meals) in byDay.entries) {
      final summary = summariseDay(meals, isOver: day.isBefore(today));
      if (summary.isComplete) complete++;
    }
    return (complete, byDay.length);
  }
}
