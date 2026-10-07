import 'training.dart';

/// One past session of an exercise, summarised by its best completed
/// working set.
class ExerciseHistoryEntry {
  const ExerciseHistoryEntry({
    required this.date,
    required this.weightKg,
    required this.reps,
    this.rir,
    this.oneRepMaxKg,
    this.seconds,
    this.meters,
  });

  final DateTime date;

  /// The session's best counted set, by the exercise's own measure: the
  /// heaviest for weight and reps, the most reps for reps alone, the
  /// longest for a time, the furthest for a distance.
  final double weightKg;
  final int reps;
  final int? rir;

  /// That set's time and distance, for the exercises recorded that way.
  final int? seconds;
  final double? meters;

  /// The best estimated max of any counted set that session, which may
  /// be a lighter set done for more reps; null when none gives one.
  final double? oneRepMaxKg;
}

/// One finished session of an exercise and its sets, in the order they
/// were planned.
class ExerciseSessionRecord {
  const ExerciseSessionRecord({
    required this.workoutId,
    required this.date,
    required this.sets,
  });

  /// The finished workout the session was done in.
  final String workoutId;
  final DateTime date;
  final List<WorkoutSet> sets;
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
