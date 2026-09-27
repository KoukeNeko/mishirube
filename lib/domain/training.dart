enum TrackingType { weightReps, reps, duration, distance }

enum ExerciseSource { builtIn, custom, imported }

/// Where on the body a muscle group is: what a filter or a body map
/// groups by.
enum BodyRegion { chest, shoulders, back, arms, core, legs }

/// A muscle group as training counts it: fine enough to tell the front
/// of the shoulder from the back, no finer than a set can be credited to.
///
/// The four general ones — back, shoulders, arms, core — name a region
/// without saying which part of it. The built-in library never uses
/// them; an exercise the user made or imported may.
enum MuscleGroup {
  chest(BodyRegion.chest),
  frontDelts(BodyRegion.shoulders),
  sideDelts(BodyRegion.shoulders),
  rearDelts(BodyRegion.shoulders),
  biceps(BodyRegion.arms),
  triceps(BodyRegion.arms),
  forearms(BodyRegion.arms),
  traps(BodyRegion.back),
  lats(BodyRegion.back),
  upperBack(BodyRegion.back),
  spinalErectors(BodyRegion.back),
  abs(BodyRegion.core),
  obliques(BodyRegion.core),
  glutes(BodyRegion.legs),
  quads(BodyRegion.legs),
  hamstrings(BodyRegion.legs),
  adductors(BodyRegion.legs),
  abductors(BodyRegion.legs),
  calves(BodyRegion.legs),
  back(BodyRegion.back),
  shoulders(BodyRegion.shoulders),
  arms(BodyRegion.arms),
  core(BodyRegion.core);

  const MuscleGroup(this.region);
  final BodyRegion region;

  /// A whole region rather than a muscle in it.
  bool get isGeneral =>
      this == back || this == shoulders || this == arms || this == core;

  /// Whether choosing this finds an exercise that trains [other]: the same
  /// muscle, or either one being the whole region the other is in — 背
  /// finds the lats, and the lats find an exercise marked only 背.
  bool covers(MuscleGroup other) =>
      this == other ||
      (region == other.region && (isGeneral || other.isGeneral));
}

enum Equipment {
  barbell,
  dumbbell,
  cable,
  machine,
  smithMachine,
  kettlebell,
  ezBar,
  trapBar,
  landmine,
  plate,
  band,
  bodyweight,
  cardio,
  other,
}

enum MovementPattern {
  squat,
  hinge,
  lunge,
  horizontalPush,
  horizontalPull,
  verticalPush,
  verticalPull,
  isolation,
  core,
  carry,
  conditioning,

  /// Kept for exercises made before lunges had their own pattern.
  unilateral,
}

/// How the two sides work.
enum Laterality {
  bilateral,

  /// One side at a time, the set done for each.
  unilateral,

  /// Left and right in turn within the set.
  alternating,
}

class ExerciseDefinition {
  const ExerciseDefinition({
    required this.id,
    required this.name,
    required this.equipment,
    required this.primaryMuscles,
    required this.pattern,
    this.aliases = const [],
    this.personalAliases = const [],
    this.secondaryMuscles = const [],
    this.trackingType = TrackingType.weightReps,
    this.source = ExerciseSource.builtIn,
    this.isFavorite = false,
    this.isHidden = false,
    this.isInHomeGym = true,
    this.lastPerformance,
    this.lastUsedDaysAgo,
    this.recordCount = 0,
    this.cues = const [],
    this.laterality = Laterality.bilateral,
    this.family = '',
    this.frames = const [],
  });

  final String id;
  final String name;
  final List<String> aliases;

  /// Names this user gave it; the catalog's own aliases stay untouched.
  final List<String> personalAliases;
  final Equipment equipment;
  final List<MuscleGroup> primaryMuscles;
  final List<MuscleGroup> secondaryMuscles;
  final MovementPattern pattern;
  final TrackingType trackingType;
  final ExerciseSource source;
  final bool isFavorite;

  /// Kept out of pickers and suggestions; history and old workouts keep it.
  final bool isHidden;
  final bool isInHomeGym;
  final String? lastPerformance;
  final int? lastUsedDaysAgo;
  final int recordCount;
  final List<String> cues;
  final Laterality laterality;

  /// The movement it is a version of — `bench-press` for a barbell,
  /// dumbbell or machine press — so a swap stays the same movement.
  /// Empty when nobody said.
  final String family;

  /// Its demonstration, as the poses of one repetition in order; empty
  /// when there is none.
  final List<String> frames;

  /// The same exercise whatever its usage figures: identity is the stable
  /// id, so a definition reloaded from storage equals the one on screen.
  @override
  bool operator ==(Object other) =>
      other is ExerciseDefinition && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The plan side of training: editing it never rewrites finished workouts.
/// One planned set: its weight and reps.
typedef SetLoad = ({double weightKg, int reps});

/// One exercise of a finished workout as corrected: the sets it was done
/// at, and the exercise as it was recorded, which [was] is null for one
/// added while correcting.
typedef WorkoutCorrection = ({
  ExerciseDefinition exercise,
  ExerciseSession? was,
  List<SetLoad> loads,
});

class PlannedExercise {
  const PlannedExercise({
    required this.exercise,
    required this.sets,
    required this.reps,
    required this.targetWeightKg,
    required this.progressionLabel,
    this.rir,
    this.isUnilateral = false,
    this.joinsNext = false,
    this.setLoads,
  });

  /// A plan of [loads], set by set: its sets, reps and weight read from
  /// them (the heaviest set's), and the loads kept only when the sets
  /// differ.
  factory PlannedExercise.ofLoads(
    PlannedExercise planned,
    List<SetLoad> loads,
  ) {
    final heaviest = loads.reduce((a, b) => b.weightKg > a.weightKg ? b : a);
    final uniform = loads.every((load) => load == loads.first);
    return PlannedExercise(
      exercise: planned.exercise,
      sets: loads.length,
      reps: heaviest.reps,
      targetWeightKg: heaviest.weightKg,
      progressionLabel: planned.progressionLabel,
      rir: planned.rir,
      isUnilateral: planned.isUnilateral,
      joinsNext: planned.joinsNext,
      setLoads: uniform ? null : List.unmodifiable(loads),
    );
  }

  final ExerciseDefinition exercise;
  final int sets;
  final int reps;
  final double targetWeightKg;
  final String progressionLabel;
  final int? rir;
  final bool isUnilateral;

  /// Done in turn with the exercise after it, a set of each before the
  /// rest: a superset. A run of these is one superset.
  final bool joinsNext;

  /// Each set's weight and reps when they differ from set to set; null
  /// when every set is [reps] at [targetWeightKg].
  final List<SetLoad>? setLoads;

  /// Every set's weight and reps, set by set.
  List<SetLoad> get loads =>
      setLoads ?? List.filled(sets, (weightKg: targetWeightKg, reps: reps));

  /// A new reps or weight makes every set alike again; a new number of
  /// sets keeps the sets' own loads, dropping the last or repeating it.
  PlannedExercise copyWith({
    int? sets,
    int? reps,
    ExerciseDefinition? exercise,
    double? targetWeightKg,
    bool? joinsNext,
  }) {
    final own = setLoads;
    final count = sets ?? this.sets;
    return PlannedExercise(
      exercise: exercise ?? this.exercise,
      sets: count,
      reps: reps ?? this.reps,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      progressionLabel: progressionLabel,
      rir: rir,
      isUnilateral: isUnilateral,
      joinsNext: joinsNext ?? this.joinsNext,
      setLoads: own == null || reps != null || targetWeightKg != null
          ? null
          : [
              for (var i = 0; i < count; i++)
                own[i < own.length ? i : own.length - 1],
            ],
    );
  }
}

class Routine {
  const Routine({
    required this.id,
    required this.name,
    required this.programName,
    required this.estimatedMinutes,
    required this.lastCompletedLabel,
    required this.exercises,
  });

  final String id;
  final String name;
  final String programName;
  final int estimatedMinutes;
  final String lastCompletedLabel;
  final List<PlannedExercise> exercises;

  int get totalSets => exercises.fold(0, (sum, item) => sum + item.sets);

  /// A renamed template; the id stays, so finished workouts still point
  /// at the same template.
  Routine renamed(String name) => Routine(
    id: id,
    name: name,
    programName: programName,
    estimatedMinutes: estimatedMinutes,
    lastCompletedLabel: lastCompletedLabel,
    exercises: exercises,
  );

  Routine copyWith({List<PlannedExercise>? exercises}) => Routine(
    id: id,
    name: name,
    programName: programName,
    estimatedMinutes: estimatedMinutes,
    lastCompletedLabel: lastCompletedLabel,
    exercises: exercises ?? this.exercises,
  );
}

enum SetType { working, warmup, drop, failure }

/// How a finished workout felt, as the lifter rates it afterwards. It
/// feeds the next suggestion: after a workout that was too much, the
/// weight is not raised.
enum Workload { tooLight, right, tooHard }

/// The actual side of training: what was really lifted today.
class WorkoutSet {
  WorkoutSet({
    required this.weightKg,
    required this.reps,
    required this.previousWeightKg,
    required this.previousReps,
    this.rir,
    this.rpe,
    this.type = SetType.working,
    this.durationSeconds,
    this.distanceMeters,
    this.isDone = false,
  });

  final double weightKg;
  final int reps;
  final double previousWeightKg;
  final int previousReps;
  final int? rir;
  final double? rpe;
  final SetType type;
  final int? durationSeconds;
  final double? distanceMeters;
  bool isDone;
}

class ExerciseSession {
  ExerciseSession({
    required this.exercise,
    required this.sets,
    this.isPersonalRecordCandidate = false,
    this.joinsNext = false,
  });

  final ExerciseDefinition exercise;
  final List<WorkoutSet> sets;
  final bool isPersonalRecordCandidate;

  /// Done in turn with the exercise after it; see
  /// [PlannedExercise.joinsNext].
  bool joinsNext;

  int get completedSets => sets.where((set) => set.isDone).length;
  bool get isComplete => completedSets == sets.length;

  int? get nextSetIndex {
    final index = sets.indexWhere((set) => !set.isDone);
    return index < 0 ? null : index;
  }
}

class WorkoutSession {
  WorkoutSession({
    required this.id,
    required this.routineName,
    required this.startedAt,
    required this.exercises,
    this.routineId,
    this.notes,
  });

  final String id;
  final String? routineId;
  final String routineName;

  /// What the user wrote about this workout.
  String? notes;

  /// How it felt, once rated; null until then.
  Workload? workload;
  final DateTime startedAt;
  final List<ExerciseSession> exercises;
  int currentExerciseIndex = 0;
  DateTime? finishedAt;
  DateTime? pausedAt;
  Duration pausedTotal = Duration.zero;

  bool get isPaused => pausedAt != null;

  /// Opened but not yet under way: paused since it was started, with no
  /// set done, so its sets and weights can be looked over first.
  bool get isReady =>
      pausedAt == startedAt &&
      pausedTotal == Duration.zero &&
      completedSets == 0;

  ExerciseSession get currentExercise => exercises[currentExerciseIndex];

  /// The exercises done in turn with the one at [index], in order: just
  /// that one when it is in no superset.
  List<int> supersetOf(int index) {
    var first = index;
    while (first > 0 && exercises[first - 1].joinsNext) {
      first--;
    }
    var last = index;
    while (last < exercises.length - 1 && exercises[last].joinsNext) {
      last++;
    }
    return [for (var i = first; i <= last; i++) i];
  }

  /// Whether a set of the exercise at [index] is followed by a rest: it
  /// is, unless a later exercise of its superset still has a set to do
  /// this round.
  bool restsAfter(int index) =>
      supersetOf(index)
          .where((other) => other > index)
          .every((other) => exercises[other].nextSetIndex == null);

  int get completedSets =>
      exercises.fold(0, (sum, item) => sum + item.completedSets);

  int get completedExercises =>
      exercises.where((item) => item.isComplete).length;

  int get totalSets => exercises.fold(0, (sum, item) => sum + item.sets.length);

  /// Active training time: a running pause freezes the clock and finished
  /// pauses are subtracted.
  Duration elapsedAt(DateTime now) =>
      (finishedAt ?? pausedAt ?? now).difference(startedAt) - pausedTotal;
}

/// A candidate replacement for an exercise and why it is a fair swap.
class SubstitutionOption {
  const SubstitutionOption({required this.exercise, required this.reasons});

  final ExerciseDefinition exercise;
  final List<SubstitutionReason> reasons;
}

/// Why a swap was offered, or what changes with it; the screen puts it
/// into words.
sealed class SubstitutionReason {
  const SubstitutionReason();
}

/// The same movement pattern.
final class SamePattern extends SubstitutionReason {
  const SamePattern(this.pattern);

  final MovementPattern pattern;
}

/// Some of the same muscles, when the pattern differs.
final class SameMuscles extends SubstitutionReason {
  const SameMuscles(this.muscles);

  final List<MuscleGroup> muscles;
}

/// Equipment the user's gym has.
final class EquipmentAvailable extends SubstitutionReason {
  const EquipmentAvailable(this.equipment);

  final Equipment equipment;
}

/// Its sets are recorded another way.
final class TrackingChanges extends SubstitutionReason {
  const TrackingChanges(this.trackingType);

  final TrackingType trackingType;
}

/// Different equipment, so the weight does not carry over.
final class EquipmentChanges extends SubstitutionReason {
  const EquipmentChanges(this.equipment);

  final Equipment equipment;
}

/// One side at a time, so the reps do not carry over.
final class OneSideAtATime extends SubstitutionReason {
  const OneSideAtATime();
}
