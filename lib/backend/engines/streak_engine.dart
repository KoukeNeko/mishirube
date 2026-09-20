import '../../domain/domain.dart';

/// Bumped whenever a rule below changes, so a stored or exported result
/// can say which version produced it.
const streakEngineVersion = 1;

/// What the app suggests when someone has no history to go on. Three is
/// a rhythm most people can keep; the guidelines are about a weekly
/// total, not a number of sessions, so this is a starting point rather
/// than a recommendation.
const suggestedWeeklyGoal = 3;

const minWeeklyGoal = 1;
const maxWeeklyGoal = 7;

/// The days something was done on. A day counts once however much was
/// done in it, so splitting one session into three records changes
/// nothing.
Set<DateTime> activeDays(Iterable<DateTime> records) => {
  for (final record in records) DateTime(record.year, record.month, record.day),
};

/// The Monday of the week [day] falls in.
DateTime startOfWeek(DateTime day) {
  final date = DateTime(day.year, day.month, day.day);
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
}

/// The [weeks] whole weeks ending with the one holding [now], each
/// measured against the goal in force that week.
List<WeekProgress> weekProgress({
  required Set<DateTime> activeDays,
  required List<WeeklyGoal> goals,
  required List<GoalPause> pauses,
  required DateTime now,
  required int weeks,
}) {
  final thisWeek = startOfWeek(now);
  return [
    for (var index = weeks - 1; index >= 0; index--)
      _week(
        start: thisWeek.subtract(Duration(days: index * DateTime.daysPerWeek)),
        activeDays: activeDays,
        goals: goals,
        pauses: pauses,
        isCurrent: index == 0,
      ),
  ];
}

WeekProgress _week({
  required DateTime start,
  required Set<DateTime> activeDays,
  required List<WeeklyGoal> goals,
  required List<GoalPause> pauses,
  required bool isCurrent,
}) {
  var days = 0;
  for (var i = 0; i < DateTime.daysPerWeek; i++) {
    if (activeDays.contains(start.add(Duration(days: i)))) days++;
  }
  return WeekProgress(
    start: start,
    activeDays: days,
    targetDays: goalOn(start, goals)?.targetDays ?? suggestedWeeklyGoal,
    // A week is paused when the pause covers any part of it: a week half
    // spent ill is not a week the user failed.
    isPaused: pauses.any((pause) => _overlaps(pause, start)),
    isCurrent: isCurrent,
  );
}

bool _overlaps(GoalPause pause, DateTime weekStart) {
  final weekEnd = weekStart.add(const Duration(days: DateTime.daysPerWeek));
  final endsAfterWeekStarts =
      pause.endedAt == null || pause.endedAt!.isAfter(weekStart);
  return endsAfterWeekStarts && pause.startedAt.isBefore(weekEnd);
}

/// The goal in force on [day]: the most recent one that had started by
/// then. Null before the user set any.
WeeklyGoal? goalOn(DateTime day, List<WeeklyGoal> goals) {
  WeeklyGoal? inForce;
  for (final goal in goals) {
    if (goal.effectiveFrom.isAfter(day)) continue;
    if (inForce == null || goal.effectiveFrom.isAfter(inForce.effectiveFrom)) {
      inForce = goal;
    }
  }
  return inForce;
}

/// Weeks met in a row, oldest first in [weeks]. A paused week is skipped
/// rather than counted or broken, and the week in progress only counts
/// once it has been met.
StreakSummary streak(List<WeekProgress> weeks) {
  if (weeks.isEmpty) return StreakSummary.empty;
  var best = 0;
  var run = 0;
  var previous = 0;
  for (final week in weeks) {
    if (week.isPaused) continue;
    if (week.isMet) {
      run++;
      if (run > best) best = run;
      continue;
    }
    // The week in progress has not failed, so it neither adds nor ends.
    if (week.isCurrent) continue;
    if (run > 0) previous = run;
    run = 0;
  }
  return StreakSummary(
    current: run,
    best: best,
    previous: previous,
    isThisWeekPending: !weeks.last.isMet && !weeks.last.isPaused,
  );
}
