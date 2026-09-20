import '../../domain/domain.dart';

/// Bumped whenever the ranking below changes.
const substitutionEngineVersion = 1;

const _defaultCandidateCount = 3;

/// Candidate swaps for [exercise], best first, each with the reasons that
/// put it there.
///
/// A fair swap keeps the stimulus, not the name: the same movement
/// pattern first, then the muscles worked, then equipment the user
/// actually has. Load is never carried across equipment; when the set-up
/// differs the reasons say so instead of implying the same weights.
List<SubstitutionOption> substitutesFor(
  ExerciseDefinition exercise,
  Iterable<ExerciseDefinition> catalog, {
  int count = _defaultCandidateCount,
}) {
  final scored = <(int, SubstitutionOption)>[];
  for (final candidate in catalog) {
    if (candidate.id == exercise.id) continue;
    final sharedMuscles = candidate.primaryMuscles
        .where(exercise.primaryMuscles.contains)
        .toList();
    final samePattern = candidate.pattern == exercise.pattern;
    if (!samePattern && sharedMuscles.isEmpty) continue;

    final reasons = <String>[
      if (samePattern)
        '同為${exercise.pattern.label}模式'
      else
        '同樣練${sharedMuscles.map((muscle) => muscle.label).join('、')}',
      if (candidate.isInHomeGym) '${candidate.equipment.label}可用',
      if (candidate.trackingType != exercise.trackingType)
        '記錄方式改為${candidate.trackingType.label}'
      else if (candidate.equipment != exercise.equipment)
        '換${candidate.equipment.label}，重量需重新設定',
      if (candidate.pattern == MovementPattern.unilateral &&
          exercise.pattern != MovementPattern.unilateral)
        '單側動作，次數請重新設定',
    ];
    final score =
        (samePattern ? 4 : 0) +
        sharedMuscles.length +
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
