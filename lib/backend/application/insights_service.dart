import '../../domain/domain.dart';
import '../engines/activity_metrics.dart';
import '../engines/insight_engine.dart';
import '../engines/nutrition_summary.dart';
import '../engines/training_metrics.dart';
import '../engines/trend_engine.dart';
import '../engines/trend_findings.dart';
import '../engines/workout_review.dart';
import '../storage/activity_sample_repository.dart';
import '../storage/database.dart';
import '../storage/exercise_repository.dart';
import '../storage/journal_repository.dart';
import '../storage/meal_repository.dart';
import '../storage/workout_repository.dart';

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

/// What the Trends page says: the changes worth noticing, strongest
/// first; a relation between two areas when the records support one;
/// and each area's long-run line.
class TrendsReport {
  const TrendsReport({
    required this.findings,
    required this.relation,
    required this.lines,
  });

  final List<({TrendDomain domain, Insight insight})> findings;
  final Insight? relation;
  final List<TrendLine> lines;

  /// Every figure said above, one line each, for a writer to put into
  /// words without adding any.
  List<String> get facts => [
    for (final finding in findings) finding.insight.statement,
    ?relation?.statement,
    for (final line in lines)
      '${line.domain.label}：${line.value}'
          '${line.change == null ? '' : '，${line.change}'}',
  ];
}

/// How many changes the Trends page leads with.
const _findingCount = 3;

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

  /// The changes worth noticing, a relation between sleep and training
  /// when the records support one, and each area's long-run line, over
  /// the latest [trendWindowDays] and the stretch before.
  TrendsReport report() {
    final now = _db.now();
    final from = _dayOf(now)
        .subtract(const Duration(days: trendLineWeeks * DateTime.daysPerWeek));
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
    final restingHeartRate = dailyValues(
      _samples.between(ActivityMetric.restingHeartRate, from, until),
    );
    final (completeDays, daysTracked) = _completeFoodDays(from, until, now);
    final findings = [
      ?weightFinding(weights, now),
      ?trainingFinding(starts, now),
      ?strengthFinding([
        for (final exercise in _exercises.all())
          if (exercise.recordCount > 0)
            (exercise.name, _exercises.history(exercise.id)),
      ], now),
      ?sleepFinding(nights, now),
      ?intakeFinding(completeDays, now),
      ?stepsFinding(steps, now),
      ?restingHeartRateFinding(restingHeartRate, now),
    ]..sort((a, b) => b.strength.compareTo(a.strength));
    return TrendsReport(
      findings: [
        for (final finding in findings.take(_findingCount))
          (domain: finding.domain, insight: finding.insight),
      ],
      relation: sleepAndTrainingInsight({
        for (final (wokeAt, minutes) in nights) _dayOf(wokeAt): minutes,
      }, _workouts.completedVolumes(since: from)),
      lines: [
        ?bodyLine(weights, now),
        ?trainingLine(starts, now),
        ?sleepLine(nights, now),
        ?nutritionLine(completeDays, daysTracked, now),
        ?activityLine(steps, now),
      ],
    );
  }

  static DateTime _dayOf(DateTime time) =>
      DateTime(time.year, time.month, time.day);

  /// Energy eaten on each complete day from [from], and how many days in
  /// the latest stretch have any food record. Today is never complete:
  /// it is not over.
  (List<(DateTime, double)>, int) _completeFoodDays(
    DateTime from,
    DateTime until,
    DateTime now,
  ) {
    final byDay = <DateTime, List<MealEvent>>{};
    for (final (eatenAt, meal) in _meals.between(from, until)) {
      (byDay[_dayOf(eatenAt)] ??= []).add(meal);
    }
    final today = _dayOf(now);
    final recentStart = today.subtract(
      const Duration(days: trendWindowDays - 1),
    );
    final complete = <(DateTime, double)>[];
    for (final MapEntry(key: day, value: meals) in byDay.entries) {
      final summary = summariseDay(meals, isOver: day.isBefore(today));
      if (summary.isComplete) complete.add((day, summary.kcal.toDouble()));
    }
    complete.sort((a, b) => a.$1.compareTo(b.$1));
    return (
      complete,
      byDay.keys.where((day) => !day.isBefore(recentStart)).length,
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
