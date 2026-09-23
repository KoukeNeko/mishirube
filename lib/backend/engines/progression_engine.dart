import '../../domain/domain.dart';
import '../../shared/format.dart';
import 'training_metrics.dart';

/// Bumped whenever a rule below changes, so a stored or exported result
/// can say which version produced it.
const progressionEngineVersion = 1;

/// Sessions whose reps must fall short before the weight comes down.
/// One bad day is a bad day; two in a row is the weight. Doing fewer
/// sets than planned is not one of these: the reps at that weight were
/// still there, the session was just shorter.
const sessionsBeforeDeload = 2;

/// How much a deload takes off, before rounding to something loadable.
const deloadShare = 0.9;

/// Reps in reserve at or below which a set counted as hard enough to be
/// worth adding weight after. Null means the user did not say, and the
/// reps alone decide.
const readyRir = 2;

/// What to do with an exercise next time.
enum ProgressionMove {
  /// Add weight: the plan was met with something in reserve.
  increase,

  /// Repeat it: close, but not met.
  hold,

  /// Take weight off: the plan has been missed repeatedly.
  deload,
}

/// What one session of an exercise actually came to, as the engine needs
/// it: the best working set and how many working sets were done.
class ExerciseAttempt {
  const ExerciseAttempt({
    required this.date,
    required this.weightKg,
    required this.reps,
    required this.workingSets,
    this.rir,
  });

  final DateTime date;
  final double weightKg;
  final int reps;
  final int workingSets;
  final int? rir;
}

/// What to do with an exercise next time, and why. The reason is part of
/// the suggestion: a number with no argument behind it is not advice.
class ProgressionSuggestion {
  const ProgressionSuggestion({
    required this.move,
    required this.targetWeightKg,
    required this.reps,
    required this.reason,
  });

  final ProgressionMove move;
  final double targetWeightKg;
  final int reps;

  /// Plain words for why, in terms of what the user did.
  final String reason;

  /// Whether it asks for anything to change at all.
  bool get changesWeight => move != ProgressionMove.hold;
}

/// What to do with [planned] next time, given [recent] attempts at it,
/// newest first. Null when there is nothing to go on: an engine that
/// cannot support a statement says nothing rather than guessing.
///
/// The rule is double progression against the plan: meet the planned
/// reps on every planned set with something left in reserve and the
/// weight goes up one step; miss the reps twice running and it comes
/// down; anything else repeats.
ProgressionSuggestion? suggestProgression({
  required PlannedExercise planned,
  required List<ExerciseAttempt> recent,
  double step = plateStepKg,
}) {
  if (recent.isEmpty) return null;
  final last = recent.first;
  final met = _met(last, planned);
  final rested = last.rir == null || last.rir! >= readyRir;

  if (met && rested) {
    return ProgressionSuggestion(
      move: ProgressionMove.increase,
      targetWeightKg: last.weightKg + step,
      reps: planned.reps,
      reason: _reasonFor(last, planned, added: step),
    );
  }

  final shortRun = recent
      .take(sessionsBeforeDeload)
      .where((attempt) => attempt.reps < planned.reps)
      .length;
  if (shortRun >= sessionsBeforeDeload &&
      recent.length >= sessionsBeforeDeload) {
    return ProgressionSuggestion(
      move: ProgressionMove.deload,
      targetWeightKg: roundToPlate(last.weightKg * deloadShare, step: step),
      reps: planned.reps,
      reason:
          '連續 $sessionsBeforeDeload 次沒做到 ${planned.reps} 下，'
          '先退一階把次數做滿。',
    );
  }

  return ProgressionSuggestion(
    move: ProgressionMove.hold,
    targetWeightKg: last.weightKg,
    reps: planned.reps,
    reason: switch (last) {
      _ when last.reps < planned.reps =>
        '上次 ${_sets(last)}，還沒做到 ${planned.reps} 下，先維持同重量。',
      _ when last.workingSets < planned.sets =>
        '上次只做了 ${last.workingSets} 組，先把 ${planned.sets} 組做滿再加重。',
      _ => '上次做滿了，但最後一組已經接近極限（RIR ${last.rir}），先維持同重量。',
    },
  );
}

bool _met(ExerciseAttempt attempt, PlannedExercise planned) =>
    attempt.workingSets >= planned.sets && attempt.reps >= planned.reps;

String _reasonFor(
  ExerciseAttempt last,
  PlannedExercise planned, {
  required double added,
}) {
  final reserve = last.rir == null ? '' : '，最後一組還留 ${last.rir} 下';
  return '上次 ${_sets(last)} 做滿了 ${planned.sets} × ${planned.reps}$reserve，'
      '可以加 ${formatWeight(added)} kg。';
}

/// How an attempt reads in a reason: `3 × 5`.
String _sets(ExerciseAttempt attempt) =>
    '${attempt.workingSets} × ${attempt.reps}';
