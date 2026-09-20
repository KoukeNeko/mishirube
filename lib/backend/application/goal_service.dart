import '../../domain/domain.dart';
import '../engines/streak_engine.dart';
import '../storage/activity_repository.dart';
import '../storage/database.dart';
import '../storage/goal_repository.dart';
import '../storage/workout_repository.dart';

/// Weeks of history the page shows and the streak is counted over.
const _weeksTracked = 52;

/// How far back "a normal week for you" looks when suggesting a goal.
const _weeksForSuggestion = 4;

/// Everything the goal screen shows, derived from the records.
class GoalOverview {
  const GoalOverview({
    required this.isEnabled,
    required this.weeks,
    required this.streak,
    required this.activeDays,
    required this.pause,
    required this.hasGoal,
    required this.suggestedDays,
  });

  final bool isEnabled;

  /// A year of weeks, oldest first, ending with the week in progress.
  final List<WeekProgress> weeks;

  final StreakSummary streak;

  /// Every day with a workout or an activity on it.
  final Set<DateTime> activeDays;

  /// The pause still running, if any.
  final GoalPause? pause;

  /// False until the user has set a goal, which is not the same as one
  /// of zero: the screen asks instead of assuming.
  final bool hasGoal;

  /// What the user has actually been doing, for setting a goal from.
  final int suggestedDays;

  WeekProgress get thisWeek => weeks.last;

  bool get isPaused => pause != null;
}

/// The weekly goal, the weeks measured against it, and the run of weeks
/// met. Counts a day once however much was done in it, and counts
/// training and other exercise the same: the question is whether the
/// week had a rhythm, not how much was lifted.
class GoalService {
  GoalService(this._db, this._goals, this._workouts, this._activities);

  static const _enabledKey = 'weekly_goal_enabled';

  final AppDatabase _db;
  final GoalRepository _goals;
  final WorkoutRepository _workouts;
  final ActivityRepository _activities;

  bool get isEnabled => _db.setting(_enabledKey) == 'true';

  void setEnabled(bool value) => _db.setSetting(_enabledKey, '$value');

  GoalOverview overview() {
    final now = _db.now();
    final goals = _goals.goals();
    final days = activeDays([
      ..._workouts.completedStarts(),
      ..._activities
          .between(DateTime(now.year - 1, now.month, now.day), _db.nowInclusive)
          .map((activity) => activity.startedAt),
    ]);
    final weeks = weekProgress(
      activeDays: days,
      goals: goals,
      pauses: _goals.pauses(),
      now: now,
      weeks: _weeksTracked,
    );
    return GoalOverview(
      isEnabled: isEnabled,
      weeks: weeks,
      streak: streak(weeks),
      activeDays: days,
      pause: _goals.openPause(),
      hasGoal: goals.isNotEmpty,
      suggestedDays: _suggestFrom(weeks),
    );
  }

  /// A goal to start from: what the last few finished weeks actually
  /// looked like, or a plain suggestion when there is no history.
  int _suggestFrom(List<WeekProgress> weeks) {
    final recent = weeks
        .where((week) => !week.isCurrent)
        .toList()
        .reversed
        .take(_weeksForSuggestion)
        .toList();
    if (recent.isEmpty) return suggestedWeeklyGoal;
    final total = recent.fold(0, (sum, week) => sum + week.activeDays);
    final average = (total / recent.length).round();
    if (average < minWeeklyGoal) return suggestedWeeklyGoal;
    return average > maxWeeklyGoal ? maxWeeklyGoal : average;
  }

  /// Sets the goal from next week, or from this one when the user asks.
  /// Earlier weeks keep the goal they were judged by.
  void setGoal(int days, {bool applyThisWeek = false}) {
    final thisWeek = startOfWeek(_db.now());
    _goals.setGoal(
      WeeklyGoal(
        id: _db.newId(),
        effectiveFrom: applyThisWeek
            ? thisWeek
            : thisWeek.add(const Duration(days: DateTime.daysPerWeek)),
        targetDays: days.clamp(minWeeklyGoal, maxWeeklyGoal),
      ),
    );
    setEnabled(true);
  }

  /// Stops the goal applying. Without [until] it runs until the user
  /// picks it up again.
  void pause({DateTime? until, String note = ''}) {
    if (_goals.openPause() != null) return;
    _goals.startPause(
      GoalPause(
        id: _db.newId(),
        startedAt: _db.now(),
        endedAt: until,
        note: note,
      ),
    );
  }

  void resume() {
    final open = _goals.openPause();
    if (open == null) return;
    _goals.endPause(open.id, _db.now());
  }
}
