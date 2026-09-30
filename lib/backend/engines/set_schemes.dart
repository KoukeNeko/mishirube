import '../../domain/domain.dart';
import 'training_metrics.dart';

/// A way of spreading an exercise's working sets over weight and reps.
enum SetScheme {
  /// Every set at the main weight.
  straight,

  /// Lighter for more reps first, the main weight last.
  ascending,

  /// Heaviest first, then lighter for more reps.
  reverse,

  /// Five sets of five at the main weight, whatever sets and reps say.
  fiveByFive,

  /// One heavy set, the rest lighter.
  topSet,

  /// Heaviest first, a little lighter each set.
  drop,
}

/// The sets and reps of [SetScheme.fiveByFive].
const fiveByFiveSets = 5;
const fiveByFiveReps = 5;

/// How much lighter than the main weight the sets after a top set are, and
/// the reps they gain.
const _topSetBackoffShare = 0.9;
const _topSetBackoffExtraReps = 2;

/// The working sets [scheme] makes of [mainKg] for [reps]: [sets] of them
/// (five for [SetScheme.fiveByFive]), in the order they are done. Weights
/// are rounded down to what a bar can load; a set never goes below 0, and
/// a bodyweight exercise (no main weight) stays at 0. [seconds] and
/// [meters] go on every set: only [SetScheme.straight] is offered for an
/// exercise that has them.
List<SetLoad> schemeSets(
  SetScheme scheme, {
  required double mainKg,
  required int sets,
  required int reps,
  int? seconds,
  double? meters,
}) {
  final count = scheme == SetScheme.fiveByFive ? fiveByFiveSets : sets;
  final last = count - 1;
  SetLoad at(double share, int setReps) => SetLoad(
    weightKg: _loadable(mainKg * share),
    reps: setReps < 0 ? 0 : setReps,
    seconds: seconds,
    meters: meters,
  );
  return [
    for (var i = 0; i < count; i++)
      switch (scheme) {
        SetScheme.straight => at(1, reps),
        SetScheme.ascending =>
          last == 0
              ? at(1, reps)
              : at(0.8 + 0.2 * i / last, reps + 2 - 2 * i ~/ last),
        SetScheme.reverse => at(1 - 0.1 * i, reps + 2 * i),
        SetScheme.fiveByFive => at(1, fiveByFiveReps),
        SetScheme.topSet =>
          i == 0
              ? at(1, reps)
              : at(_topSetBackoffShare, reps + _topSetBackoffExtraReps),
        SetScheme.drop => at(1 - 0.05 * i, reps + i),
      },
  ];
}

/// Shares like 0.7 are not exact in binary: without the nudge, 70 kg of
/// 100 could come out as 69.999… and round down a whole step.
double _loadable(double kg) => kg <= 0 ? 0 : roundToPlate(kg + 1e-9);

/// The weight a scheme starts from for an exercise: its heaviest counted
/// weight in the [oneRepMaxWindow] before [now], or its heaviest ever when
/// none is that recent; null with no history.
({double kg, bool isRecent})? mainWeightFrom(
  ExerciseHistory history,
  DateTime now,
) {
  final since = now.subtract(oneRepMaxWindow);
  double? recent;
  double? ever;
  for (final entry in history.recent) {
    if (entry.weightKg > (ever ?? 0)) ever = entry.weightKg;
    if (!entry.date.isBefore(since) && entry.weightKg > (recent ?? 0)) {
      recent = entry.weightKg;
    }
  }
  if (recent != null) return (kg: recent, isRecent: true);
  if (ever != null) return (kg: ever, isRecent: false);
  return null;
}
