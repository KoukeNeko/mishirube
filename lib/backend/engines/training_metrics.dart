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
