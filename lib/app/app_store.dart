import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../backend/backend.dart';
import '../backend/database.dart';
import '../backend/seed.dart';
import '../backend/timeline_query.dart';
import '../data/mock_data.dart';
import '../data/models.dart';

/// Which moment of the mock day the Today screen is showing.
enum DayPhase {
  morning('早上'),
  noon('中午'),
  evening('20:41');

  const DayPhase(this.label);

  final String label;
}

enum AppModule {
  nutrition('記錄飲食', '一餐、料理、成分與營養'),
  weight('管理體重', '體重趨勢與攝取的關係'),
  training('重量訓練', '動作、訓練、計畫與訓練紀錄'),
  activity('增加日常活動', '步數與活動量'),
  sleep('改善睡眠', '睡眠時間與品質'),
  wellness('觀察身體狀況', '心情、精力與症狀日誌'),
  notes('筆記', '和任何一天或一筆紀錄關聯');

  const AppModule(this.title, this.description);

  final String title;
  final String description;
}

enum HomeTab { today, log, trends, me }

/// Result of splitting a composite dish, kept so the change can be undone.
class DishSplitSnapshot {
  const DishSplitSnapshot({required this.mealIndex, required this.meal});

  final int mealIndex;
  final MealEvent meal;
}

class AppStore extends ChangeNotifier {
  /// [backend] defaults to a seeded in-memory store (tests, previews); the
  /// app passes the on-device one. A given [isOnboarded] overrides and
  /// saves the stored value.
  AppStore({DateTime Function()? clock, bool? isOnboarded, Backend? backend})
    : _clock = clock ?? DateTime.now,
      _backend = backend ?? Backend.inMemory(clock: clock),
      _ownsBackend = backend == null {
    seedDemoData(_backend, now());
    if (isOnboarded != null && isOnboarded != _storedOnboarded) {
      _backend.db.setSetting(_onboardedKey, '$isOnboarded');
    }
    _isOnboarded = _storedOnboarded;
    if (_backend.db.setting(_modulesKey) case final stored?) {
      _enabledModules
        ..clear()
        ..addAll([
          for (final name in (jsonDecode(stored) as List).cast<String>())
            AppModule.values.byName(name),
        ]);
    }
    _reloadExercises();
    _routine = _backend.routines.byId(_mainRoutineId, _exercisesById)!;
    _activeWorkout = _backend.workouts.active(_exercise);
    _lastFinishedWorkout = _backend.workouts.lastFinished(_exercise);
    _todayMeals.addAll(_backend.meals.onDay(now()));
  }

  static const _aiProposalSquatSets = 5;
  static const _aiProposalLegCurlSets = 4;
  static const _onboardedKey = 'onboarded';
  static const _modulesKey = 'enabled_modules';
  static const _mainRoutineId = 'lower-a';

  final DateTime Function() _clock;
  final Backend _backend;
  final bool _ownsBackend;

  late bool _isOnboarded;
  final Set<AppModule> _enabledModules = {
    AppModule.nutrition,
    AppModule.weight,
    AppModule.training,
  };
  DayPhase _phase = DayPhase.morning;
  late Routine _routine;
  WorkoutSession? _activeWorkout;
  WorkoutSession? _lastFinishedWorkout;
  final List<MealEvent> _todayMeals = [];
  List<ExerciseDefinition> _exercises = const [];
  Map<String, ExerciseDefinition> _exercisesById = const {};
  bool _hasSyncConflict = true;
  HomeTab _selectedTab = HomeTab.today;

  bool get _storedOnboarded => _backend.db.setting(_onboardedKey) == 'true';

  void _reloadExercises() {
    _exercises = _backend.exercises.all();
    _exercisesById = {for (final e in _exercises) e.id: e};
  }

  ExerciseDefinition _exercise(String id) =>
      _exercisesById[id] ?? _backend.exercises.byId(id)!;

  DateTime now() => _clock();
  Backend get backend => _backend;
  bool get isOnboarded => _isOnboarded;
  Set<AppModule> get enabledModules => Set.unmodifiable(_enabledModules);
  DayPhase get phase => _phase;
  Routine get routine => _routine;
  WorkoutSession? get activeWorkout => _activeWorkout;
  WorkoutSession? get lastFinishedWorkout => _lastFinishedWorkout;
  List<MealEvent> get todayMeals => List.unmodifiable(_todayMeals);
  bool get hasSyncConflict => _hasSyncConflict;
  HomeTab get selectedTab => _selectedTab;
  bool get isLunchLogged =>
      _todayMeals.any((meal) => meal.name == MockNutrition.lunch.name);

  /// The exercise catalog with usage derived from finished workouts.
  List<ExerciseDefinition> get exercises => List.unmodifiable(_exercises);

  ExerciseHistory exerciseHistory(ExerciseDefinition exercise) =>
      _backend.exercises.history(exercise.id);

  /// Records for the log; [month] is its first day.
  MonthRecords monthRecords(DateTime month) =>
      _backend.timeline.month(month, _exercise);

  /// The first month the log can go back to.
  DateTime get earliestRecordMonth {
    final today = now();
    return _backend.timeline.earliestMonth() ??
        DateTime(today.year, today.month);
  }

  int get todayKcal => _sumMeals((meal) => meal.kcal);
  int get todayProteinGrams => _sumMeals((meal) => meal.proteinGrams);
  int get todayCarbGrams => _sumMeals((meal) => meal.carbGrams);
  int get todayFatGrams => _sumMeals((meal) => meal.fatGrams);

  int _sumMeals(int Function(MealEvent meal) valueOf) =>
      _todayMeals.fold(0, (sum, meal) => sum + valueOf(meal));

  @override
  void dispose() {
    if (_ownsBackend) _backend.close();
    super.dispose();
  }

  void selectTab(HomeTab tab) {
    if (_selectedTab == tab) return;
    _selectedTab = tab;
    notifyListeners();
  }

  void toggleModule(AppModule module) {
    if (!_enabledModules.remove(module)) _enabledModules.add(module);
    _backend.db.setSetting(
      _modulesKey,
      jsonEncode([for (final m in _enabledModules) m.name]),
    );
    notifyListeners();
  }

  void completeOnboarding() {
    _isOnboarded = true;
    _backend.db.setSetting(_onboardedKey, 'true');
    notifyListeners();
  }

  void cyclePhase() {
    final nextIndex = (_phase.index + 1) % DayPhase.values.length;
    _phase = DayPhase.values[nextIndex];
    if (_phase == DayPhase.evening) _ensureLunchLogged();
    notifyListeners();
  }

  void startWorkout() {
    if (_activeWorkout != null) {
      notifyListeners();
      return;
    }
    final workout = WorkoutSession(
      id: _backend.db.newId(),
      routineId: _routine.id,
      routineName: _routine.name,
      startedAt: now(),
      exercises: _routine.exercises.map(_buildExerciseSession).toList(),
    );
    _backend.workouts.save(workout, action: 'start');
    _activeWorkout = workout;
    notifyListeners();
  }

  /// Commits the running workout after [action], so it survives the app
  /// being killed.
  void _saveActive(String action) {
    final workout = _activeWorkout;
    if (workout != null) _backend.workouts.save(workout, action: action);
  }

  ExerciseSession _buildExerciseSession(PlannedExercise planned) {
    // "Last time" is the heaviest working set of the last finished session;
    // with no history the plan itself is the reference.
    final last = _backend.exercises.history(planned.exercise.id).last;
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
  /// on to the next exercise once every set is finished.
  WorkoutSet? completeNextSet() {
    final workout = _activeWorkout;
    if (workout == null) return null;
    final exercise = workout.currentExercise;
    final setIndex = exercise.nextSetIndex;
    if (setIndex == null) return null;

    final completedSet = exercise.sets[setIndex]..isDone = true;
    if (exercise.isComplete) _advanceToNextPendingExercise(workout);
    _saveActive('complete_set');
    notifyListeners();
    return completedSet;
  }

  void _advanceToNextPendingExercise(WorkoutSession workout) {
    final nextIndex = workout.exercises.indexWhere((item) => !item.isComplete);
    if (nextIndex >= 0) workout.currentExerciseIndex = nextIndex;
  }

  void toggleSet(int setIndex) {
    final set = _activeWorkout?.currentExercise.sets[setIndex];
    if (set == null) return;
    set.isDone = !set.isDone;
    _saveActive(set.isDone ? 'complete_set' : 'reopen_set');
    notifyListeners();
  }

  void selectExercise(int index) {
    final workout = _activeWorkout;
    if (workout == null) return;
    workout.currentExerciseIndex = index.clamp(0, workout.exercises.length - 1);
    _saveActive('select_exercise');
    notifyListeners();
  }

  void addExercises(List<ExerciseDefinition> exercises) {
    final planned = exercises.map(_planFor).toList();
    final workout = _activeWorkout;
    if (workout != null) {
      workout.exercises.addAll(planned.map(_buildExerciseSession));
      _saveActive('add_exercises');
    } else {
      _routine = _routine.copyWith(
        exercises: [..._routine.exercises, ...planned],
      );
      _backend.routines.save(_routine, action: 'add_exercises');
    }
    notifyListeners();
  }

  PlannedExercise _planFor(ExerciseDefinition exercise) => PlannedExercise(
    exercise: exercise,
    sets: 3,
    reps: 10,
    targetWeightKg: 20,
    progressionLabel: '維持',
  );

  /// Stores a new custom exercise and makes it available to pickers.
  void createExercise(ExerciseDefinition exercise) {
    if (_exercisesById.containsKey(exercise.id)) return;
    _backend.exercises.save(exercise);
    _reloadExercises();
    notifyListeners();
  }

  void toggleFavorite(ExerciseDefinition exercise) {
    final isFavorite = !(_exercisesById[exercise.id]?.isFavorite ?? false);
    _backend.exercises.setFavorite(exercise.id, isFavorite: isFavorite);
    _reloadExercises();
    notifyListeners();
  }

  void replaceCurrentExercise(ExerciseDefinition replacement) {
    final workout = _activeWorkout;
    if (workout == null) return;
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
    _saveActive('replace_exercise');
    notifyListeners();
  }

  void togglePause() {
    final workout = _activeWorkout;
    if (workout == null) return;
    _togglePause(workout);
    _saveActive(workout.isPaused ? 'pause' : 'resume');
    notifyListeners();
  }

  void _togglePause(WorkoutSession workout) {
    final pausedAt = workout.pausedAt;
    if (pausedAt == null) {
      workout.pausedAt = now();
      return;
    }
    workout
      ..pausedTotal += now().difference(pausedAt)
      ..pausedAt = null;
  }

  void finishWorkout() {
    final workout = _activeWorkout;
    if (workout == null) return;
    if (workout.isPaused) _togglePause(workout);
    workout.finishedAt = now();
    _backend.workouts.save(workout, action: 'finish');
    _lastFinishedWorkout = workout;
    _activeWorkout = null;
    _phase = DayPhase.evening;
    _ensureLunchLogged();
    _routine = _backend.routines.byId(_routine.id, _exercisesById)!;
    _reloadExercises();
    notifyListeners();
  }

  void confirmLunch() {
    _ensureLunchLogged();
    notifyListeners();
  }

  void _ensureLunchLogged() {
    if (isLunchLogged) return;
    final template = MockNutrition.lunch;
    final lunch = _backend.meals.exists(template.id)
        ? template.copyWith(id: _backend.db.newId())
        : template;
    final today = now();
    _backend.meals.insert(
      lunch,
      eatenAt: DateTime(today.year, today.month, today.day, 12, 35),
    );
    _todayMeals.add(lunch);
  }

  DishSplitSnapshot? splitDish({
    required String mealId,
    required int dishIndex,
  }) {
    final mealIndex = _todayMeals.indexWhere((meal) => meal.id == mealId);
    if (mealIndex < 0) return null;
    final meal = _todayMeals[mealIndex];
    final dish = meal.dishes[dishIndex];
    if (!dish.isComposite) return null;

    final standaloneEntries = dish.components.map(
      (component) => DishEntry(
        name: component.name,
        quantityLabel: component.amountLabel,
        subtitle: component.source,
      ),
    );
    final dishes = [...meal.dishes]
      ..removeAt(dishIndex)
      ..insertAll(dishIndex, standaloneEntries);
    final split = meal.copyWith(dishes: dishes);
    _backend.meals.replaceDishes(split, action: 'explode_dish', previous: meal);
    _todayMeals[mealIndex] = split;
    notifyListeners();
    return DishSplitSnapshot(mealIndex: mealIndex, meal: meal);
  }

  void undoSplit(DishSplitSnapshot snapshot) {
    _backend.meals.replaceDishes(
      snapshot.meal,
      action: 'undo_explode_dish',
      previous: _todayMeals[snapshot.mealIndex],
    );
    _todayMeals[snapshot.mealIndex] = snapshot.meal;
    notifyListeners();
  }

  /// Accepts the AI's routine proposal: it changes the template only, and
  /// the audit log records that the change came from an AI draft.
  void applyAiProposal() {
    final exercises = [
      for (final planned in _routine.exercises)
        switch (planned.exercise.id) {
          'back-squat' => planned.copyWith(sets: _aiProposalSquatSets),
          'leg-curl' => planned.copyWith(sets: _aiProposalLegCurlSets),
          _ => planned,
        },
    ];
    _routine = _routine.copyWith(exercises: exercises);
    _backend.routines.save(
      _routine,
      action: 'accept_ai_proposal',
      source: ChangeSource.aiDraft,
    );
    notifyListeners();
  }

  void resolveSyncConflict() {
    _hasSyncConflict = false;
    notifyListeners();
  }
}

class AppStoreScope extends InheritedNotifier<AppStore> {
  const AppStoreScope({
    super.key,
    required AppStore store,
    required super.child,
  }) : super(notifier: store);

  static AppStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStoreScope>();
    assert(scope != null, 'AppStoreScope is missing above this context.');
    return scope!.notifier!;
  }

  /// Reads the store without subscribing, for use inside callbacks.
  static AppStore read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<AppStoreScope>();
    assert(element != null, 'AppStoreScope is missing above this context.');
    return (element!.widget as AppStoreScope).notifier!;
  }
}
