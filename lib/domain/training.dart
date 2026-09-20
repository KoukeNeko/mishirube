enum TrackingType {
  weightReps('重量 + 次數'),
  reps('次數'),
  duration('時間'),
  distance('距離');

  const TrackingType(this.label);

  final String label;
}

enum ExerciseSource {
  builtIn('內建'),
  custom('自訂'),
  imported('匯入');

  const ExerciseSource(this.label);

  final String label;
}

enum MuscleGroup {
  chest('胸'),
  back('背'),
  shoulders('肩'),
  quads('股四頭'),
  glutes('臀'),
  hamstrings('腿後'),
  arms('手臂'),
  core('核心'),
  calves('小腿'),
  spinalErectors('豎脊肌');

  const MuscleGroup(this.label);

  final String label;
}

enum Equipment {
  barbell('槓鈴'),
  dumbbell('啞鈴'),
  cable('纜繩'),
  machine('機械'),
  kettlebell('壺鈴'),
  bodyweight('徒手'),
  smithMachine('史密斯機');

  const Equipment(this.label);

  final String label;
}

enum MovementPattern {
  squat('深蹲'),
  hinge('髖伸'),
  horizontalPush('水平推'),
  horizontalPull('水平拉'),
  verticalPush('垂直推'),
  verticalPull('垂直拉'),
  unilateral('單側'),
  isolation('單關節');

  const MovementPattern(this.label);

  final String label;
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

  String get muscleSummary => primaryMuscles.map((m) => m.label).join('、');

  /// The same exercise whatever its usage figures: identity is the stable
  /// id, so a definition reloaded from storage equals the one on screen.
  @override
  bool operator ==(Object other) =>
      other is ExerciseDefinition && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The plan side of training: editing it never rewrites finished workouts.
class PlannedExercise {
  const PlannedExercise({
    required this.exercise,
    required this.sets,
    required this.reps,
    required this.targetWeightKg,
    required this.progressionLabel,
    this.rir,
    this.isUnilateral = false,
  });

  final ExerciseDefinition exercise;
  final int sets;
  final int reps;
  final double targetWeightKg;
  final String progressionLabel;
  final int? rir;
  final bool isUnilateral;

  PlannedExercise copyWith({int? sets}) => PlannedExercise(
    exercise: exercise,
    sets: sets ?? this.sets,
    reps: reps,
    targetWeightKg: targetWeightKg,
    progressionLabel: progressionLabel,
    rir: rir,
    isUnilateral: isUnilateral,
  );
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

enum SetType {
  working('工作組'),
  warmup('熱身組'),
  drop('遞減組'),
  failure('力竭組');

  const SetType(this.label);

  final String label;

  /// The kind without the word 組, for places that supply it themselves
  /// (「加入一組熱身」).
  String get kindLabel => label.replaceAll('組', '');
}

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
  });

  final ExerciseDefinition exercise;
  final List<WorkoutSet> sets;
  final bool isPersonalRecordCandidate;

  int get completedSets => sets.where((set) => set.isDone).length;
  bool get isComplete => completedSets == sets.length;

  int? get nextSetIndex {
    final index = sets.indexWhere((set) => !set.isDone);
    return index < 0 ? null : index;
  }

  bool get hasPersonalRecord => isPersonalRecordCandidate && completedSets > 0;
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
  final DateTime startedAt;
  final List<ExerciseSession> exercises;
  int currentExerciseIndex = 0;
  DateTime? finishedAt;
  DateTime? pausedAt;
  Duration pausedTotal = Duration.zero;

  bool get isPaused => pausedAt != null;

  ExerciseSession get currentExercise => exercises[currentExerciseIndex];

  int get completedSets =>
      exercises.fold(0, (sum, item) => sum + item.completedSets);

  int get completedExercises =>
      exercises.where((item) => item.isComplete).length;

  int get totalSets => exercises.fold(0, (sum, item) => sum + item.sets.length);

  int get personalRecords =>
      exercises.where((item) => item.hasPersonalRecord).length;

  /// Active training time: a running pause freezes the clock and finished
  /// pauses are subtracted.
  Duration elapsedAt(DateTime now) =>
      (finishedAt ?? pausedAt ?? now).difference(startedAt) - pausedTotal;
}

/// A candidate replacement for an exercise and why it is a fair swap.
class SubstitutionOption {
  const SubstitutionOption({required this.exercise, required this.reasons});

  final ExerciseDefinition exercise;
  final List<String> reasons;
}
