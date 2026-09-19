import 'package:flutter/material.dart';

import '../app/theme.dart';

enum RecordCategory {
  training('訓練', AppColors.training),
  nutrition('飲食', AppColors.nutrition),
  body('身體', AppColors.body),
  wellness('狀態', AppColors.wellness);

  const RecordCategory(this.label, this.color);

  final String label;
  final Color color;
}

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
    this.secondaryMuscles = const [],
    this.trackingType = TrackingType.weightReps,
    this.source = ExerciseSource.builtIn,
    this.isFavorite = false,
    this.isInHomeGym = true,
    this.lastPerformance,
    this.lastUsedDaysAgo,
    this.recordCount = 0,
    this.cues = const [],
  });

  final String id;
  final String name;
  final List<String> aliases;
  final Equipment equipment;
  final List<MuscleGroup> primaryMuscles;
  final List<MuscleGroup> secondaryMuscles;
  final MovementPattern pattern;
  final TrackingType trackingType;
  final ExerciseSource source;
  final bool isFavorite;
  final bool isInHomeGym;
  final String? lastPerformance;
  final int? lastUsedDaysAgo;
  final int recordCount;
  final List<String> cues;

  String get muscleSummary => primaryMuscles.map((m) => m.label).join('、');

  bool matchesQuery(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;
    return [
      name,
      ...aliases,
      equipment.label,
    ].any((term) => term.toLowerCase().contains(normalizedQuery));
  }
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

  Routine copyWith({List<PlannedExercise>? exercises}) => Routine(
    id: id,
    name: name,
    programName: programName,
    estimatedMinutes: estimatedMinutes,
    lastCompletedLabel: lastCompletedLabel,
    exercises: exercises ?? this.exercises,
  );
}

/// The actual side of training: what was really lifted today.
class WorkoutSet {
  WorkoutSet({
    required this.weightKg,
    required this.reps,
    required this.previousWeightKg,
    required this.previousReps,
    this.rir,
  });

  final double weightKg;
  final int reps;
  final double previousWeightKg;
  final int previousReps;
  final int? rir;
  bool isDone = false;
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
    required this.routineName,
    required this.startedAt,
    required this.exercises,
  });

  final String routineName;
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

class FoodComponent {
  const FoodComponent({
    required this.name,
    required this.amountLabel,
    required this.source,
  });

  final String name;
  final String amountLabel;
  final String source;
}

class DishEntry {
  const DishEntry({
    required this.name,
    required this.quantityLabel,
    required this.subtitle,
    this.components = const [],
  });

  final String name;
  final String quantityLabel;
  final String subtitle;
  final List<FoodComponent> components;

  bool get isComposite => components.isNotEmpty;
}

class MealEvent {
  const MealEvent({
    required this.id,
    required this.name,
    required this.timeLabel,
    required this.kcal,
    required this.qualityTag,
    required this.dishes,
    required this.proteinGrams,
    required this.carbGrams,
    required this.fatGrams,
  });

  final String id;
  final String name;
  final String timeLabel;
  final int kcal;
  final String qualityTag;
  final List<DishEntry> dishes;
  final int proteinGrams;
  final int carbGrams;
  final int fatGrams;

  MealEvent copyWith({List<DishEntry>? dishes}) => MealEvent(
    id: id,
    name: name,
    timeLabel: timeLabel,
    kcal: kcal,
    qualityTag: qualityTag,
    dishes: dishes ?? this.dishes,
    proteinGrams: proteinGrams,
    carbGrams: carbGrams,
    fatGrams: fatGrams,
  );
}

class TimelineEntry {
  const TimelineEntry({
    required this.timeLabel,
    required this.category,
    required this.title,
    required this.detail,
    this.tags = const [],
  });

  final String timeLabel;
  final RecordCategory category;
  final String title;
  final String detail;
  final List<String> tags;
}

class TimelineDay {
  const TimelineDay({required this.label, required this.entries, this.warning});

  final String label;
  final List<TimelineEntry> entries;
  final String? warning;
}

class Insight {
  const Insight({required this.statement, required this.evidence});

  final String statement;
  final List<String> evidence;
}

/// A candidate replacement for an exercise and why it is a fair swap.
class SubstitutionOption {
  const SubstitutionOption({required this.exercise, required this.reasons});

  final ExerciseDefinition exercise;
  final List<String> reasons;
}
