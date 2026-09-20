import '../../domain/domain.dart';
import '../engines/training_metrics.dart';
import '../storage/database.dart';
import '../storage/exercise_repository.dart';
import '../storage/routine_repository.dart';
import '../storage/workout_repository.dart';

/// Defaults for an exercise added on the fly, until the user edits it.
const _addedSets = 3;

/// What a template the user made themselves belongs to, where a seeded
/// one names its program.
const _ownProgramName = '自己的訓練';
const _addedReps = 10;
const _addedWeightKg = 20.0;

/// Running a workout: the rules that decide what a set means and what is
/// written when. Every change is committed as it happens, so a workout
/// survives the app being killed.
class TrainingService {
  TrainingService(this._db, this._workouts, this._exercises, this._routines);

  final AppDatabase _db;
  final WorkoutRepository _workouts;
  final ExerciseRepository _exercises;
  final RoutineRepository _routines;

  WorkoutSession? active() => _workouts.active(_exercise);

  WorkoutSession? lastFinished() => _workouts.lastFinished(_exercise);

  ExerciseDefinition _exercise(String id) => _exercises.byId(id)!;

  /// Starts [routine], carrying last time's numbers into each exercise.
  WorkoutSession start(Routine routine) {
    final workout = WorkoutSession(
      id: _db.newId(),
      routineId: routine.id,
      routineName: routine.name,
      startedAt: _db.now(),
      exercises: [for (final planned in routine.exercises) plan(planned)],
    );
    _workouts.save(workout, action: 'start');
    return workout;
  }

  /// Builds one exercise of a workout. "Last time" is the heaviest working
  /// set of the last finished session; with no history the plan itself is
  /// the reference, and a heavier target counts as a record attempt.
  ExerciseSession plan(PlannedExercise planned) {
    final last = _exercises.history(planned.exercise.id).last;
    final previousWeight = last?.weightKg ?? planned.targetWeightKg;
    final previousReps = last?.reps ?? planned.reps;
    return ExerciseSession(
      exercise: planned.exercise,
      isPersonalRecordCandidate: planned.targetWeightKg > previousWeight,
      sets: List.generate(
        planned.sets,
        (_) => WorkoutSet(
          weightKg: planned.targetWeightKg,
          reps: planned.reps,
          rir: planned.rir,
          previousWeightKg: previousWeight,
          previousReps: previousReps,
        ),
      ),
    );
  }

  /// Marks the next pending set of the current exercise as done and moves
  /// on to the next unfinished exercise once every set is logged.
  WorkoutSet? completeNextSet(WorkoutSession workout) {
    final exercise = workout.currentExercise;
    final setIndex = exercise.nextSetIndex;
    if (setIndex == null) return null;
    final completed = exercise.sets[setIndex]..isDone = true;
    if (exercise.isComplete) {
      final next = workout.exercises.indexWhere((item) => !item.isComplete);
      if (next >= 0) workout.currentExerciseIndex = next;
    }
    _workouts.save(workout, action: 'complete_set');
    return completed;
  }

  /// Adds one more set to the exercise being done. A warm-up or drop set
  /// starts at a share of the working weight, rounded to the plates, for
  /// the user to adjust.
  WorkoutSet addSet(WorkoutSession workout, SetType type) {
    final exercise = workout.currentExercise;
    final working = exercise.sets.isEmpty ? 0.0 : exercise.sets.first.weightKg;
    final set = WorkoutSet(
      weightKg: startingWeight(working, type),
      reps: exercise.sets.isEmpty ? 0 : exercise.sets.first.reps,
      previousWeightKg: working,
      previousReps: exercise.sets.isEmpty ? 0 : exercise.sets.first.reps,
      type: type,
    );
    exercise.sets.add(set);
    _workouts.save(workout, action: 'add_set');
    return set;
  }

  /// Saves what the user wrote about the workout.
  void setNotes(WorkoutSession workout, String notes) {
    workout.notes = notes.isEmpty ? null : notes;
    _workouts.save(workout, action: 'set_notes');
  }

  void toggleSet(WorkoutSession workout, int setIndex) {
    final set = workout.currentExercise.sets[setIndex];
    set.isDone = !set.isDone;
    _workouts.save(workout, action: set.isDone ? 'complete_set' : 'reopen_set');
  }

  void selectExercise(WorkoutSession workout, int index) {
    workout.currentExerciseIndex = index.clamp(0, workout.exercises.length - 1);
    _workouts.save(workout, action: 'select_exercise');
  }

  void addExercises(
    WorkoutSession workout,
    Iterable<ExerciseDefinition> exercises,
  ) {
    workout.exercises.addAll([
      for (final exercise in exercises) plan(planFor(exercise)),
    ]);
    _workouts.save(workout, action: 'add_exercises');
  }

  /// Swaps today's exercise only; the template and history stay as they
  /// are. Prescribed sets and reps carry over, the load does not.
  void replaceCurrentExercise(
    WorkoutSession workout,
    ExerciseDefinition replacement,
  ) {
    final current = workout.currentExercise;
    workout.exercises[workout.currentExerciseIndex] = ExerciseSession(
      exercise: replacement,
      sets: [
        for (final set in current.sets)
          WorkoutSet(
            weightKg: set.weightKg,
            reps: set.reps,
            rir: set.rir,
            previousWeightKg: set.previousWeightKg,
            previousReps: set.previousReps,
          ),
      ],
    );
    _workouts.save(workout, action: 'replace_exercise');
  }

  void togglePause(WorkoutSession workout) {
    final pausedAt = workout.pausedAt;
    if (pausedAt == null) {
      workout.pausedAt = _db.now();
    } else {
      workout
        ..pausedTotal += _db.now().difference(pausedAt)
        ..pausedAt = null;
    }
    _workouts.save(workout, action: workout.isPaused ? 'pause' : 'resume');
  }

  /// Gives up on a workout: it is kept as an abandoned one, not counted
  /// as training and not deleted.
  void discard(WorkoutSession workout) => _workouts.cancel(workout);

  void finish(WorkoutSession workout) {
    if (workout.isPaused) togglePause(workout);
    workout.finishedAt = _db.now();
    _workouts.save(workout, action: 'finish');
  }

  /// Adds [exercises] to the template. Editing a template never rewrites a
  /// finished workout.
  Routine addToRoutine(
    Routine routine,
    Iterable<ExerciseDefinition> exercises, {
    String action = 'add_exercises',
    ChangeSource source = ChangeSource.local,
  }) {
    final updated = routine.copyWith(
      exercises: [
        ...routine.exercises,
        for (final exercise in exercises) planFor(exercise),
      ],
    );
    _routines.save(updated, action: action, source: source);
    return updated;
  }

  /// Drops one exercise from the template. History keeps every workout
  /// that used it.
  Routine removeFromRoutine(Routine routine, int index) {
    final exercises = [...routine.exercises]..removeAt(index);
    final updated = routine.copyWith(exercises: exercises);
    _routines.save(updated, action: 'remove_exercise');
    return updated;
  }

  /// Moves an exercise within the template; the order is the order they
  /// are meant to be done in.
  Routine reorderRoutine(Routine routine, int from, int to) {
    if (from == to) return routine;
    final exercises = [...routine.exercises];
    exercises.insert(to, exercises.removeAt(from));
    final updated = routine.copyWith(exercises: exercises);
    _routines.save(updated, action: 'reorder_exercises');
    return updated;
  }

  /// Swaps a planned exercise for another, keeping what was planned for
  /// it. Finished workouts are untouched, as with any template edit.
  Routine replaceInRoutine(
    Routine routine,
    String exerciseId,
    ExerciseDefinition replacement,
  ) {
    final updated = routine.copyWith(
      exercises: [
        for (final planned in routine.exercises)
          if (planned.exercise.id == exerciseId)
            planned.copyWith(exercise: replacement)
          else
            planned,
      ],
    );
    _routines.save(updated, action: 'replace_exercise');
    return updated;
  }

  Routine renameRoutine(Routine routine, String name) {
    final updated = routine.renamed(name);
    _routines.save(updated, action: 'rename');
    return updated;
  }

  /// Saves an edited template as is.
  void saveRoutine(
    Routine routine, {
    required String action,
    ChangeSource source = ChangeSource.local,
  }) => _routines.save(routine, action: action, source: source);

  Routine? routine(String id, Map<String, ExerciseDefinition> exercises) =>
      _routines.byId(id, exercises);

  List<Routine> routines(Map<String, ExerciseDefinition> exercises) =>
      _routines.all(exercises);

  /// A new, empty template. Exercises are added to it afterwards, the
  /// same way they are added to any other.
  Routine createRoutine(String name) {
    final routine = Routine(
      id: _db.newId(),
      name: name,
      programName: _ownProgramName,
      estimatedMinutes: 0,
      lastCompletedLabel: '還沒完成過',
      exercises: const [],
    );
    _routines.save(routine, action: 'create');
    return routine;
  }

  void deleteRoutine(String id) => _routines.remove(id);

  void undeleteRoutine(String id) => _routines.restore(id);

  PlannedExercise planFor(ExerciseDefinition exercise) => PlannedExercise(
    exercise: exercise,
    sets: _addedSets,
    reps: _addedReps,
    targetWeightKg: _addedWeightKg,
    progressionLabel: '維持',
  );
}
