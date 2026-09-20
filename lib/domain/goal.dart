/// How many days a week the user wants to move, from [effectiveFrom] on.
/// Changing the goal adds another one of these rather than rewriting the
/// old one, so a past week is still judged by what it was aiming at.
class WeeklyGoal {
  const WeeklyGoal({
    required this.id,
    required this.effectiveFrom,
    required this.targetDays,
  });

  final String id;

  /// The Monday the goal starts counting from.
  final DateTime effectiveFrom;

  final int targetDays;
}

/// A stretch where the goal does not apply: ill, injured, travelling.
/// An open pause has no [endedAt] yet.
class GoalPause {
  const GoalPause({
    required this.id,
    required this.startedAt,
    this.endedAt,
    this.note = '',
  });

  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String note;

  bool covers(DateTime day) =>
      !day.isBefore(startedAt) && (endedAt == null || day.isBefore(endedAt!));
}

/// One week measured against the goal that was in force that week.
class WeekProgress {
  const WeekProgress({
    required this.start,
    required this.activeDays,
    required this.targetDays,
    required this.isPaused,
    required this.isCurrent,
  });

  /// The Monday the week starts on.
  final DateTime start;

  /// Days with at least one workout or activity. A day counts once
  /// however much was done in it.
  final int activeDays;

  final int targetDays;

  /// The goal did not apply: the week neither extends nor breaks a run.
  final bool isPaused;

  /// The week in progress, which cannot have failed yet.
  final bool isCurrent;

  DateTime get end => start.add(const Duration(days: DateTime.daysPerWeek));

  bool get isMet => !isPaused && activeDays >= targetDays;

  /// Only a finished week that fell short counts as missed.
  bool get isMissed => !isPaused && !isCurrent && activeDays < targetDays;

  int get remaining =>
      targetDays - activeDays < 0 ? 0 : targetDays - activeDays;
}

/// Weeks met in a row, and what that run looked like at its best.
class StreakSummary {
  const StreakSummary({
    required this.current,
    required this.best,
    required this.previous,
    required this.isThisWeekPending,
  });

  static const empty = StreakSummary(
    current: 0,
    best: 0,
    previous: 0,
    isThisWeekPending: false,
  );

  /// Weeks met in a row up to now. The week in progress counts as soon
  /// as it is met, so meeting the goal on Thursday shows straight away.
  final int current;

  final int best;

  /// The run that ended, for saying what there is to get back to rather
  /// than showing a zero.
  final int previous;

  /// This week has not been met yet, which is not the same as failing.
  final bool isThisWeekPending;

  bool get hasRun => current > 0;
}
