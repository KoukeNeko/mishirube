import '../../domain/domain.dart';
import 'training_metrics.dart';

/// Bumped whenever a rule below changes, so a stored or exported result
/// can say which version produced it.
const workoutReviewVersion = 1;

/// Whether [set] beats every earlier session of its exercise: heavier
/// than any of them, or a higher estimated max, so more reps at the same
/// weight count too. A first session is no record: there is nothing to
/// beat. A warm-up or an unfinished set never is.
bool isPersonalRecordSet(WorkoutSet set, List<ExerciseHistoryEntry> earlier) {
  if (!set.isDone || set.type == SetType.warmup || earlier.isEmpty) {
    return false;
  }
  final bestWeight = earlier
      .map((entry) => entry.weightKg)
      .reduce((a, b) => a > b ? a : b);
  if (set.weightKg > bestWeight) return true;
  final estimate = estimateOneRepMax(set.weightKg, set.reps);
  final bestEstimate = earlier
      .map((entry) => entry.oneRepMaxKg)
      .nonNulls
      .fold<double?>(null, (best, e) => best == null || e > best ? e : best);
  return estimate != null && bestEstimate != null && estimate > bestEstimate;
}

/// One exercise of a workout as it came out.
class ExerciseReview {
  const ExerciseReview({
    required this.exercise,
    required this.sets,
    required this.best,
    required this.volumeKg,
    required this.record,
  });

  final ExerciseDefinition exercise;

  /// Sets done, warm-ups included: they were done.
  final int sets;

  /// The heaviest counted set; null when only warm-ups were done.
  final WorkoutSet? best;

  final double volumeKg;

  /// The set that set a record, the one with the highest estimated max
  /// when several did; null for none.
  final WorkoutSet? record;
}

/// A workout as it came out, against what came before it.
class WorkoutReview {
  const WorkoutReview({
    required this.exercises,
    required this.previousVolumeKg,
  });

  /// The exercises with at least one set done, in the order done.
  final List<ExerciseReview> exercises;

  /// The last finished workout of the same template, for comparison;
  /// null when there is none.
  final double? previousVolumeKg;

  int get sets => exercises.fold(0, (sum, item) => sum + item.sets);

  double get volumeKg => exercises.fold(0, (sum, item) => sum + item.volumeKg);

  int get records => exercises.where((item) => item.record != null).length;
}

/// Reviews [workout] against [earlier]: each exercise's finished sessions
/// before this workout, by exercise id. [previous] is the last finished
/// workout of the same template.
WorkoutReview reviewWorkout(
  WorkoutSession workout, {
  required Map<String, List<ExerciseHistoryEntry>> earlier,
  WorkoutSession? previous,
}) {
  final exercises = [
    for (final session in workout.exercises)
      if (session.completedSets > 0)
        ExerciseReview(
          exercise: session.exercise,
          sets: session.completedSets,
          best: heaviestSet(session.sets),
          volumeKg: volumeKg(session.sets),
          record: _record(
            session.sets,
            earlier[session.exercise.id] ?? const [],
          ),
        ),
  ];
  return WorkoutReview(
    exercises: exercises,
    previousVolumeKg: previous?.exercises.fold<double>(
      0,
      (sum, session) => sum + volumeKg(session.sets),
    ),
  );
}

WorkoutSet? _record(List<WorkoutSet> sets, List<ExerciseHistoryEntry> earlier) {
  WorkoutSet? record;
  double score(WorkoutSet set) =>
      estimateOneRepMax(set.weightKg, set.reps) ?? set.weightKg;
  for (final set in sets) {
    if (!isPersonalRecordSet(set, earlier)) continue;
    if (record == null || score(set) > score(record)) record = set;
  }
  return record;
}
