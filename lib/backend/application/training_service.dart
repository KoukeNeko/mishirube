import '../../domain/domain.dart';
import '../engines/training_metrics.dart';
import '../storage/database.dart';
import '../storage/exercise_repository.dart';
import '../engines/progression_engine.dart';
import '../engines/workout_review.dart';
import '../storage/routine_repository.dart';
import '../storage/workout_repository.dart';

/// How many of a template's last workouts its length is judged from.
const _recentForLength = 5;

/// Defaults for an exercise added on the fly, until the user edits it.
const _addedSets = 3;

/// What a template the user made themselves belongs to, where a seeded
/// one names its program.
const _ownProgramName = '自己的訓練';

/// What a workout started from no routine is called.
const freeWorkoutName = '自由訓練';
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
  /// An exercise that works a muscle in [sore] gets a set fewer today;
  /// the template itself is left as it is.
  WorkoutSession start(Routine routine, {Set<MuscleGroup> sore = const {}}) {
    final workout = WorkoutSession(
      id: _db.newId(),
      routineId: routine.id,
      routineName: routine.name,
      startedAt: _db.now(),
      exercises: [
        for (final planned in routine.exercises)
          plan(
            worksSoreMuscle(planned, sore)
                ? planned.copyWith(sets: setsWhenSore(planned.sets))
                : planned,
          ),
      ],
    );
    _workouts.save(workout, action: 'start');
    return workout;
  }

  /// Starts a workout from no routine, with [exercises] to begin with.
  WorkoutSession startFree(List<ExerciseDefinition> exercises) {
    final workout = WorkoutSession(
      id: _db.newId(),
      routineName: freeWorkoutName,
      startedAt: _db.now(),
      exercises: [for (final exercise in exercises) plan(planFor(exercise))],
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
      joinsNext: planned.joinsNext,
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

  /// How long [routine] takes: what its recent workouts took, or, before
  /// there are any, its sets and rests as planned. Worked out on each
  /// read, so it follows every edit to the plan.
  Duration expectedLength(Routine routine) =>
      _workouts.averageLengthOf(routine.id, _recentForLength) ??
      plannedDuration(routine.exercises);

  /// The template's last [limit] finished workouts, newest first.
  List<WorkoutSession> recentOf(Routine routine, {int limit = 3}) =>
      _workouts.recentOf(routine.id, limit, _exercise);

  /// [workout] against what came before it, finished or still running.
  WorkoutReview review(WorkoutSession workout) {
    final routineId = workout.routineId;
    return reviewWorkout(
      workout,
      earlier: {
        for (final session in workout.exercises)
          session.exercise.id: _exercises
              .history(session.exercise.id)
              .before(workout.startedAt),
      },
      previous: routineId == null
          ? null
          : _workouts.previousOf(routineId, workout.startedAt, _exercise),
    );
  }

  /// Whether [set] of [exercise] beats every earlier session of it.
  bool isPersonalRecord(
    WorkoutSession workout,
    ExerciseDefinition exercise,
    WorkoutSet set,
  ) => isPersonalRecordSet(
    set,
    _exercises.history(exercise.id).before(workout.startedAt),
  );

  /// Marks the next pending set of the current exercise as done and moves
  /// on to the next unfinished exercise once every set is logged.
  WorkoutSet? completeNextSet(WorkoutSession workout) {
    final exercise = workout.currentExercise;
    final setIndex = exercise.nextSetIndex;
    if (setIndex == null) return null;
    final completed = exercise.sets[setIndex]..isDone = true;
    // Round the superset: the next of its exercises with a set left,
    // starting after this one; this one again when it is alone.
    final current = workout.currentExerciseIndex;
    final superset = workout.supersetOf(current);
    final next = [
      ...superset.where((i) => i > current),
      ...superset.where((i) => i <= current),
    ].where((i) => !workout.exercises[i].isComplete).firstOrNull;
    if (next != null) {
      workout.currentExerciseIndex = next;
    } else {
      final after = workout.exercises.indexWhere((item) => !item.isComplete);
      if (after >= 0) workout.currentExerciseIndex = after;
    }
    _workouts.save(workout, action: 'complete_set');
    return completed;
  }

  /// Adds one more set to the exercise being done. A warm-up or drop set
  /// starts at a share of the working weight, rounded to the plates, for
  /// the user to adjust; a working set repeats the last one. A warm-up is
  /// the next set to do, ahead of the work it prepares for; any other set
  /// goes last.
  WorkoutSet addSet(WorkoutSession workout, SetType type) {
    final exercise = workout.currentExercise;
    // The last working set is what the others are measured from; one
    // more working set repeats it.
    final reference =
        exercise.sets.where((set) => set.type == SetType.working).lastOrNull ??
        exercise.sets.lastOrNull;
    final working = reference?.weightKg ?? 0.0;
    final set = WorkoutSet(
      weightKg: startingWeight(working, type),
      reps: reference?.reps ?? 0,
      rir: type == SetType.working ? reference?.rir : null,
      previousWeightKg: reference?.previousWeightKg ?? working,
      previousReps: reference?.previousReps ?? 0,
      type: type,
    );
    if (type == SetType.warmup) {
      exercise.sets.insert(exercise.nextSetIndex ?? exercise.sets.length, set);
    } else {
      exercise.sets.add(set);
    }
    _workouts.save(workout, action: 'add_set');
    return set;
  }

  /// Warms up for the exercise being done: the whole ramp to its working
  /// weight when it has no warm-up yet, one more warm-up set otherwise.
  /// They go ahead of the next set to do.
  List<WorkoutSet> addWarmups(WorkoutSession workout) {
    final exercise = workout.currentExercise;
    final working = exercise.sets
        .where((set) => set.type == SetType.working)
        .firstOrNull;
    final ramp = working == null
        ? const <(double, int)>[]
        : warmupRamp(working.weightKg, exercise.exercise.equipment);
    if (ramp.isEmpty ||
        exercise.sets.any((set) => set.type == SetType.warmup)) {
      return [addSet(workout, SetType.warmup)];
    }
    final sets = [
      for (final (kg, reps) in ramp)
        WorkoutSet(
          weightKg: kg,
          reps: reps,
          previousWeightKg: working!.previousWeightKg,
          previousReps: working.previousReps,
          type: SetType.warmup,
        ),
    ];
    exercise.sets.insertAll(
      exercise.nextSetIndex ?? exercise.sets.length,
      sets,
    );
    _workouts.save(workout, action: 'add_warmups');
    return sets;
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

  /// Rewrites what one set of the current exercise was: the weight, the
  /// reps and how many were left in reserve. Its type, last time's
  /// numbers and whether it is done stay as they are.
  void editSet(
    WorkoutSession workout,
    int setIndex, {
    required double weightKg,
    required int reps,
    required int? rir,
  }) {
    final sets = workout.currentExercise.sets;
    final set = sets[setIndex];
    sets[setIndex] = WorkoutSet(
      weightKg: weightKg,
      reps: reps,
      rir: rir,
      rpe: set.rpe,
      type: set.type,
      previousWeightKg: set.previousWeightKg,
      previousReps: set.previousReps,
      durationSeconds: set.durationSeconds,
      distanceMeters: set.distanceMeters,
      isDone: set.isDone,
    );
    _workouts.save(workout, action: 'edit_set');
  }

  /// Takes a set off the current exercise, done or not. The workout's
  /// earlier states stay in the audit trail.
  void removeSet(WorkoutSession workout, int setIndex) {
    workout.currentExercise.sets.removeAt(setIndex);
    _workouts.save(workout, action: 'remove_set');
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

  /// Records how a finished workout felt.
  void rate(WorkoutSession workout, Workload workload) {
    workout.workload = workload;
    _workouts.save(workout, action: 'rate');
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
  /// Makes the planned exercise at [index] a superset with the one after
  /// it, or ends that.
  Routine setJoinsNext(Routine routine, int index, {required bool joins}) {
    final exercises = [...routine.exercises];
    exercises[index] = exercises[index].copyWith(joinsNext: joins);
    final updated = routine.copyWith(exercises: exercises);
    _routines.save(updated, action: joins ? 'join_superset' : 'leave_superset');
    return updated;
  }

  Routine reorderRoutine(Routine routine, int from, int to) {
    if (from == to) return routine;
    final exercises = [...routine.exercises];
    exercises.insert(to, exercises.removeAt(from));
    final updated = routine.copyWith(exercises: exercises);
    _routines.save(updated, action: 'reorder_exercises');
    return updated;
  }

  /// What to do with each planned exercise next time, in the plan's own
  /// order. Exercises with nothing to go on are left out rather than
  /// given a guess.
  List<(PlannedExercise, ProgressionSuggestion)> suggestions(Routine routine) {
    final out = <(PlannedExercise, ProgressionSuggestion)>[];
    for (final planned in routine.exercises) {
      final suggestion = suggestProgression(
        planned: planned,
        recent: _attempts(planned.exercise.id),
      );
      if (suggestion != null) out.add((planned, suggestion));
    }
    return out;
  }

  /// Finished sessions of an exercise, newest first: the best working set
  /// of each, with how many working sets it took.
  List<ExerciseAttempt> _attempts(String exerciseId) {
    final setsByDay = {
      for (final (date, sets) in _exercises.sessionSetCounts(exerciseId))
        date: sets,
    };
    final workloads = _workouts.workloads();
    return [
      for (final entry in _exercises.history(exerciseId).recent)
        ExerciseAttempt(
          date: entry.date,
          weightKg: entry.weightKg,
          reps: entry.reps,
          rir: entry.rir,
          workingSets: setsByDay[entry.date] ?? 0,
          workload: workloads[entry.date],
        ),
    ];
  }

  /// Writes a suggestion into the plan. It is the user's decision, so
  /// nothing is applied until they say so.
  Routine applySuggestion(
    Routine routine,
    PlannedExercise planned,
    ProgressionSuggestion suggestion,
  ) {
    final updated = routine.copyWith(
      exercises: [
        for (final item in routine.exercises)
          if (item.exercise.id == planned.exercise.id)
            item.copyWith(targetWeightKg: suggestion.targetWeightKg)
          else
            item,
      ],
    );
    _routines.save(updated, action: 'apply_progression');
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

  /// A new template, empty unless [exercises] are given. Exercises are
  /// otherwise added afterwards, the same way as to any other.
  Routine createRoutine(
    String name, {
    List<PlannedExercise> exercises = const [],
  }) {
    final routine = Routine(
      id: _db.newId(),
      name: name,
      programName: _ownProgramName,
      estimatedMinutes: 0,
      lastCompletedLabel: '未完成過',
      exercises: exercises,
    );
    _routines.save(routine, action: 'create');
    return routine;
  }

  /// A copy of [routine] under a new id, for a program to hold as its
  /// own.
  Routine copyRoutine(Routine routine) =>
      createRoutine(routine.name, exercises: routine.exercises);

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
