import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../backend/application/ai_service.dart';
import '../backend/ai/copilot_drafter.dart';
import '../backend/application/health_service.dart';
import '../backend/engines/progression_engine.dart';
import '../backend/application/provenance_service.dart';
import '../backend/backend.dart';
import '../backend/health/health_source.dart';
import '../backend/engines/nutrition_summary.dart';
import '../backend/seed/demo_content.dart';
import '../backend/seed/seed.dart';
import '../backend/storage/database.dart';
import '../domain/domain.dart';

export '../backend/application/catalog_service.dart' show TrackingChangeRefused;
export '../backend/application/provenance_service.dart'
    show CatalogueRecord, ImportRecord;
export '../backend/application/nutrition_service.dart'
    show DishSplitSnapshot, RecentFood, RecentMeal;

/// Which moment of the mock day the Today screen is showing.
enum DayPhase {
  morning('早上'),
  noon('中午'),
  evening('20:41');

  const DayPhase(this.label);

  final String label;
}

enum AppModule {
  nutrition('飲食', '一餐、料理、成分與營養'),
  weight('體重', '體重與圍度'),
  training('訓練', '動作、訓練模板與訓練紀錄'),
  activity('運動', '跑步、健走、騎車、球類、瑜伽'),
  sleep('睡眠', '睡眠時間與品質'),
  wellness('心情、精力、症狀', '一天的狀態日誌'),
  notes('筆記', '和任何一天或一筆紀錄關聯');

  const AppModule(this.title, this.description);

  final String title;
  final String description;
}

enum HomeTab { today, log, trends, me }

class AppStore extends ChangeNotifier {
  /// [backend] defaults to a seeded in-memory store (tests, previews); the
  /// app passes the on-device one. A given [isOnboarded] overrides and
  /// saves the stored value. [ai] defaults to no provider at all.
  AppStore({
    DateTime Function()? clock,
    bool? isOnboarded,
    Backend? backend,
    AiService? ai,
    HealthSource? health,
  }) : _clock = clock ?? DateTime.now,
       _backend = backend ?? Backend.inMemory(clock: clock),
       _ownsBackend = backend == null {
    _ai = ai ?? AiService.none(_backend.db);
    _health = _backend.healthFrom(health ?? const NoHealthSource());
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
    _backend.db.changes.addListener(_onRecordsChanged);
  }

  /// A write from a feature's view model, which this store does not see
  /// made: what it keeps in memory is read again, and the screens still
  /// reading from here are rebuilt.
  void _onRecordsChanged() {
    _todayMealsRead = null;
    notifyListeners();
  }

  static const _aiProposalSquatSets = 5;
  static const _aiProposalLegCurlSets = 4;
  static const _onboardedKey = 'onboarded';
  static const _modulesKey = 'enabled_modules';
  static const _selectedRoutineKey = 'selected_routine';

  final DateTime Function() _clock;
  final Backend _backend;
  late final AiService _ai;
  late final HealthService _health;
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

  /// Today's meals as last read, and the day they were read for; read
  /// again after any write and when the day turns.
  (DateTime, List<MealEvent>)? _todayMealsRead;

  List<MealEvent> get _todayMeals {
    final today = now();
    final day = DateTime(today.year, today.month, today.day);
    final read = _todayMealsRead;
    if (read != null && read.$1 == day) return read.$2;
    final meals = _backend.nutrition.mealsOn(today);
    _todayMealsRead = (day, meals);
    return meals;
  }

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

  /// Where the previous database file was moved to when it could not be
  /// read, or null on a normal start. The app says so rather than
  /// looking as though the records were never there.
  String? get recoveredDatabasePath => _backend.db.recoveredFrom;

  /// How much the store takes on disk.
  int get databaseBytes => _backend.db.sizeInBytes;

  /// Records the user entered themselves, per category.
  Map<RecordCategory, int> get typedRecordCounts =>
      _backend.provenance.recordCounts(ChangeSource.local);

  /// Demo records put in on first launch, per category. Not the user's.
  Map<RecordCategory, int> get demoRecordCounts =>
      _backend.provenance.recordCounts(ChangeSource.seed);

  List<ImportRecord> get imports => _backend.provenance.imports();

  List<CatalogueRecord> get catalogues => _backend.provenance.catalogues();

  /// Today's food totals and how complete the day's log is.
  DaySummary get todaySummary => summariseDay(_todayMeals, isOver: false);

  int get todayKcal => todaySummary.kcal;

  @override
  void dispose() {
    _backend.db.changes.removeListener(_onRecordsChanged);
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
    _backend.nutrition.logMeal(
      DemoNutrition.lunch,
      eatenAt: DateTime(today.year, today.month, today.day, 12, 35),
    );
  }

  /// One finished workout, for opening a row in the log.
  WorkoutSession? workoutById(String id) =>
      _backend.storage.workouts.byId(id, _exercise);

  /// The provider drafts come from, or null until one is chosen.
  AiProviderKind? get aiProvider => _ai.provider;

  void setAiProvider(AiProviderKind kind) {
    _ai.setProvider(kind);
    notifyListeners();
  }

  /// The model the chosen provider is set to use.
  String get aiModel => switch (_ai.provider) {
    final kind? => _ai.modelFor(kind),
    null => '',
  };

  void setAiModel(String model) {
    if (_ai.provider case final kind?) _ai.setModel(kind, model);
    notifyListeners();
  }

  /// The models the chosen provider offers. Throws [AiException].
  Future<List<String>> aiModels() => _ai.models();

  /// Where the chosen provider lives, when it needs an address.
  String get aiEndpoint => switch (_ai.provider) {
    final kind? => _ai.endpointFor(kind),
    null => '',
  };

  void setAiEndpoint(String address) {
    if (_ai.provider case final kind?) _ai.setEndpoint(kind, address);
    notifyListeners();
  }

  bool get hasCloudConsent => _ai.hasCloudConsent;

  void setCloudConsent(bool agreed) {
    _ai.setCloudConsent(agreed);
    notifyListeners();
  }

  bool get hasPhotoConsent => _ai.hasPhotoConsent;

  void setPhotoConsent(bool agreed) {
    _ai.setPhotoConsent(agreed);
    notifyListeners();
  }

  /// The app registration Microsoft 365 Copilot signs in through.
  String get aiClientId => _ai.clientId;

  void setAiClientId(String id) {
    _ai.setClientId(id);
    notifyListeners();
  }

  /// The tenant that registration belongs to; blank means any.
  String get aiTenant => _ai.tenant;

  void setAiTenant(String tenant) {
    _ai.setTenant(tenant);
    notifyListeners();
  }

  /// Starts a Copilot sign-in; [finishAiSignIn] waits for it.
  Future<DeviceCodePrompt> startAiSignIn() => _ai.startSignIn();

  Future<void> finishAiSignIn(DeviceCodePrompt prompt) async {
    await _ai.finishSignIn(prompt);
    notifyListeners();
  }

  /// Whether the chosen provider has its key.
  Future<bool> hasAiKey() async => switch (_ai.provider) {
    final kind? => _ai.hasKey(kind),
    null => false,
  };

  Future<void> setAiKey(String key) async {
    if (_ai.provider case final kind?) await _ai.setKey(kind, key);
    notifyListeners();
  }

  Future<AiAvailability> aiAvailability(AiProviderKind kind) =>
      _ai.availability(kind);

  /// A draft of a described meal; nothing is logged. Throws
  /// [AiException].
  Future<MealDraft> draftMeal(String description) => _ai.draftMeal(description);

  /// A food drafted from a photo of its nutrition label; nothing is
  /// saved. Throws [AiException].
  Future<FoodLabelDraft> scanFoodLabel(String imagePath) =>
      _ai.scanFoodLabel(imagePath);

  /// The items a food photo shows, with estimated figures; nothing is
  /// logged. Throws [AiException].
  Future<MealDraft> draftMealPhoto(String imagePath, {String note = ''}) =>
      _ai.draftMealPhoto(imagePath, note: note);

  /// Exercise logged on [day].
  List<ActivitySession> activitiesOn(DateTime day) => _backend.activity.on(day);

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

  /// The health platform on this device: Apple Health or Health Connect.
  String get healthSourceName => _health.source.name;

  /// What it can be read for.
  Set<HealthDataKind> get healthKinds => _health.source.kinds;

  Future<bool> isHealthAvailable() => _health.isAvailable();

  bool get isHealthConnected => _health.isConnected;

  /// What the user allowed; null when the platform will not say.
  Future<Set<HealthDataKind>?> healthGrantedKinds() => _health.grantedKinds();

  /// Asks again for what was not allowed, and reads what now is.
  Future<HealthImport?> askHealthAgain() async {
    final imported = await _health.askAgain();
    _reloadAfterImport();
    return imported;
  }

  /// Shows the privacy page whenever the platform asks the app to
  /// explain its use of health data.
  Future<void> onHealthPrivacyRequest(void Function() show) =>
      _health.source.onPrivacyRequest(show);

  DateTime? get lastHealthSync => _health.lastSync;

  /// Asks for read access to every kind and reads the last month; null
  /// when the platform is missing or the request did not go through.
  Future<HealthImport?> connectHealth() async {
    final imported = await _health.connect();
    _reloadAfterImport();
    return imported;
  }

  void disconnectHealth() {
    _health.disconnect();
    notifyListeners();
  }

  /// Reads the last month again, when connected.
  Future<HealthImport?> syncHealth() async {
    if (!_health.isConnected) return null;
    final imported = await _health.importAll();
    _reloadAfterImport();
    return imported;
  }

  /// Whether the last automatic sync failed.
  bool get healthSyncFailed => _healthSyncFailed;
  bool _healthSyncFailed = false;

  /// The sync run at launch. Nobody is waiting on it, so a failure is
  /// kept for 資料來源 to show rather than thrown into nowhere.
  Future<void> syncHealthInBackground() async {
    try {
      await syncHealth();
      _healthSyncFailed = false;
    } on Exception {
      _healthSyncFailed = true;
    }
    notifyListeners();
  }

  void _reloadAfterImport() => notifyListeners();

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
