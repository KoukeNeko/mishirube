/// One past session of an exercise, summarised by its heaviest completed
/// working set.
class ExerciseHistoryEntry {
  const ExerciseHistoryEntry({
    required this.date,
    required this.weightKg,
    required this.reps,
    this.rir,
  });

  final DateTime date;
  final double weightKg;
  final int reps;
  final int? rir;
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
}
