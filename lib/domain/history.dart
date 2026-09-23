/// One past session of an exercise, summarised by its heaviest completed
/// working set.
class ExerciseHistoryEntry {
  const ExerciseHistoryEntry({
    required this.date,
    required this.weightKg,
    required this.reps,
    this.rir,
    this.oneRepMaxKg,
  });

  final DateTime date;

  /// The session's heaviest counted set.
  final double weightKg;
  final int reps;
  final int? rir;

  /// The best estimated max of any counted set that session, which may
  /// be a lighter set done for more reps; null when none gives one.
  final double? oneRepMaxKg;
}

/// What the user has done with one exercise, derived from finished workouts.
class ExerciseHistory {
  const ExerciseHistory({
    required this.recent,
    required this.sessionCount,
    this.estimatedOneRepMaxKg,
  });

  static const empty = ExerciseHistory(recent: [], sessionCount: 0);

  /// Newest first.
  final List<ExerciseHistoryEntry> recent;
  final int sessionCount;

  /// Best Epley estimate within the estimate window; null without data.
  final double? estimatedOneRepMaxKg;

  ExerciseHistoryEntry? get last => recent.isEmpty ? null : recent.first;

  /// The sessions that started before [time], newest first.
  List<ExerciseHistoryEntry> before(DateTime time) =>
      recent.where((entry) => entry.date.isBefore(time)).toList();
}
