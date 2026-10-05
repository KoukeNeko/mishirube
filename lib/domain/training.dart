/// How the sets of an exercise are recorded, and so which figures each
/// one has.
enum TrackingType {
  /// Weight and reps.
  weightReps,

  /// Reps alone, as a push-up.
  reps,

  /// Time alone, as a plank.
  duration,

  /// Weight and time, as a weighted plank.
  weightDuration,

  /// Distance, and optionally the time it took.
  distance;

  bool get usesWeight => this == weightReps || this == weightDuration;

  bool get usesReps => this == weightReps || this == reps;

  /// Whether a set has a time: required for the timed kinds, optional for
  /// distance.
  bool get usesTime =>
      this == duration || this == weightDuration || this == distance;

  bool get usesDistance => this == distance;
}

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
  pullUpBar,
  rings,
  suspension,
  medicineBall,
  stabilityBall,
  foamRoller,
  sled,
  box,
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

  /// A lift of the Olympic kind: the snatch, the clean, the jerk and the
  /// pulls that train them.
  olympic,

  /// Moving a joint through its range, in reps, before or after training.
  mobility,

  /// A stretch held for time.
  stretch,

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

  /// The exercise whose poses these are, when they are not its own: a
  /// variant that shows the movement of the one it is a version of. Null
  /// for an exercise with its own poses, or with none.
  String? get demoFromId {
    final id = RegExp(r'/([^/]+)-\d+\.webp$')
        .firstMatch(frames.firstOrNull ?? '')
        ?.group(1);
    return id == this.id ? null : id;
  }

  /// The same exercise whatever its usage figures: identity is the stable
  /// id, so a definition reloaded from storage equals the one on screen.
  @override
  bool operator ==(Object other) =>
      other is ExerciseDefinition && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The plan side of training: editing it never rewrites finished workouts.
/// One planned set: the figures its exercise's [TrackingType] uses; the
/// others stay at 0 (weight, reps) or null (time, distance).
class SetLoad {
  const SetLoad({this.weightKg = 0, this.reps = 0, this.seconds, this.meters});

  final double weightKg;
  final int reps;
  final int? seconds;
  final double? meters;

  SetLoad copyWith({
    double? weightKg,
    int? reps,
    int? seconds,
    double? meters,
  }) => SetLoad(
    weightKg: weightKg ?? this.weightKg,
    reps: reps ?? this.reps,
    seconds: seconds ?? this.seconds,
    meters: meters ?? this.meters,
  );

  @override
  bool operator ==(Object other) =>
      other is SetLoad &&
      other.weightKg == weightKg &&
      other.reps == reps &&
      other.seconds == seconds &&
      other.meters == meters;

  @override
  int get hashCode => Object.hash(weightKg, reps, seconds, meters);

  @override
  String toString() =>
      'SetLoad($weightKg kg, $reps reps, $seconds s, $meters m)';
}

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
    this.targetSeconds,
    this.targetMeters,
  });

  /// A plan of [loads], set by set: its sets, reps, weight, time and
  /// distance read from them (the heaviest set's), and the loads kept only
  /// when the sets differ.
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
      targetSeconds: heaviest.seconds,
      targetMeters: heaviest.meters,
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

  /// The time each set is meant to last and the distance it covers, for
  /// the exercises recorded that way; null for the others.
  final int? targetSeconds;
  final double? targetMeters;
  final String progressionLabel;
  final int? rir;
  final bool isUnilateral;

  /// Done in turn with the exercise after it, a set of each before the
  /// rest: a superset. A run of these is one superset.
  final bool joinsNext;

  /// Each set's figures when they differ from set to set; null when every
  /// set is [reps] at [targetWeightKg], for [targetSeconds] and
  /// [targetMeters].
  final List<SetLoad>? setLoads;

  /// Every set's figures, set by set.
  List<SetLoad> get loads =>
      setLoads ??
      List.filled(
        sets,
        SetLoad(
          weightKg: targetWeightKg,
          reps: reps,
          seconds: targetSeconds,
          meters: targetMeters,
        ),
      );

  /// A new reps, weight, time or distance makes every set alike again; a
  /// new number of sets keeps the sets' own loads, dropping the last or
  /// repeating it.
  PlannedExercise copyWith({
    int? sets,
    int? reps,
    ExerciseDefinition? exercise,
    double? targetWeightKg,
    int? targetSeconds,
    double? targetMeters,
    bool? joinsNext,
  }) {
    final own = setLoads;
    final count = sets ?? this.sets;
    return PlannedExercise(
      exercise: exercise ?? this.exercise,
      sets: count,
      reps: reps ?? this.reps,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      targetSeconds: targetSeconds ?? this.targetSeconds,
      targetMeters: targetMeters ?? this.targetMeters,
      progressionLabel: progressionLabel,
      rir: rir,
      isUnilateral: isUnilateral,
      joinsNext: joinsNext ?? this.joinsNext,
      setLoads:
          own == null ||
              reps != null ||
              targetWeightKg != null ||
              targetSeconds != null ||
              targetMeters != null
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
