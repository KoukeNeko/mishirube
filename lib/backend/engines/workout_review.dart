import '../../domain/domain.dart';
import 'training_metrics.dart';

/// Bumped whenever a rule below changes, so a stored or exported result
/// can say which version produced it.
const workoutReviewVersion = 1;

/// Whether [set] beats every earlier session of its exercise, recorded as
/// [type]. With weight and reps: heavier than any of them, or a higher
/// estimated max, so more reps at the same weight count too. With reps
/// alone, more reps; with a time, longer; with weight and time, heavier,
/// or longer than any session at that weight or more; with a distance,
/// further. A first session is no record: there is nothing to beat. A
/// warm-up or an unfinished set never is.
bool isPersonalRecordSet(
  WorkoutSet set,
  List<ExerciseHistoryEntry> earlier, {
  TrackingType type = TrackingType.weightReps,
}) {
  if (!set.isDone || set.type == SetType.warmup || earlier.isEmpty) {
    return false;
  }
  final figures = figuresOfSet(set);
  final before = [for (final entry in earlier) figuresOfEntry(entry)];
  switch (type) {
    case TrackingType.reps:
      return before.every((other) => figures.reps > other.reps);
    case TrackingType.duration:
      return figures.seconds > 0 &&
          before.every((other) => figures.seconds > other.seconds);
    case TrackingType.weightDuration:
      return figures.seconds > 0 &&
          before.every(
            (other) =>
                other.weightKg < figures.weightKg ||
                other.seconds < figures.seconds,
          );
    case TrackingType.distance:
      return figures.meters > 0 &&
          before.every((other) => figures.meters > other.meters);
    case TrackingType.weightReps:
      break;
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
    required this.done,
    required this.best,
    required this.volumeKg,
    required this.record,
    this.seconds = 0,
    this.reps = 0,
    this.meters = 0,
  });

  final ExerciseDefinition exercise;

  /// The sets done, in order, warm-ups included: they were done.
  final List<WorkoutSet> done;

  int get sets => done.length;

  /// The best counted set by the exercise's own measure; null when only
  /// warm-ups were done.
  final WorkoutSet? best;

  /// What was lifted, in kg: only an exercise recorded by weight and reps
  /// adds to it.
  final double volumeKg;

  /// What an exercise recorded another way came to: its time, its reps
  /// when recorded by reps alone, its distance in metres.
  final int seconds;
  final int reps;
  final double meters;

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

  /// The time, reps and distance (in metres) of the exercises recorded by
  /// those, summed.
  int get seconds => exercises.fold(0, (sum, item) => sum + item.seconds);
  int get reps => exercises.fold(0, (sum, item) => sum + item.reps);
  double get meters => exercises.fold(0.0, (sum, item) => sum + item.meters);

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
          done: [
            for (final set in session.sets)
              if (set.isDone) set,
          ],
          best: bestSet(session.exercise.trackingType, session.sets),
          volumeKg: sessionVolumeKg(session),
          seconds: sessionSeconds(session),
          reps: sessionReps(session),
          meters: sessionMeters(session),
          record: _record(
            session.exercise.trackingType,
            session.sets,
            earlier[session.exercise.id] ?? const [],
          ),
        ),
  ];
  return WorkoutReview(
    exercises: exercises,
    previousVolumeKg: previous?.exercises.fold<double>(
      0,
      (sum, session) => sum + sessionVolumeKg(session),
    ),
  );
}

WorkoutSet? _record(
  TrackingType type,
  List<WorkoutSet> sets,
  List<ExerciseHistoryEntry> earlier,
) {
  WorkoutSet? record;
  // A weight and reps set is ranked by its estimated max, so more reps at
  // the same weight count; any other by its own measure.
  bool beats(WorkoutSet a, WorkoutSet b) => type == TrackingType.weightReps
      ? (estimateOneRepMax(a.weightKg, a.reps) ?? a.weightKg) >
            (estimateOneRepMax(b.weightKg, b.reps) ?? b.weightKg)
      : isBetterSet(type, figuresOfSet(a), figuresOfSet(b));
  for (final set in sets) {
    if (!isPersonalRecordSet(set, earlier, type: type)) continue;
    if (record == null || beats(set, record)) record = set;
  }
  return record;
}

/// The best an exercise has come to across its finished sessions.
class ExerciseBests {
  const ExerciseBests({
    required this.exercise,
    required this.best,
    required this.bestEstimate,
  });

  final ExerciseDefinition exercise;

  /// The session with the best counted set by the exercise's own measure
  /// (the heaviest, the longest, ...); the earliest on a tie, since that
  /// is when it was first done.
  final ExerciseHistoryEntry best;

  /// The session with the highest estimated max; null when no set gave
  /// an estimate.
  final ExerciseHistoryEntry? bestEstimate;

  /// When the latest of the two was set.
  DateTime get latest {
    final estimate = bestEstimate;
    return estimate == null || best.date.isAfter(estimate.date)
        ? best.date
        : estimate.date;
  }
}

/// [exercise]'s bests in [history]; null with no finished session.
ExerciseBests? bestsOf(ExerciseDefinition exercise, ExerciseHistory history) {
  ExerciseHistoryEntry? best;
  ExerciseHistoryEntry? bestEstimate;
  // Oldest first, so a later equal lift does not take the date.
  for (final entry in history.recent.reversed) {
    // Across sessions more reps at the same weight is no new heaviest: the
    // day it was first lifted stays.
    final isBest =
        best == null ||
        (exercise.trackingType == TrackingType.weightReps
            ? entry.weightKg > best.weightKg
            : isBetterSet(
                exercise.trackingType,
                figuresOfEntry(entry),
                figuresOfEntry(best),
              ));
    if (isBest) best = entry;
    final estimate = entry.oneRepMaxKg;
    if (estimate != null &&
        (bestEstimate == null || estimate > bestEstimate.oneRepMaxKg!)) {
      bestEstimate = entry;
    }
  }
  if (best == null) return null;
  return ExerciseBests(
    exercise: exercise,
    best: best,
    bestEstimate: bestEstimate,
  );
}
