import '../../domain/domain.dart';
import '../engines/trend_engine.dart';
import '../storage/activity_repository.dart';
import '../storage/database.dart';

/// What the form starts from when nothing was logged before.
const defaultActivityDuration = Duration(minutes: 30);

/// A window's worth of exercise, for the trends card.
class ActivitySummary {
  const ActivitySummary({
    required this.sessions,
    required this.time,
    required this.weekly,
  });

  static const empty = ActivitySummary(
    sessions: 0,
    time: Duration.zero,
    weekly: [],
  );

  final int sessions;
  final Duration time;

  /// Sessions per week, oldest first, ending with this week.
  final List<WeeklyBar> weekly;

  bool get hasRecords => sessions > 0;

  int get thisWeek => weekly.isEmpty ? 0 : weekly.last.$2;
}

/// Logging general exercise.
class ActivityService {
  ActivityService(this._db, this._activities);

  final AppDatabase _db;
  final ActivityRepository _activities;

  /// Records a session. [startedAt] is when it began; the caller works out
  /// the start from the end and the duration, since that is how people
  /// remember it.
  ActivitySession log({
    required ActivityType type,
    required DateTime startedAt,
    required Duration duration,
    double? distanceMeters,
    int? effort,
    String note = '',
  }) {
    final activity = ActivitySession(
      id: _db.newId(),
      type: type,
      startedAt: startedAt,
      duration: duration,
      distanceMeters: distanceMeters,
      effort: effort,
      note: note,
    );
    _activities.add(activity);
    return activity;
  }

  ActivitySession? byId(String id) => _activities.byId(id);

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
    return ActivitySummary(
      sessions: sessions.length,
      time: sessions.fold(Duration.zero, (sum, s) => sum + s.duration),
      weekly: weeklyCounts(
        sessions.map((session) => session.startedAt),
        now: now,
        weeks: (window.inDays / DateTime.daysPerWeek).ceil(),
      ),
    );
  }
}
