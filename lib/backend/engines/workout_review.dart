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
    required this.oneRepMaxKg,
    required this.previousOneRepMaxKg,
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

  /// The best estimated max of this session, and of the one before it:
  /// the change that says more than the total lifted. Null where no set
  /// gives an estimate, or there was no session before.
  final double? oneRepMaxKg;
  final double? previousOneRepMaxKg;
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
          oneRepMaxKg: _bestEstimate(session.sets),
          previousOneRepMaxKg:
              earlier[session.exercise.id]?.firstOrNull?.oneRepMaxKg,
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

double? _bestEstimate(List<WorkoutSet> sets) =>
    countedSets(sets)
        .map((set) => estimateOneRepMax(set.weightKg, set.reps))
        .nonNulls
        .fold<double?>(null, (best, e) => best == null || e > best ? e : best);

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

/// The best an exercise has come to across its finished sessions.
class ExerciseBests {
  const ExerciseBests({
    required this.exercise,
    required this.heaviest,
    required this.bestEstimate,
  });

  final ExerciseDefinition exercise;

  /// The session with the heaviest counted set; the earliest on a tie,
  /// since that is when it was first lifted.
  final ExerciseHistoryEntry heaviest;

  /// The session with the highest estimated max; null when no set gave
  /// an estimate.
  final ExerciseHistoryEntry? bestEstimate;

  /// When the latest of the two was set.
  DateTime get latest {
    final estimate = bestEstimate;
    return estimate == null || heaviest.date.isAfter(estimate.date)
        ? heaviest.date
        : estimate.date;
  }
}

/// [exercise]'s bests in [history]; null with no finished session.
ExerciseBests? bestsOf(ExerciseDefinition exercise, ExerciseHistory history) {
  ExerciseHistoryEntry? heaviest;
  ExerciseHistoryEntry? bestEstimate;
  // Oldest first, so a later equal lift does not take the date.
  for (final entry in history.recent.reversed) {
    if (heaviest == null || entry.weightKg > heaviest.weightKg) {
      heaviest = entry;
    }
    final estimate = entry.oneRepMaxKg;
    if (estimate != null &&
        (bestEstimate == null || estimate > bestEstimate.oneRepMaxKg!)) {
      bestEstimate = entry;
    }
  }
  if (heaviest == null) return null;
  return ExerciseBests(
    exercise: exercise,
    heaviest: heaviest,
    bestEstimate: bestEstimate,
  );
}
