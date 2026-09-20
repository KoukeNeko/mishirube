import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../backend/application/activity_service.dart';
import '../backend/application/goal_service.dart';
import '../backend/engines/progression_engine.dart';
import '../backend/application/insights_service.dart';
import '../backend/application/nutrition_service.dart';
import '../backend/backend.dart';
import '../backend/engines/caffeine.dart';
import '../backend/engines/food_portion.dart';
import '../backend/engines/nutrition_summary.dart';
import '../backend/seed/demo_content.dart';
import '../backend/seed/seed.dart';
import '../backend/storage/database.dart';
import '../domain/domain.dart';

export '../backend/application/catalog_service.dart' show TrackingChangeRefused;
export '../backend/application/nutrition_service.dart'
    show DishSplitSnapshot, RecentMeal;

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
  activity('運動', '跑步、健走、騎車、球類、瑜伽'),
  sleep('改善睡眠', '睡眠時間與品質'),
  wellness('觀察身體狀況', '心情、精力與症狀日誌'),
  notes('筆記', '和任何一天或一筆紀錄關聯');

  const AppModule(this.title, this.description);

  final String title;
  final String description;
}

enum HomeTab { today, log, trends, me }

/// Which body the muscle map is drawn on. It is a choice of drawing,
/// not a statement about the user: the same records are shaded either
/// way, and nothing else in the app reads it.
enum MuscleFigure {
  male('男性'),
  female('女性');

  const MuscleFigure(this.label);

  final String label;
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
    _routine =
        _storedRoutine ?? _backend.training.routines(_exercisesById).first;
    _session = switch ((
      _backend.training.active(),
      _backend.activity.active(),
    )) {
      (final WorkoutSession workout, _) => ActiveWorkout(workout),
      (_, final LiveActivity live) => ActiveActivity(live),
      _ => null,
    };
    _lastFinishedWorkout = _backend.training.lastFinished();
    _todayMeals.addAll(_backend.nutrition.mealsOn(now()));
  }

  static const _aiProposalSquatSets = 5;
  static const _aiProposalLegCurlSets = 4;
  static const _onboardedKey = 'onboarded';
  static const _modulesKey = 'enabled_modules';
  static const _selectedRoutineKey = 'selected_routine';
  static const _muscleFigureKey = 'muscle_figure';
  static const _glassKey = 'glass_millilitres';

  /// What one glass is, until the user says otherwise.
  static const defaultGlassMillilitres = 250;

  final DateTime Function() _clock;
  final Backend _backend;
  final bool _ownsBackend;

  late bool _isOnboarded;

  /// On until the user says otherwise: the modules whose records the app
  /// can actually log today.
  final Set<AppModule> _enabledModules = {
    AppModule.nutrition,
    AppModule.weight,
    AppModule.training,
    AppModule.activity,
    AppModule.sleep,
    AppModule.wellness,
  };
  DayPhase _phase = DayPhase.morning;
  late Routine _routine;
  ActiveSession? _session;
  WorkoutSession? _lastFinishedWorkout;
  final List<MealEvent> _todayMeals = [];
  List<ExerciseDefinition> _exercises = const [];
  Map<String, ExerciseDefinition> _exercisesById = const {};
  bool _hasSyncConflict = true;
  HomeTab _selectedTab = HomeTab.today;

  bool get _storedOnboarded => _backend.db.setting(_onboardedKey) == 'true';

  /// The template last trained from, when it is still there.
  Routine? get _storedRoutine {
    final id = _backend.db.setting(_selectedRoutineKey);
    return id == null ? null : _backend.training.routine(id, _exercisesById);
  }

  void _reloadExercises() {
    _exercises = _backend.catalog.all();
    _exercisesById = {for (final e in _exercises) e.id: e};
  }

  ExerciseDefinition _exercise(String id) =>
      _exercisesById[id] ?? _backend.catalog.byId(id)!;

  DateTime now() => _clock();
  Backend get backend => _backend;
  bool get isOnboarded => _isOnboarded;
  Set<AppModule> get enabledModules => Set.unmodifiable(_enabledModules);
  DayPhase get phase => _phase;
  Routine get routine => _routine;

  /// Every template, for choosing what to train.
  List<Routine> get routines => _backend.training.routines(_exercisesById);

  /// Whatever is running, of whatever kind; null when nothing is.
  ActiveSession? get activeSession => _session;

  WorkoutSession? get activeWorkout => switch (_session) {
    ActiveWorkout(:final workout) => workout,
    _ => null,
  };

  LiveActivity? get activeActivity => switch (_session) {
    ActiveActivity(:final activity) => activity,
    _ => null,
  };
  WorkoutSession? get lastFinishedWorkout => _lastFinishedWorkout;
  List<MealEvent> get todayMeals => List.unmodifiable(_todayMeals);
  bool get hasSyncConflict => _hasSyncConflict;
  HomeTab get selectedTab => _selectedTab;
  bool get isLunchLogged =>
      _todayMeals.any((meal) => meal.name == DemoNutrition.lunch.name);

  /// The exercise catalog with usage derived from finished workouts.
  List<ExerciseDefinition> get exercises => List.unmodifiable(_exercises);

  ExerciseHistory exerciseHistory(ExerciseDefinition exercise) =>
      _backend.catalog.history(exercise.id);

  /// Fair swaps for [exercise], each with the reason it is one.
  List<SubstitutionOption> substitutesFor(ExerciseDefinition exercise) =>
      _backend.catalog.substitutesFor(exercise);

  /// Insights for the Today screen, derived from the records.
  List<Insight> get todayInsights => _backend.insights.today();

  /// Everything the Trends screen shows over [window].
  TrendsOverview trends({Duration window = const Duration(days: 28)}) =>
      _backend.insights.trends(window: window);

  /// Training volume for one exercise, or for the most trained one.
  VolumeReport? volumeReport({
    String? exerciseId,
    Duration window = const Duration(days: 28),
  }) => _backend.insights.volumeReport(exerciseId: exerciseId, window: window);

  /// The weekly goal, the weeks measured against it, and the run of
  /// weeks met, all derived from the records.
  GoalOverview get goalOverview => _backend.goal.overview();

  bool get isGoalEnabled => _backend.goal.isEnabled;

  /// Sets how many days a week to move. From next week unless the user
  /// asks for it to count now; earlier weeks keep their own goal.
  void setWeeklyGoal(int days, {bool applyThisWeek = false}) {
    _backend.goal.setGoal(days, applyThisWeek: applyThisWeek);
    notifyListeners();
  }

  /// Stops the goal applying until [until], or until picked up again.
  void pauseGoal({DateTime? until}) {
    _backend.goal.pause(until: until);
    notifyListeners();
  }

  void resumeGoal() {
    _backend.goal.resume();
    notifyListeners();
  }

  /// Turning the goal off hides it; the records and the trends stay.
  void setGoalEnabled(bool value) {
    _backend.goal.setEnabled(value);
    notifyListeners();
  }

  /// Folds a duplicate exercise into the one it duplicates. The records
  /// move with it; the plan is reloaded because it may name either.
  void mergeExercise({
    required ExerciseDefinition duplicate,
    required ExerciseDefinition canonical,
  }) {
    _backend.catalog.merge(duplicate: duplicate, canonical: canonical);
    _reloadExercises();
    _routine = _backend.training.routine(_routine.id, _exercisesById)!;
    notifyListeners();
  }

  /// What to do with each planned exercise next time, with the reason.
  /// Nothing is applied until the user accepts it.
  List<(PlannedExercise, ProgressionSuggestion)> get progressionSuggestions =>
      _backend.training.suggestions(_routine);

  /// Writes one suggestion into the template.
  void applySuggestion(
    PlannedExercise planned,
    ProgressionSuggestion suggestion,
  ) {
    _routine = _backend.training.applySuggestion(_routine, planned, suggestion);
    notifyListeners();
  }

  /// Which body the muscle map draws. Defaults to the male figure only
  /// because one of the two has to be first.
  MuscleFigure get muscleFigure => MuscleFigure.values.firstWhere(
    (figure) => figure.name == _backend.db.setting(_muscleFigureKey),
    orElse: () => MuscleFigure.male,
  );

  void setMuscleFigure(MuscleFigure figure) {
    _backend.db.setSetting(_muscleFigureKey, figure.name);
    notifyListeners();
  }

  /// Working sets per muscle per week, for seeing what is being trained
  /// and what is being left out.
  List<(MuscleGroup, int)> muscleLoad({
    Duration window = const Duration(days: 28),
  }) => _backend.insights.muscleLoad(window: window);

  /// Where the previous database file was moved to when it could not be
  /// read, or null on a normal start. The app says so rather than
  /// looking as though the records were never there.
  String? get recoveredDatabasePath => _backend.db.recoveredFrom;

  /// Saves a correction to a meal.
  void updateMeal(MealEvent previous, MealEvent corrected) {
    _backend.nutrition.edit(previous, corrected);
    final index = _todayMeals.indexWhere((item) => item.id == corrected.id);
    if (index >= 0) _todayMeals[index] = corrected;
    notifyListeners();
  }

  /// Starred meals, for logging again without going looking.
  List<RecentMeal> get favoriteMeals => _backend.nutrition.favorites();

  /// Stars or unstars a meal.
  void setMealFavorite(MealEvent meal, {required bool isFavorite}) {
    _backend.nutrition.setFavorite(meal, isFavorite: isFavorite);
    final index = _todayMeals.indexWhere((item) => item.id == meal.id);
    if (index >= 0) {
      _todayMeals[index] = _todayMeals[index].copyWith(isFavorite: isFavorite);
    }
    notifyListeners();
  }

  /// Records for the log; [month] is its first day.
  MonthRecords monthRecords(DateTime month) => _backend.timeline.month(month);

  /// The first month the log can go back to.
  DateTime get earliestRecordMonth {
    final today = now();
    return _backend.timeline.earliestMonth() ??
        DateTime(today.year, today.month);
  }

  /// Today's food totals and how complete the day's log is.
  DaySummary get todaySummary => summariseDay(_todayMeals, isOver: false);

  int get todayKcal => todaySummary.kcal;
  int get todayProteinGrams => todaySummary.proteinGrams;
  int get todayCarbGrams => todaySummary.carbGrams;
  int get todayFatGrams => todaySummary.fatGrams;
  int get todayFibreGrams => todaySummary.fibreGrams;

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

  /// Starts (or picks up) today's workout. Refuses while exercise is
  /// being timed: ending someone's run for them is not ours to do.
  bool startWorkout() {
    if (_session case ActiveActivity()) return false;
    _session = ActiveWorkout(
      activeWorkout ?? _backend.training.start(_routine),
    );
    notifyListeners();
    return true;
  }

  /// Marks the next pending set of the current exercise as done.
  WorkoutSet? completeNextSet() {
    final workout = activeWorkout;
    if (workout == null) return null;
    final completed = _backend.training.completeNextSet(workout);
    if (completed != null) notifyListeners();
    return completed;
  }

  /// Saves a note on the running workout.
  void setWorkoutNotes(String notes) {
    final workout = activeWorkout;
    if (workout == null) return;
    _backend.training.setNotes(workout, notes);
    notifyListeners();
  }

  /// Adds one more set of [type] to the exercise being done.
  WorkoutSet? addSet(SetType type) {
    final workout = activeWorkout;
    if (workout == null) return null;
    final set = _backend.training.addSet(workout, type);
    notifyListeners();
    return set;
  }

  void toggleSet(int setIndex) {
    final workout = activeWorkout;
    if (workout == null) return;
    _backend.training.toggleSet(workout, setIndex);
    notifyListeners();
  }

  void selectExercise(int index) {
    final workout = activeWorkout;
    if (workout == null) return;
    _backend.training.selectExercise(workout, index);
    notifyListeners();
  }

  /// Trains from [routine] from now on. The choice survives a restart,
  /// because it is what the Today screen offers.
  void selectRoutine(Routine routine) {
    _routine = routine;
    _backend.db.setSetting(_selectedRoutineKey, routine.id);
    notifyListeners();
  }

  /// Adds an empty template and switches to it.
  Routine createRoutine(String name) {
    final created = _backend.training.createRoutine(name);
    selectRoutine(created);
    return created;
  }

  /// Removes the template being shown. Refuses to remove the last one:
  /// the Today screen always has something to offer, and a template is
  /// not the history, which stays either way. Returns false when it
  /// refused, so the screen can say why.
  bool deleteRoutine(Routine routine) {
    final remaining = routines.where((other) => other.id != routine.id);
    if (remaining.isEmpty) return false;
    _backend.training.deleteRoutine(routine.id);
    selectRoutine(remaining.first);
    return true;
  }

  /// Puts a removed template back and trains from it again.
  void undeleteRoutine(String id) {
    _backend.training.undeleteRoutine(id);
    final restored = _backend.training.routine(id, _exercisesById);
    if (restored != null) selectRoutine(restored);
  }

  /// Adds [exercises] to the running workout, or to the template when no
  /// workout is running.
  void addExercises(List<ExerciseDefinition> exercises) {
    final workout = activeWorkout;
    if (workout != null) {
      _backend.training.addExercises(workout, exercises);
    } else {
      _routine = _backend.training.addToRoutine(_routine, exercises);
    }
    notifyListeners();
  }

  /// Removes the exercise at [index] from the template.
  void removeRoutineExercise(int index) {
    _routine = _backend.training.removeFromRoutine(_routine, index);
    notifyListeners();
  }

  /// Moves an exercise within the template.
  void moveRoutineExercise(int from, int to) {
    _routine = _backend.training.reorderRoutine(_routine, from, to);
    notifyListeners();
  }

  /// Puts a template back as it was, for undoing an edit.
  void restoreRoutine(Routine routine) {
    _routine = routine;
    _backend.training.saveRoutine(routine, action: 'restore');
    notifyListeners();
  }

  void renameRoutine(String name) {
    _routine = _backend.training.renameRoutine(_routine, name);
    notifyListeners();
  }

  /// Stores a new custom exercise and makes it available to pickers.
  void createExercise(ExerciseDefinition exercise) {
    _backend.catalog.create(exercise);
    _reloadExercises();
    notifyListeners();
  }

  /// The catalog matching [query] and [filter], best match first.
  List<ExerciseDefinition> searchExercises({
    String query = '',
    ExerciseFilter filter = const ExerciseFilter(),
  }) => _backend.catalog.search(query: query, filter: filter);

  /// Exercises that may already be what the user is about to create.
  List<ExerciseDefinition> duplicateCandidatesFor(String name) =>
      _backend.catalog.duplicateCandidatesFor(name);

  /// Saves an edited exercise. Throws [TrackingChangeRefused] when the
  /// change would make finished sets mean something else.
  void updateExercise(ExerciseDefinition exercise) {
    _backend.catalog.update(exercise);
    _reloadExercises();
    notifyListeners();
  }

  /// Replaces the names this user gave [exercise]; they only affect this
  /// user's search, not the catalog.
  void setPersonalAliases(ExerciseDefinition exercise, List<String> aliases) {
    _backend.catalog.setPersonalAliases(exercise.id, aliases);
    _reloadExercises();
    notifyListeners();
  }

  void toggleHidden(ExerciseDefinition exercise) {
    _backend.catalog.setHidden(exercise.id, isHidden: !exercise.isHidden);
    _reloadExercises();
    notifyListeners();
  }

  void toggleFavorite(ExerciseDefinition exercise) {
    final isFavorite = !(_exercisesById[exercise.id]?.isFavorite ?? false);
    _backend.catalog.setFavorite(exercise.id, isFavorite: isFavorite);
    _reloadExercises();
    notifyListeners();
  }

  /// Swaps the exercise being done. With [updateTemplate] the plan the
  /// workout came from is changed too, so the swap holds next time; the
  /// workout's own record keeps whatever was actually done either way.
  void replaceCurrentExercise(
    ExerciseDefinition replacement, {
    bool updateTemplate = false,
  }) {
    final workout = activeWorkout;
    if (workout == null) return;
    final replaced = workout.currentExercise.exercise.id;
    _backend.training.replaceCurrentExercise(workout, replacement);
    if (updateTemplate) _replaceInTemplate(workout, replaced, replacement);
    notifyListeners();
  }

  void _replaceInTemplate(
    WorkoutSession workout,
    String replacedId,
    ExerciseDefinition replacement,
  ) {
    final id = workout.routineId;
    if (id == null) return;
    final plan = id == _routine.id
        ? _routine
        : _backend.training.routine(id, _exercisesById);
    if (plan == null) return;
    final updated = _backend.training.replaceInRoutine(
      plan,
      replacedId,
      replacement,
    );
    if (updated.id == _routine.id) _routine = updated;
  }

  /// Pauses whatever is running, or picks it up again.
  void togglePause() {
    switch (_session) {
      case ActiveWorkout(:final workout):
        _backend.training.togglePause(workout);
      case ActiveActivity(:final activity):
        _backend.activity.togglePause(activity);
      case null:
        return;
    }
    notifyListeners();
  }

  /// Abandons the running workout. Logged sets stay in the audit trail
  /// but the workout does not count as training done.
  void discardWorkout() {
    final workout = activeWorkout;
    if (workout == null) return;
    _backend.training.discard(workout);
    _session = null;
    notifyListeners();
  }

  void finishWorkout() {
    final workout = activeWorkout;
    if (workout == null) return;
    _backend.training.finish(workout);
    _lastFinishedWorkout = workout;
    _session = null;
    _phase = DayPhase.evening;
    _ensureLunchLogged();
    _routine = _backend.training.routine(_routine.id, _exercisesById)!;
    _reloadExercises();
    notifyListeners();
  }

  void confirmLunch() {
    _ensureLunchLogged();
    notifyListeners();
  }

  void _ensureLunchLogged() {
    if (isLunchLogged) return;
    final today = now();
    _todayMeals.add(
      _backend.nutrition.logMeal(
        DemoNutrition.lunch,
        eatenAt: DateTime(today.year, today.month, today.day, 12, 35),
      ),
    );
  }

  /// One finished workout, for opening a row in the log.
  WorkoutSession? workoutById(String id) =>
      _backend.storage.workouts.byId(id, _exercise);

  /// Meals eaten on [day]; today's come from what is already in memory.
  List<MealEvent> mealsOn(DateTime day) =>
      _isToday(day) ? todayMeals : _backend.nutrition.mealsOn(day);

  /// Food totals for [day] and how complete its log is.
  DaySummary summaryOf(DateTime day) =>
      _isToday(day) ? todaySummary : _backend.nutrition.summaryOf(day);

  /// Meals worth offering again, newest first.
  List<RecentMeal> get recentMeals => _backend.nutrition.recent();

  /// Logs [meal] as eaten now.
  MealEvent logMeal(MealEvent meal) {
    final logged = _backend.nutrition.logMeal(meal, eatenAt: now());
    _todayMeals.add(logged);
    notifyListeners();
    return logged;
  }

  /// Logs a meal eaten before all over again.
  MealEvent copyMeal(MealEvent meal) {
    final logged = _backend.nutrition.copy(meal);
    _todayMeals.add(logged);
    notifyListeners();
    return logged;
  }

  /// How much caffeine is likely still in the body right now, in
  /// milligrams, from what was logged over the last day.
  ///
  /// An estimate from a population half-life, not a reading. The screen
  /// showing it has to say so.
  double get estimatedCaffeineMg => estimatedCaffeineRemaining(
    caffeineIntakes(
      _backend.nutrition.between(
        now().subtract(const Duration(days: 1)),
        now(),
      ),
    ),
    now: now(),
  );

  /// Saved foods matching [query]; an empty query is all of them.
  List<FoodItem> searchFoods(String query) =>
      _backend.nutrition.searchFoods(query);

  /// How much one tap of the water shortcut logs. The user's own glass
  /// or bottle, because nobody drinks in units the app picked.
  int get glassMillilitres =>
      int.tryParse(_backend.db.setting(_glassKey) ?? '') ??
      defaultGlassMillilitres;

  void setGlassMillilitres(int millilitres) {
    _backend.db.setSetting(_glassKey, '$millilitres');
    notifyListeners();
  }

  /// Logs a glass of water. It writes the same record every drink
  /// writes, so the day's fluid stays one total.
  MealEvent logWater([int? millilitres]) {
    final logged = _backend.nutrition.logWater(millilitres ?? glassMillilitres);
    _todayMeals.add(logged);
    notifyListeners();
    return logged;
  }

  /// The sizes of a food, smallest first. A food with none is logged as
  /// itself.
  List<FoodItem> sizesOf(String foodId) => _backend.nutrition.sizesOf(foodId);

  /// The size names this brand already uses, so a second drink from the
  /// same shop offers the same cups.
  List<String> sizeNamesFor(String brand) =>
      _backend.nutrition.sizeNamesFor(brand);

  /// A fresh id for a food about to be saved.
  String newFoodId() => _backend.nutrition.newFoodId();

  /// Stores a food, new or edited.
  void saveFood(FoodItem food) {
    _backend.nutrition.saveFood(food);
    notifyListeners();
  }

  /// Removes a saved food. The meals already logged from it keep their
  /// numbers, so this is not a change to any record.
  void deleteFood(String id) {
    _backend.nutrition.deleteFood(id);
    notifyListeners();
  }

  void undeleteFood(String id) {
    _backend.nutrition.undeleteFood(id);
    notifyListeners();
  }

  /// Logs a portion of a saved food as a meal eaten now.
  MealEvent logPortion(FoodPortion portion, {MealType? mealType}) {
    final logged = _backend.nutrition.logPortion(portion, mealType: mealType);
    _todayMeals.add(logged);
    notifyListeners();
    return logged;
  }

  DishSplitSnapshot? splitDish({
    required String mealId,
    required int dishIndex,
    DateTime? day,
  }) {
    final date = day ?? now();
    final exploded = _backend.nutrition.explodeDish(
      mealsOn(date),
      mealId: mealId,
      dishIndex: dishIndex,
      day: date,
    );
    if (exploded == null) return null;
    final (meal, snapshot) = exploded;
    if (_isToday(date)) _todayMeals[snapshot.mealIndex] = meal;
    notifyListeners();
    return snapshot;
  }

  void undoSplit(DishSplitSnapshot snapshot) {
    _backend.nutrition.undoExplode(
      snapshot,
      current: mealsOn(snapshot.day)[snapshot.mealIndex],
    );
    if (_isToday(snapshot.day)) {
      _todayMeals[snapshot.mealIndex] = snapshot.meal;
    }
    notifyListeners();
  }

  bool _isToday(DateTime day) {
    final today = now();
    return day.year == today.year &&
        day.month == today.month &&
        day.day == today.day;
  }

  /// Body weights measured in the last few weeks, oldest first.
  List<BodyWeight> get recentWeights =>
      _backend.journal.recentWeights(const Duration(days: 28));

  /// Nights logged in the last few weeks, oldest first.
  List<SleepEntry> get recentSleep =>
      _backend.journal.recentSleep(const Duration(days: 28));

  /// Exercise logged on [day].
  List<ActivitySession> activitiesOn(DateTime day) => _backend.activity.on(day);

  /// The kinds of exercise used recently, newest first.
  List<ActivityType> get recentActivityTypes => _backend.activity.recentTypes();

  /// Where the duration field starts for [type].
  Duration startingActivityDuration(ActivityType type) =>
      _backend.activity.startingDuration(type);

  /// Exercise over the last few weeks, for the trends card.
  ActivitySummary activitySummary({
    Duration window = const Duration(days: 28),
  }) => _backend.activity.summary(window: window);

  /// Records a session of general exercise.
  ActivitySession logActivity({
    required ActivityType type,
    required DateTime startedAt,
    required Duration duration,
    double? distanceMeters,
    double? elevationGainMeters,
    int? effort,
    String note = '',
  }) {
    final activity = _backend.activity.log(
      type: type,
      startedAt: startedAt,
      duration: duration,
      distanceMeters: distanceMeters,
      elevationGainMeters: elevationGainMeters,
      effort: effort,
      note: note,
    );
    notifyListeners();
    return activity;
  }

  /// Starts timing [type] from now. Refuses while a workout is running,
  /// rather than quietly ending it.
  bool startActivity(ActivityType type) {
    if (_session != null) return false;
    _session = ActiveActivity(_backend.activity.start(type));
    notifyListeners();
    return true;
  }

  /// Stops the running session and keeps it as a record.
  ActivitySession? finishActivity({
    double? distanceMeters,
    double? elevationGainMeters,
    int? effort,
    String note = '',
  }) {
    final live = activeActivity;
    if (live == null) return null;
    final finished = _backend.activity.finish(
      live,
      distanceMeters: distanceMeters,
      elevationGainMeters: elevationGainMeters,
      effort: effort,
      note: note,
    );
    _session = null;
    notifyListeners();
    return finished;
  }

  /// Throws the running session away without counting it.
  void discardActivity() {
    final live = activeActivity;
    if (live == null) return;
    _backend.activity.discard(live);
    _session = null;
    notifyListeners();
  }

  /// A logged session, or null once it has been removed.
  ActivitySession? activityById(String id) => _backend.activity.byId(id);

  /// Saves a correction to a session already logged.
  void updateActivity(ActivitySession activity) {
    _backend.activity.edit(activity);
    notifyListeners();
  }

  /// Removes a session; [restoreActivity] takes it back.
  void deleteActivity(String id) {
    _backend.activity.delete(id);
    notifyListeners();
  }

  void restoreActivity(String id) {
    _backend.activity.restore(id);
    notifyListeners();
  }

  /// Records a body weight measured now.
  void recordWeight(double kilograms, {String note = ''}) {
    _backend.journal.recordWeight(kilograms, note: note);
    notifyListeners();
  }

  /// Records one tape measurement.
  void recordMeasurement(
    MeasurementSite site,
    double centimetres, {
    String note = '',
  }) {
    _backend.journal.recordMeasurement(site, centimetres, note: note);
    notifyListeners();
  }

  /// The last measurement of each site, for prefilling and for showing
  /// what has been tracked at all.
  Map<MeasurementSite, BodyMeasurement> get latestMeasurements =>
      _backend.journal.latestMeasurements();

  /// Records a night's sleep.
  void recordSleep(Duration slept, {int? score, String note = ''}) {
    _backend.journal.recordSleep(slept, score: score, note: note);
    notifyListeners();
  }

  /// Records a 1–5 wellness check-in.
  void recordWellness(WellnessKind kind, int score, {String note = ''}) {
    _backend.journal.recordWellness(kind, score, note: note);
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
    _backend.training.saveRoutine(
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
