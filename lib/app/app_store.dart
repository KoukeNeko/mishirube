import 'package:flutter/widgets.dart';

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
  AppStore({DateTime Function()? clock, this._isOnboarded = false})
    : _clock = clock ?? DateTime.now;

  static const _aiProposalSquatSets = 5;
  static const _aiProposalLegCurlSets = 4;

  final DateTime Function() _clock;

  bool _isOnboarded;
  final Set<AppModule> _enabledModules = {
    AppModule.nutrition,
    AppModule.weight,
    AppModule.training,
  };
  DayPhase _phase = DayPhase.morning;
  Routine _routine = MockRoutines.lowerBodyA;
  WorkoutSession? _activeWorkout;
  WorkoutSession? _lastFinishedWorkout;
  final List<MealEvent> _todayMeals = [MockNutrition.breakfast];
  bool _hasSyncConflict = true;
  HomeTab _selectedTab = HomeTab.today;

  DateTime now() => _clock();
  bool get isOnboarded => _isOnboarded;
  Set<AppModule> get enabledModules => Set.unmodifiable(_enabledModules);
  DayPhase get phase => _phase;
  Routine get routine => _routine;
  WorkoutSession? get activeWorkout => _activeWorkout;
  WorkoutSession? get lastFinishedWorkout => _lastFinishedWorkout;
  List<MealEvent> get todayMeals => List.unmodifiable(_todayMeals);
  bool get hasSyncConflict => _hasSyncConflict;
  HomeTab get selectedTab => _selectedTab;
  bool get isLunchLogged => _todayMeals.any((meal) => meal.id == 'lunch');

  int get todayKcal => _sumMeals((meal) => meal.kcal);
  int get todayProteinGrams => _sumMeals((meal) => meal.proteinGrams);
  int get todayCarbGrams => _sumMeals((meal) => meal.carbGrams);
  int get todayFatGrams => _sumMeals((meal) => meal.fatGrams);

  int _sumMeals(int Function(MealEvent meal) valueOf) =>
      _todayMeals.fold(0, (sum, meal) => sum + valueOf(meal));

  void selectTab(HomeTab tab) {
    if (_selectedTab == tab) return;
    _selectedTab = tab;
    notifyListeners();
  }

  void toggleModule(AppModule module) {
    if (!_enabledModules.remove(module)) _enabledModules.add(module);
    notifyListeners();
  }

  void completeOnboarding() {
    _isOnboarded = true;
    notifyListeners();
  }

  void cyclePhase() {
    final nextIndex = (_phase.index + 1) % DayPhase.values.length;
    _phase = DayPhase.values[nextIndex];
    if (_phase == DayPhase.evening) _ensureLunchLogged();
    notifyListeners();
  }

  void startWorkout() {
    _activeWorkout ??= WorkoutSession(
      routineName: _routine.name,
      startedAt: now(),
      exercises: _routine.exercises.map(_buildExerciseSession).toList(),
    );
    notifyListeners();
  }

  ExerciseSession _buildExerciseSession(PlannedExercise planned) {
    final (previousWeight, previousReps) = MockPreviousPerformance.of(planned);
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
    notifyListeners();
  }

  void selectExercise(int index) {
    final workout = _activeWorkout;
    if (workout == null) return;
    workout.currentExerciseIndex = index.clamp(0, workout.exercises.length - 1);
    notifyListeners();
  }

  void addExercises(List<ExerciseDefinition> exercises) {
    final planned = exercises.map(_planFor).toList();
    final workout = _activeWorkout;
    if (workout != null) {
      workout.exercises.addAll(planned.map(_buildExerciseSession));
    } else {
      _routine = _routine.copyWith(
        exercises: [..._routine.exercises, ...planned],
      );
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
    notifyListeners();
  }

  void togglePause() {
    final workout = _activeWorkout;
    if (workout == null) return;
    _togglePause(workout);
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
    _lastFinishedWorkout = workout;
    _activeWorkout = null;
    _phase = DayPhase.evening;
    _ensureLunchLogged();
    notifyListeners();
  }

  void confirmLunch() {
    _ensureLunchLogged();
    notifyListeners();
  }

  void _ensureLunchLogged() {
    if (!isLunchLogged) _todayMeals.add(MockNutrition.lunch);
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
    _todayMeals[mealIndex] = meal.copyWith(dishes: dishes);
    notifyListeners();
    return DishSplitSnapshot(mealIndex: mealIndex, meal: meal);
  }

  void undoSplit(DishSplitSnapshot snapshot) {
    _todayMeals[snapshot.mealIndex] = snapshot.meal;
    notifyListeners();
  }

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
