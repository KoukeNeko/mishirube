import '../../domain/domain.dart';

/// Bumped whenever the ranking below changes.
const substitutionEngineVersion = 2;

const _defaultCandidateCount = 3;

/// Candidate swaps for [exercise], best first, each with the reasons that
/// put it there.
///
/// A fair swap keeps the stimulus, not the name: the same movement
/// pattern first, then the muscles worked, then equipment the user
/// actually has. A pattern alone is not enough for a single-joint or core
/// movement, which any muscle may do: the exercise must also work the
/// same region of the body, and one of the same family (a dumbbell press
/// for a barbell press) comes first. Load is never carried across
/// equipment; when the set-up differs the reasons say so instead of
/// implying the same weights. An exercise the user hid is not offered.
List<SubstitutionOption> substitutesFor(
  ExerciseDefinition exercise,
  Iterable<ExerciseDefinition> catalog, {
  int count = _defaultCandidateCount,
}) {
  final scored = <(int, SubstitutionOption)>[];
  for (final candidate in catalog) {
    if (candidate.id == exercise.id || candidate.isHidden) continue;
    final sharedMuscles = candidate.primaryMuscles
        .where(exercise.primaryMuscles.contains)
        .toList();
    final samePattern = candidate.pattern == exercise.pattern;
    if (!samePattern && sharedMuscles.isEmpty) continue;
    final sameRegion = candidate.primaryMuscles.any(
      (muscle) =>
          exercise.primaryMuscles.any((other) => other.region == muscle.region),
    );
    if (sharedMuscles.isEmpty && !sameRegion) continue;

    final reasons = <SubstitutionReason>[
      if (samePattern)
        SamePattern(exercise.pattern)
      else
        SameMuscles(sharedMuscles),
      if (candidate.isInHomeGym) EquipmentAvailable(candidate.equipment),
      if (candidate.trackingType != exercise.trackingType)
        TrackingChanges(candidate.trackingType)
      else if (candidate.equipment != exercise.equipment)
        EquipmentChanges(candidate.equipment),
      if (candidate.pattern == MovementPattern.unilateral &&
          exercise.pattern != MovementPattern.unilateral)
        const OneSideAtATime(),
    ];
    final score =
        (samePattern ? 4 : 0) +
        sharedMuscles.length +
        (exercise.family.isNotEmpty && candidate.family == exercise.family
            ? 3
            : 0) +
        (candidate.isInHomeGym ? 2 : 0) +
        (candidate.trackingType == exercise.trackingType ? 2 : 0) +
        (candidate.equipment == exercise.equipment ? 1 : 0) +
        (candidate.isFavorite ? 1 : 0);
    scored.add((
      score,
      SubstitutionOption(exercise: candidate, reasons: reasons),
    ));
  }
  scored.sort((a, b) {
    final byScore = b.$1.compareTo(a.$1);
    // Ties keep a stable order so the list does not shuffle between opens.
    return byScore != 0
        ? byScore
        : a.$2.exercise.name.compareTo(b.$2.exercise.name);
  });
  return [for (final (_, option) in scored.take(count)) option];
}
