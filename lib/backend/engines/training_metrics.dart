import '../../domain/domain.dart';

/// Bumped whenever a formula below changes, so stored or exported results
/// can say which rules produced them.
const trainingMetricsVersion = 1;

/// Epley grows unreliable past this many reps, so such sets give no estimate.
const maxRepsForEstimate = 12;

/// How far back the estimated max looks.
const oneRepMaxWindow = Duration(days: 90);

/// The smallest change a barbell can make: a plate on each side.
const plateStepKg = 2.5;

/// Defaults for a set added during a workout, as a share of the working
/// weight. They are starting points to adjust, not prescriptions.
const warmupShare = 0.6;
const dropShare = 0.8;

/// Working sets planned for an exercise on a day one of its muscles is
/// still sore: one fewer, never none. Recovery is read from the lifter,
/// not guessed from the records.
int setsWhenSore(int sets) => sets > 1 ? sets - 1 : sets;

/// Whether [planned] works a muscle in [sore].
bool worksSoreMuscle(PlannedExercise planned, Set<MuscleGroup> sore) =>
    planned.exercise.primaryMuscles.any(sore.contains);

/// Time to do one set, the rest after it aside.
const setWorkTime = Duration(seconds: 40);

/// How long [exercises] take as planned: each set and the rest after it.
Duration plannedDuration(List<PlannedExercise> exercises) => exercises.fold(
  Duration.zero,
  (sum, planned) =>
      sum + (setWorkTime + restAfter(planned.exercise)) * planned.sets,
);

/// A warm-up ramp: shares of the working weight, each with fewer reps
/// than the last, so the working set is reached without tiring for it.
const _rampSteps = [(0.4, 5), (0.6, 3), (0.8, 1)];

/// The warm-up sets before a working set of [workingKg], lightest first,
/// as weight and reps: an empty bar first for a barbell, then the ramp,
/// rounded to the plates. A step that rounds to the one before it, or to
/// the working weight, is left out.
List<(double, int)> warmupRamp(double workingKg, Equipment equipment) {
  final isBarbell = equipment == Equipment.barbell;
  final ramp = <(double, int)>[if (isBarbell && workingKg > barKg) (barKg, 10)];
  for (final (share, reps) in _rampSteps) {
    final kg = roundToPlate(workingKg * share);
    if (kg >= workingKg || (isBarbell && kg <= barKg)) continue;
    if (ramp.isNotEmpty && kg <= ramp.last.$1) continue;
    ramp.add((kg, reps));
  }
  return ramp;
}

/// An Olympic bar, and the plates a gym has, heaviest first.
const barKg = 20.0;
const platesKg = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25];

/// The plates on each side of the bar for [totalKg], heaviest first:
/// empty for the bare bar, null when the plates cannot make it exactly.
List<double>? platesPerSide(double totalKg) {
  var side = (totalKg - barKg) / 2;
  if (side < 0) return null;
  final plates = <double>[];
  for (final plate in platesKg) {
    while (side >= plate - 1e-9) {
      plates.add(plate);
      side -= plate;
    }
  }
  return side.abs() < 1e-9 ? plates : null;
}

/// Rest before the next set when nothing else is said: a movement that
/// loads several joints needs longer to recover for than one that
/// isolates a muscle. Starting points to lengthen or cut short.
const compoundRest = Duration(minutes: 2);
const isolationRest = Duration(seconds: 90);

Duration restAfter(ExerciseDefinition exercise) =>
    exercise.pattern == MovementPattern.isolation
    ? isolationRest
    : compoundRest;

/// Rounds [kilograms] down to something loadable on a bar, never below
/// one step.
double roundToPlate(double kilograms, {double step = plateStepKg}) {
  if (kilograms <= step) return step;
  return (kilograms / step).floorToDouble() * step;
}

/// The weight a set of [type] starts at, given the working weight.
double startingWeight(double workingKg, SetType type) => switch (type) {
  SetType.warmup => roundToPlate(workingKg * warmupShare),
  SetType.drop => roundToPlate(workingKg * dropShare),
  SetType.working || SetType.failure => workingKg,
};

/// Epley estimate of a one-rep max: `w × (1 + reps / 30)`.
double? estimateOneRepMax(double weightKg, int reps) {
  if (reps <= 0 || reps > maxRepsForEstimate || weightKg <= 0) return null;
  if (reps == 1) return weightKg;
  return weightKg * (1 + reps / 30);
}

/// Sets that count for progress: done and not warm-ups.
Iterable<WorkoutSet> countedSets(Iterable<WorkoutSet> sets) =>
    sets.where((set) => set.isDone && set.type != SetType.warmup);

/// Total load moved in the counted sets, in kg.
double volumeKg(Iterable<WorkoutSet> sets) =>
    countedSets(sets).fold(0, (sum, set) => sum + set.weightKg * set.reps);

/// The heaviest counted set; ties go to more reps.
WorkoutSet? heaviestSet(Iterable<WorkoutSet> sets) {
  WorkoutSet? best;
  for (final set in countedSets(sets)) {
    if (best == null ||
        set.weightKg > best.weightKg ||
        (set.weightKg == best.weightKg && set.reps > best.reps)) {
      best = set;
    }
  }
  return best;
}

/// Working sets per muscle group, most trained first. A set counts for
/// the exercise's primary muscles only: the secondary work is real, but
/// counting a row as a full set of biceps would flatter the numbers.
List<(MuscleGroup, int)> setsByMuscle(
  Iterable<(ExerciseDefinition, int)> setsByExercise,
) {
  final totals = <MuscleGroup, int>{};
  for (final (exercise, sets) in setsByExercise) {
    for (final muscle in exercise.primaryMuscles) {
      totals[muscle] = (totals[muscle] ?? 0) + sets;
    }
  }
  return [for (final entry in totals.entries) (entry.key, entry.value)]
    ..sort((a, b) {
      final bySets = b.$2.compareTo(a.$2);
      // A stable order when two muscles tie, so the list does not shuffle.
      return bySets != 0 ? bySets : a.$1.index.compareTo(b.$1.index);
    });
}

/// The same totals as a rate: sets per week over [weeks], which is how
/// training volume is usually talked about.
List<(MuscleGroup, int)> weeklySetsByMuscle(
  Iterable<(ExerciseDefinition, int)> setsByExercise, {
  required int weeks,
}) => [
  for (final (muscle, sets) in setsByMuscle(setsByExercise))
    if ((sets / (weeks < 1 ? 1 : weeks)).round() case final perWeek
        when perWeek > 0)
      (muscle, perWeek),
];
