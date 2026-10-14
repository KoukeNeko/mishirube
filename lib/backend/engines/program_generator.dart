import '../../domain/domain.dart';
import 'program_slots.dart';
import 'training_metrics.dart';

export 'program_slots.dart' show WorkoutKind;

/// Bumped whenever a rule below changes what a request produces.
const programGeneratorVersion = 2;

/// How many days a week a program can be for.
const programMinDays = 2;
const programMaxDays = 6;

/// The lengths of a workout a program can be asked for, in minutes.
const programMinutes = [30, 45, 60, 75, 90];

/// What the lifter is after. It moves the reps and the order of
/// importance, not the exercises.
enum ProgramGoal { general, muscle, strength }

/// How long the lifter has trained. It decides how much a workout holds,
/// how far from failure the sets are meant to stop, and whether the lifts
/// start with a machine or a dumbbell instead of a barbell.
enum ProgramLevel { beginner, intermediate, advanced }

/// Where the lifter trains, which decides the equipment a program may use.
enum ProgramPlace {
  gym,
  dumbbells,
  bodyweight;

  Set<Equipment> get equipment => switch (this) {
    gym => Equipment.values.toSet(),
    dumbbells => const {
      Equipment.dumbbell,
      Equipment.band,
      Equipment.bodyweight,
    },
    bodyweight => const {Equipment.bodyweight},
  };

  /// The smallest place that has everything in [used].
  static ProgramPlace using(Set<Equipment> used) => values.reversed.firstWhere(
    (place) => place.equipment.containsAll(used),
    orElse: () => gym,
  );

  /// The place whose equipment is [equipment], the gym for any other.
  static ProgramPlace of(Set<Equipment> equipment) => values.firstWhere(
    (place) =>
        place.equipment.length == equipment.length &&
        place.equipment.containsAll(equipment),
    orElse: () => gym,
  );
}

/// Everything a program is built from.
class ProgramRequest {
  const ProgramRequest({
    required this.goal,
    required this.level,
    required this.days,
    required this.minutes,
    required this.equipment,
    this.variant = 0,
  });

  /// The answers before anything is known about the lifter.
  factory ProgramRequest.initial() => ProgramRequest(
    goal: ProgramGoal.muscle,
    level: ProgramLevel.intermediate,
    days: 3,
    minutes: 60,
    equipment: ProgramPlace.gym.equipment,
  );

  final ProgramGoal goal;
  final ProgramLevel level;

  /// Workouts a week, within [programMinDays] and [programMaxDays].
  final int days;

  /// How long a workout may take, warm-up included.
  final int minutes;

  /// What the lifter can train with; an exercise needing anything else is
  /// not offered.
  final Set<Equipment> equipment;

  /// Which of the nearly-as-good choices to take: the same request with
  /// another variant gives a different program, never a worse-ordered one.
  final int variant;

  ProgramRequest copyWith({
    ProgramGoal? goal,
    ProgramLevel? level,
    int? days,
    int? minutes,
    Set<Equipment>? equipment,
    int? variant,
  }) => ProgramRequest(
    goal: goal ?? this.goal,
    level: level ?? this.level,
    days: days ?? this.days,
    minutes: minutes ?? this.minutes,
    equipment: equipment ?? this.equipment,
    variant: variant ?? this.variant,
  );
}

/// Finished workouts, within [_habitWindow], from which what the lifter
/// does is taken as a way of training.
const _habitWorkouts = 4;
const _habitWindow = Duration(days: 56);

/// [base] with the days a week, the length of a workout and the place
/// that match how the lifter has been training: from their finished
/// workouts of the last eight weeks, and left as it is when there are too
/// few to show a pattern. Neither goal nor level is guessed.
ProgramRequest suggestProgramRequest(
  Iterable<WorkoutSession> finished,
  DateTime now, {
  required ProgramRequest base,
}) {
  final recent = [
    for (final workout in finished)
      if (workout.finishedAt != null &&
          now.difference(workout.startedAt) <= _habitWindow)
        workout,
  ];
  if (recent.length < _habitWorkouts) return base;

  final oldest = recent
      .map((workout) => workout.startedAt)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  final weeks = (now.difference(oldest).inDays / 7).ceil().clamp(1, 8);
  final days = (recent.length / weeks).round().clamp(
    programMinDays,
    programMaxDays,
  );

  // A workout left open for hours, or stopped after a minute, says
  // nothing about how long the lifter trains.
  final minutes = [
    for (final workout in recent)
      if (workout.elapsedAt(now).inMinutes case final length
          when length >= 15 && length <= 180)
        length,
  ]..sort();
  final typical = minutes.isEmpty ? base.minutes : minutes[minutes.length ~/ 2];

  final used = {
    for (final workout in recent)
      for (final session in workout.exercises) session.exercise.equipment,
  };
  return base.copyWith(
    days: days,
    minutes: programMinutes.reduce(
      (a, b) => (a - typical).abs() <= (b - typical).abs() ? a : b,
    ),
    equipment: used.isEmpty
        ? base.equipment
        : ProgramPlace.using(used).equipment,
  );
}

/// One workout of a program: what kind it is, which of its kind (the
/// second upper-body day is number 1), and the exercises as planned.
class GeneratedWorkout {
  const GeneratedWorkout({
    required this.kind,
    required this.index,
    required this.exercises,
    required this.length,
  });

  final WorkoutKind kind;

  /// Zero-based among the workouts of the same kind.
  final int index;
  final List<PlannedExercise> exercises;

  /// How long it takes as planned, warm-up not counted.
  final Duration length;

  int get totalSets => exercises.fold(0, (sum, item) => sum + item.sets);
}

class GeneratedProgram {
  const GeneratedProgram(this.workouts);

  final List<GeneratedWorkout> workouts;

  /// How many of each kind there are, to tell a lone workout from one of
  /// several that need a letter after the name.
  int countOf(WorkoutKind kind) =>
      workouts.where((workout) => workout.kind == kind).length;

  /// Working sets a week for each muscle, counted the way the rest of the
  /// app counts them: for an exercise's primary muscles only.
  List<(MuscleGroup, int)> get weeklySets => setsByMuscle([
    for (final workout in workouts)
      for (final planned in workout.exercises) (planned.exercise, planned.sets),
  ]);
}

/// The kinds of workout a week of [days] is made of. Every muscle is
/// reached about twice a week, which is what the training research
/// supports for the same weekly sets, except where there are only two
/// days (everything each day) or six (each kind twice).
List<WorkoutKind> splitFor(int days) => switch (days.clamp(
  programMinDays,
  programMaxDays,
)) {
  2 => const [WorkoutKind.fullBody, WorkoutKind.fullBody],
  3 => const [WorkoutKind.fullBody, WorkoutKind.fullBody, WorkoutKind.fullBody],
  4 => const [
    WorkoutKind.upper,
    WorkoutKind.lower,
    WorkoutKind.upper,
    WorkoutKind.lower,
  ],
  5 => const [
    WorkoutKind.upper,
    WorkoutKind.lower,
    WorkoutKind.push,
    WorkoutKind.pull,
    WorkoutKind.legs,
  ],
  _ => const [
    WorkoutKind.push,
    WorkoutKind.pull,
    WorkoutKind.legs,
    WorkoutKind.push,
    WorkoutKind.pull,
    WorkoutKind.legs,
  ],
};

/// Sets, reps and reps in reserve one slot is planned with.
typedef SlotScheme = ({int sets, int reps, int rir});

/// What a slot of [role] is planned with, as `research/101-program-
/// generation.md` sets out. Strength gets fewer reps at a heavier load,
/// with 2-3 sets of the main lift (ACSM position stand 2026, Med Sci
/// Sports Exerc 58(4):851-872); muscle gets 8-12 reps and enough sets for
/// the week to reach about ten a muscle; every set stops short of failure,
/// which nothing shows to be better, and a newcomer, whose guess at reps
/// left is the least reliable (Halperin 2022, Sports Med 52(2):377-390),
/// is given one set less on the smaller work and a reserve of three.
SlotScheme schemeFor(ProgramGoal goal, ProgramLevel level, SlotRole role) {
  final isBeginner = level == ProgramLevel.beginner;
  final isAdvanced = level == ProgramLevel.advanced;
  final base = switch ((goal, role)) {
    (ProgramGoal.strength, SlotRole.main) => (sets: 3, reps: 5, rir: 2),
    (ProgramGoal.strength, SlotRole.secondary) => (sets: 3, reps: 8, rir: 2),
    (ProgramGoal.strength, SlotRole.accessory) => (sets: 3, reps: 10, rir: 1),
    (ProgramGoal.strength, SlotRole.core) => (sets: 3, reps: 10, rir: 1),
    (ProgramGoal.muscle, SlotRole.main) => (sets: 4, reps: 8, rir: 2),
    (ProgramGoal.muscle, SlotRole.secondary) => (sets: 3, reps: 10, rir: 2),
    (ProgramGoal.muscle, SlotRole.accessory) => (sets: 3, reps: 12, rir: 1),
    (ProgramGoal.muscle, SlotRole.core) => (sets: 3, reps: 12, rir: 1),
    (ProgramGoal.general, SlotRole.main) => (sets: 3, reps: 8, rir: 2),
    (ProgramGoal.general, SlotRole.secondary) => (sets: 3, reps: 10, rir: 2),
    (ProgramGoal.general, SlotRole.accessory) => (sets: 2, reps: 12, rir: 2),
    (ProgramGoal.general, SlotRole.core) => (sets: 2, reps: 12, rir: 2),
  };
  if (isBeginner) {
    return (
      sets: role == SlotRole.main
          ? (base.sets < 3 ? base.sets : 3)
          : (base.sets - 1 < 2 ? 2 : base.sets - 1),
      reps: base.reps + (goal == ProgramGoal.strength ? 0 : 2),
      rir: base.rir + 1,
    );
  }
  if (isAdvanced && role == SlotRole.main && goal == ProgramGoal.strength) {
    return (sets: base.sets + 1, reps: base.reps, rir: base.rir);
  }
  return base;
}

/// Most exercises one workout holds, by experience. The time a lifter has
/// decides how many of them fit; this only keeps a newcomer's workout from
/// holding more than can be learned at once.
int maxExercisesFor(ProgramLevel level) => switch (level) {
  ProgramLevel.beginner => 6,
  ProgramLevel.intermediate => 8,
  ProgramLevel.advanced => 9,
};

/// Time set aside in a workout for warming up and changing over, before
/// the sets are counted.
const programWarmup = Duration(minutes: 5);

/// Fewest exercises a workout is cut down to; below this it is not a
/// workout of that kind any more.
const programMinExercises = 3;

/// Seconds a held exercise (a plank) is planned for.
const heldSeconds = 45;
const heldSecondsBeginner = 30;

/// Builds a program for [request] from [library].
///
/// Nothing is random, and the same request over the same library always
/// gives the same program. An exercise comes from its slot's pool first,
/// after the lifter's own favourites; with nothing in the pool that the
/// equipment allows, from any exercise of the same movement for the same
/// muscle, and one the lifter has been doing lately comes before the
/// rest of the pool. [historyOf] holds what the lifter has done of an
/// exercise: it is planned at the weight its reps could be done with,
/// worked out from the best set so far, and any other with no weight at
/// all, since a load nobody has tried is a guess. [progressionLabel] is
/// what each planned exercise says it will do next, and [restOf] the rest
/// after an exercise.
GeneratedProgram generateProgram(
  ProgramRequest request, {
  required Iterable<ExerciseDefinition> library,
  ExerciseHistory Function(ExerciseDefinition exercise) historyOf = _neverDone,
  String progressionLabel = '',
  Duration Function(ExerciseDefinition exercise) restOf = restAfter,
}) {
  final byId = {for (final exercise in library) exercise.id: exercise};
  final inProgram = <String>{};
  final seen = <WorkoutKind, int>{};
  final workouts = <GeneratedWorkout>[];
  final budget = Duration(minutes: request.minutes) - programWarmup;

  for (final kind in splitFor(request.days)) {
    final index = seen[kind] = (seen[kind] ?? -1) + 1;
    final inWorkout = <String>{};
    final planned = <PlannedExercise>[];
    for (final slot in kind.slots(index).take(maxExercisesFor(request.level))) {
      final exercise = _choose(
        slot,
        request,
        library,
        byId: byId,
        inProgram: inProgram,
        inWorkout: inWorkout,
      );
      if (exercise == null) continue;
      inWorkout.add(exercise.id);
      planned.add(
        _plan(
          exercise,
          schemeFor(request.goal, request.level, slot.role),
          request.level,
          historyOf(exercise),
          progressionLabel,
        ),
      );
    }
    final fitted = _fit(planned, budget, restOf);
    if (fitted.isEmpty) continue;
    // Only what stayed in the workout counts as used: an exercise cut for
    // time is still free for the next one.
    inProgram.addAll(fitted.map((planned) => planned.exercise.id));
    workouts.add(
      GeneratedWorkout(
        kind: kind,
        index: index,
        exercises: fitted,
        length: plannedDuration(fitted, restOf: restOf),
      ),
    );
  }
  return GeneratedProgram(workouts);
}

ExerciseHistory _neverDone(ExerciseDefinition exercise) =>
    ExerciseHistory.empty;

/// How many of a pool's best exercises are near enough to each other to
/// swap: the rest are for when nothing better fits the equipment.
const _swappable = 3;

/// The exercise for [slot]: the lifter's favourites of the right movement
/// and muscle, then the pool in order. One already used in the program is
/// passed over for a fresh one among the best few, and taken again when
/// there is none, since the same squat on three days is a program and a
/// different one each day is not. With nothing in the pool that the
/// equipment allows, a version of a pool exercise, then any exercise of
/// the same movement for the same muscle.
ExerciseDefinition? _choose(
  Slot slot,
  ProgramRequest request,
  Iterable<ExerciseDefinition> library, {
  required Map<String, ExerciseDefinition> byId,
  required Set<String> inProgram,
  required Set<String> inWorkout,
}) {
  bool allowed(ExerciseDefinition exercise) =>
      !exercise.isHidden &&
      !inWorkout.contains(exercise.id) &&
      request.equipment.contains(exercise.equipment) &&
      _isPlannable(exercise, slot.role);
  bool fits(ExerciseDefinition exercise) =>
      exercise.pattern == slot.pattern &&
      exercise.primaryMuscles.any(slot.muscles.contains);

  final order = request.level == ProgramLevel.beginner
      ? slot.beginnerPool ?? slot.pool
      : slot.pool;
  final favourites = [
    for (final exercise in library)
      if (exercise.isFavorite && allowed(exercise) && fits(exercise)) exercise,
  ]..sort((a, b) => a.id.compareTo(b.id));
  final practised =
      [
        for (final exercise in library)
          if (_isPractised(exercise) &&
              allowed(exercise) &&
              fits(exercise) &&
              !exercise.isFavorite)
            exercise,
      ]..sort((a, b) {
        final byUse = b.recordCount.compareTo(a.recordCount);
        return byUse != 0 ? byUse : a.id.compareTo(b.id);
      });
  final staples = [
    for (final id in order)
      if (byId[id] case final exercise? when allowed(exercise)) exercise,
  ];
  final candidates = {...favourites, ...practised, ...staples}.toList();
  if (candidates.isNotEmpty) {
    final best = candidates.take(_swappable).toList();
    final first = request.variant % best.length;
    final ordered = [...best.skip(first), ...best.take(first)];
    return ordered.firstWhere(
      (exercise) => !inProgram.contains(exercise.id),
      orElse: () => ordered.first,
    );
  }

  final families = {
    for (final id in slot.pool)
      if (byId[id]?.family case final family? when family.isNotEmpty) family,
  };
  final others =
      [
        for (final exercise in library)
          if (allowed(exercise) &&
              !inProgram.contains(exercise.id) &&
              fits(exercise))
            exercise,
      ]..sort((a, b) {
        final byFamily = (families.contains(a.family) ? 0 : 1).compareTo(
          families.contains(b.family) ? 0 : 1,
        );
        if (byFamily != 0) return byFamily;
        final byUse = b.recordCount.compareTo(a.recordCount);
        return byUse != 0 ? byUse : a.id.compareTo(b.id);
      });
  return others.firstOrNull;
}

/// Sessions of an exercise, within the estimate window, that make it part
/// of how the lifter trains rather than something tried once.
const _practisedSessions = 2;

/// Whether the lifter has been doing [exercise] lately.
bool _isPractised(ExerciseDefinition exercise) =>
    exercise.recordCount >= _practisedSessions &&
    (exercise.lastUsedDaysAgo ?? oneRepMaxWindow.inDays + 1) <=
        oneRepMaxWindow.inDays;

/// Whether a slot can plan [exercise]: one measured in weight and reps,
/// reps alone or, for trunk work, a time held.
bool _isPlannable(ExerciseDefinition exercise, SlotRole role) =>
    switch (exercise.trackingType) {
      TrackingType.weightReps || TrackingType.reps => true,
      TrackingType.duration => role == SlotRole.core,
      _ => false,
    };

PlannedExercise _plan(
  ExerciseDefinition exercise,
  SlotScheme scheme,
  ProgramLevel level,
  ExerciseHistory history,
  String progressionLabel,
) {
  final type = exercise.trackingType;
  return PlannedExercise(
    exercise: exercise,
    sets: scheme.sets,
    reps: type.usesReps ? scheme.reps : 0,
    targetWeightKg: type.usesWeight ? _loadFor(type, history, scheme) : 0,
    targetSeconds: type.usesTime
        ? (level == ProgramLevel.beginner ? heldSecondsBeginner : heldSeconds)
        : null,
    progressionLabel: progressionLabel,
    rir: scheme.rir,
    isUnilateral: exercise.laterality != Laterality.bilateral,
  );
}

/// The weight to plan [scheme] at. The heaviest set of the last session
/// says little about eight reps when it was a set of three, so the weight
/// comes from the best estimated max in the history; past ten reps to
/// failure, where that estimate stops holding, from the last session's
/// heaviest set when it was done for about as many reps. Otherwise none.
double _loadFor(TrackingType type, ExerciseHistory history, SlotScheme scheme) {
  final max = history.estimatedOneRepMaxKg ?? history.last?.oneRepMaxKg;
  if (type == TrackingType.weightReps && max != null) {
    final weight = weightForReps(max, reps: scheme.reps, rir: scheme.rir);
    if (weight != null) return weight;
  }
  final last = history.last;
  final isAboutAsManyReps =
      type != TrackingType.weightReps || (last?.reps ?? 0) >= scheme.reps - 2;
  return last != null && isAboutAsManyReps ? last.weightKg : 0;
}

/// Cuts a workout down to [budget]: whole exercises from the end first,
/// the least important, then a set at a time from the last one with more
/// than two, never below two sets or three exercises. A workout that is
/// still too long after that is left as it is, since a shorter one would
/// not be one.
List<PlannedExercise> _fit(
  List<PlannedExercise> planned,
  Duration budget,
  Duration Function(ExerciseDefinition exercise) restOf,
) {
  final fitted = [...planned];
  bool isOver() => plannedDuration(fitted, restOf: restOf) > budget;
  while (isOver() && fitted.length > programMinExercises) {
    fitted.removeLast();
  }
  while (isOver()) {
    final trimmable = [
      for (var i = 0; i < fitted.length; i++)
        if (fitted[i].sets > 2) i,
    ];
    if (trimmable.isEmpty) break;
    final at = trimmable.last;
    fitted[at] = fitted[at].copyWith(sets: fitted[at].sets - 1);
  }
  return fitted;
}
