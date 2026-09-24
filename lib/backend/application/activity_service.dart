import '../../domain/domain.dart';
import '../engines/activity_metrics.dart';
import '../engines/trend_engine.dart';
import '../storage/activity_repository.dart';
import '../storage/activity_sample_repository.dart';
import '../storage/database.dart';

/// What the form starts from when nothing was logged before.
const defaultActivityDuration = Duration(minutes: 30);

/// A window's worth of exercise, for the trends card.
class ActivitySummary {
  const ActivitySummary({
    required this.sessions,
    required this.time,
    required this.weekly,
    required this.weeklyMinutes,
  });

  static const empty = ActivitySummary(
    sessions: 0,
    time: Duration.zero,
    weekly: [],
    weeklyMinutes: [],
  );

  final int sessions;
  final Duration time;

  /// Sessions per week, oldest first, ending with this week.
  final List<WeeklyBar> weekly;

  /// Minutes per week over the same weeks as [weekly].
  final List<WeeklyBar> weeklyMinutes;

  bool get hasRecords => sessions > 0;

  int get thisWeek => weekly.isEmpty ? 0 : weekly.last.$2;

  int get minutesThisWeek => weeklyMinutes.isEmpty ? 0 : weeklyMinutes.last.$2;

  /// Minutes in a normal week, for saying whether this week is unusual.
  /// Null until enough weeks have finished to have a normal.
  int? get typicalWeeklyMinutes => typicalWeeklyAmount(weeklyMinutes);
}

/// Logging general exercise, and reading what a health platform counted
/// and measured about everyday movement.
class ActivityService {
  ActivityService(this._db, this._activities, this._samples);

  final AppDatabase _db;
  final ActivityRepository _activities;
  final ActivitySampleRepository _samples;

  /// Records a session. [startedAt] is when it began; the caller works out
  /// the start from the end and the duration, since that is how people
  /// remember it.
  ActivitySession log({
    required ActivityType type,
    required DateTime startedAt,
    required Duration duration,
    double? distanceMeters,
    double? elevationGainMeters,
    int? effort,
    String note = '',
  }) {
    final activity = ActivitySession(
      id: _db.newId(),
      type: type,
      startedAt: startedAt,
      duration: duration,
      distanceMeters: distanceMeters,
      elevationGainMeters: elevationGainMeters,
      effort: effort,
      note: note,
    );
    _activities.add(activity);
    return activity;
  }

  /// The session being timed right now, if any.
  LiveActivity? active() => _activities.active();

  /// Starts timing [type] from now.
  LiveActivity start(ActivityType type) {
    final live = LiveActivity(
      id: _db.newId(),
      type: type,
      startedAt: _db.now(),
    );
    _activities.start(live);
    return live;
  }

  /// Pauses a running session, or picks it up again.
  void togglePause(LiveActivity live) {
    if (live.pausedAt case final pausedAt?) {
      live.pausedTotal += _db.now().difference(pausedAt);
      live.pausedAt = null;
    } else {
      live.pausedAt = _db.now();
    }
    _activities.savePause(live);
  }

  /// Stops [live] and keeps it as a record of what was done. The length
  /// is the time it actually ran, so a pause does not count.
  ActivitySession finish(
    LiveActivity live, {
    double? distanceMeters,
    double? elevationGainMeters,
    int? effort,
    String note = '',
  }) {
    final finished = ActivitySession(
      id: live.id,
      type: live.type,
      startedAt: live.startedAt,
      duration: live.elapsedAt(_db.now()),
      distanceMeters: distanceMeters,
      elevationGainMeters: elevationGainMeters,
      effort: effort,
      note: note,
    );
    _activities.finish(finished);
    return finished;
  }

  /// Throws the running session away; nothing is counted, and the row is
  /// tombstoned rather than removed.
  void discard(LiveActivity live) => _activities.remove(live.id);

  ActivitySession? byId(String id) => _activities.byId(id);

  /// Whether session [id] was read from Apple Health or Health Connect:
  /// the platform keeps it, so the app only shows it.
  bool isFromHealth(String id) => switch (_activities.sourceOf(id)) {
    ChangeSource.healthKit || ChangeSource.healthConnect => true,
    _ => false,
  };

  /// Saves a correction to a session that was already logged.
  void edit(ActivitySession activity) => _activities.update(activity);

  /// Removes a session. The row is tombstoned, so [restore] can bring it
  /// back from the undo on the toast.
  void delete(String id) => _activities.remove(id);

  void restore(String id) => _activities.restore(id);

  List<ActivitySession> on(DateTime day) => _activities.between(
    DateTime(day.year, day.month, day.day),
    DateTime(day.year, day.month, day.day + 1),
  );

  /// The types used recently, for offering them first.
  List<ActivityType> recentTypes() => _activities.recentTypes();

  /// Where the form starts: the last duration of this type, else a round
  /// half hour.
  Duration startingDuration(ActivityType type) =>
      _activities.lastDurationOf(type) ?? defaultActivityDuration;

  /// Exercise over the window ending now.
  ActivitySummary summary({Duration window = const Duration(days: 28)}) {
    final now = _db.now();
    final sessions = _activities.between(
      now.subtract(window),
      _db.nowInclusive,
    );
    if (sessions.isEmpty) return ActivitySummary.empty;
    final weeks = (window.inDays / DateTime.daysPerWeek).ceil();
    return ActivitySummary(
      sessions: sessions.length,
      time: sessions.fold(Duration.zero, (sum, s) => sum + s.duration),
      weekly: weeklyCounts(
        sessions.map((session) => session.startedAt),
        now: now,
        weeks: weeks,
      ),
      weeklyMinutes: weeklySums(
        sessions.map(
          (session) => (session.startedAt, session.duration.inMinutes),
        ),
        now: now,
        weeks: weeks,
      ),
    );
  }

  /// The metrics any source recorded over the last year, in the order
  /// the app lists them.
  List<ActivityMetric> recordedMetrics() {
    final recorded = _samples.recordedSince(
      _db.now().subtract(const Duration(days: 365)),
    );
    return [
      for (final metric in ActivityMetric.values)
        if (recorded.contains(metric)) metric,
    ];
  }

  /// [metric] on each day from [from] to [to] (whole local days), oldest
  /// first; a day nothing was read for is absent.
  List<(DateTime, double)> daily(
    ActivityMetric metric,
    DateTime from,
    DateTime to,
  ) => dailyValues(
    _samples.between(
      metric,
      DateTime(from.year, from.month, from.day),
      DateTime(to.year, to.month, to.day + 1),
    ),
  );

  /// Each metric's figure on [day], for the ones that have one.
  Map<ActivityMetric, double> dayTotals(DateTime day) => {
    for (final metric in ActivityMetric.values)
      if (daily(metric, day, day).firstOrNull case (_, final value))
        metric: value,
  };

  /// A counted metric's [day] hour by hour; null when nothing was read
  /// for that day.
  List<double>? hourly(ActivityMetric metric, DateTime day) {
    final samples = _samples.between(
      metric,
      DateTime(day.year, day.month, day.day),
      DateTime(day.year, day.month, day.day + 1),
    );
    return samples.isEmpty ? null : hourlyValues(samples);
  }

  /// What an ordinary day of [metric] looks like, from the
  /// [usualRangeDays] before [day]; null with too few days.
  ({double low, double high})? usualRange(
    ActivityMetric metric,
    DateTime day,
  ) => usualRangeOf(
    daily(
      metric,
      day.subtract(const Duration(days: usualRangeDays)),
      day.subtract(const Duration(days: 1)),
    ),
  );
}
