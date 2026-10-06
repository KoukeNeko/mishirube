import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../backend/application/training_service.dart'
    show RemovedSet, WorkoutTiming, routineNameFor;
import '../backend/engines/workout_text.dart';
import 'device_motion.dart';
import 'set_timer.dart';

export 'device_motion.dart';
import '../backend/application/ai_service.dart';
import '../backend/ai/copilot_drafter.dart';
import '../backend/application/health_service.dart';
import '../backend/engines/body_metrics.dart';
import '../backend/engines/progression_engine.dart';
import '../backend/engines/workout_review.dart';
import '../backend/application/provenance_service.dart';
import '../backend/application/sleep_service.dart';
import '../backend/backend.dart';
import '../backend/health/health_source.dart';
import '../backend/engines/nutrition_summary.dart';
import '../backend/seed/demo_content.dart';
import '../backend/seed/seed.dart';
import '../backend/storage/database.dart';
import '../domain/domain.dart';
import '../shared/system_calendar.dart';

export '../backend/application/catalog_service.dart' show TrackingChangeRefused;
export '../backend/application/provenance_service.dart'
    show CatalogueRecord, ImportRecord;
export '../backend/application/nutrition_service.dart'
    show DishSplitSnapshot, RecentFood, RecentMeal;

/// A part of the app the user can switch on; named in the app's language
/// by [AppModuleText].
enum AppModule {
  nutrition,
  water,
  weight,
  training,
  activity,
  sleep,
  wellness,
  notes,
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
    this.motion = const NoDeviceMotion(),
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
      // Water was part of 飲食 before it was a module of its own: whoever
      // kept 飲食 on keeps it.
      if (_backend.db.setting(_waterModuleKey) == null &&
          _enabledModules.contains(AppModule.nutrition)) {
        _enabledModules.add(AppModule.water);
        _saveModules();
      }
    }
    _backend.db.setSetting(_waterModuleKey, 'true');
    _reloadExercises();
    _routine = _backend.training.routines(_exercisesById).firstOrNull;
    _session = switch ((
      _backend.training.active(),
      _backend.activity.active(),
      _backend.journal.runningBath(),
    )) {
      (final WorkoutSession workout, _, _) => ActiveWorkout(workout),
      (_, final LiveActivity live, _) => ActiveActivity(live),
      (_, _, final LiveBath bath) => ActiveBath(bath),
      _ => null,
    };
    _lastFinishedWorkout = _backend.training.lastFinished();
    _savedTiming = _backend.training.storedTiming;
    if (_session case ActiveWorkout(:final workout)) _restoreTiming(workout);
    _backend.db.changes.addListener(_onRecordsChanged);
  }

  /// A write from a feature's view model, which this store does not see
  /// made: what it keeps in memory is read again, and the screens still
  /// reading from here are rebuilt.
  void _onRecordsChanged() {
    _todayMealsRead = null;
    // The template shown may have been deleted elsewhere; another takes
    // its place.
    if (_routine case final shown?
        when _backend.training.routine(shown.id, _exercisesById) == null) {
      _routine = routines.firstOrNull;
    }
    notifyListeners();
  }

  static const _aiProposalSquatSets = 5;
  static const _aiProposalLegCurlSets = 4;
  static const _onboardedKey = 'onboarded';
  static const _modulesKey = 'enabled_modules';

  /// Set once the stored modules have had water split from 飲食.
  static const _waterModuleKey = 'water_module';

  final DateTime Function() _clock;
  final Backend _backend;
  late final AiService _ai;
  late final HealthService _health;

  /// How the device is held and moved; none unless the app passes the
  /// sensor in.
  final DeviceMotion motion;
  final bool _ownsBackend;

  late bool _isOnboarded;

  /// On until the user says otherwise: the modules whose records the app
  /// can actually log today.
  final Set<AppModule> _enabledModules = {
    AppModule.nutrition,
    AppModule.water,
    AppModule.weight,
    AppModule.training,
    AppModule.activity,
    AppModule.sleep,
    AppModule.wellness,
  };

  /// The template shown and trained from; null once every one is gone.
  Routine? _routine;

  /// [_routine], for what is only done with a template open.
  Routine get _shown => _routine!;
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

  /// The template open for editing and starting; only read where one
  /// is open (see [selectedRoutine]).
  Routine get routine => _shown;

  /// The template open for editing; null when there is none.
  Routine? get selectedRoutine => _routine;

  /// Every template, for choosing what to train.
  List<Routine> get routines => _backend.training.routines(_exercisesById);

  /// Whatever is running, of whatever kind; null when nothing is.
  ActiveSession? get activeSession => _session;

  /// The heart rate a paired watch last sent and when it was taken; live
  /// and in memory only, never stored. Not a notifying change: the clock
  /// on the workout page ticks every second and reads it then.
  int? _heartRate;
  DateTime? _heartRateAt;

  /// How long a reading stays current once the watch stops sending.
  static const liveHeartRateMaxAge = Duration(seconds: 30);

  /// The latest watch heart rate while a workout runs and the reading is
  /// recent; null otherwise.
  int? get liveHeartRate {
    final at = _heartRateAt;
    if (_heartRate == null || at == null || activeWorkout == null) return null;
    return now().difference(at) > liveHeartRateMaxAge ? null : _heartRate;
  }

  void takeHeartRate(int bpm, DateTime at) {
    if (_heartRateAt case final last? when at.isBefore(last)) return;
    _heartRate = bpm;
    _heartRateAt = at;
  }

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

  /// How long [routine] takes, in whole minutes.
  int expectedMinutes(Routine routine) =>
      (_backend.training.expectedLength(routine).inSeconds /
              Duration.secondsPerMinute)
          .round();

  /// The current template's last few finished workouts, newest first.
  List<WorkoutSession> get recentRoutineWorkouts =>
      _backend.training.recentOf(_shown);

  /// The latest weighing, the last week's weighings with their trend and
  /// how far the trend moved; null for what there are no weighings for.
  ({
    BodyWeight? latest,
    List<(DateTime, double, double)> week,
    double? weekChange,
  })
  get weightSummary {
    final weights = _backend.journal.recentWeights(const Duration(days: 14));
    final from = now().subtract(const Duration(days: 7));
    final week = [
      for (final point in trendOf(weights))
        if (!point.$1.isBefore(from)) point,
    ];
    return (
      latest: weights.lastOrNull,
      week: week,
      weekChange: trendChange(week),
    );
  }

  /// The latest night, if it ended today or yesterday.
  SleepRecord? get lastNight => _backend.sleep.lastNight();

  /// Working sets per muscle over the last seven days.
  List<(MuscleGroup, int)> get weekMuscleSets =>
      _backend.insights.muscleLoad(window: const Duration(days: 7));

  /// Records how a finished workout felt; the next suggestions read it.
  void rateWorkout(WorkoutSession workout, Workload workload) {
    _backend.training.rate(workout, workload);
    notifyListeners();
  }

  /// Rewrites what a finished workout was done at, and when and for how
  /// long when [timing] is given.
  void correctWorkout(
    WorkoutSession workout,
    List<WorkoutCorrection> corrections, {
    ({DateTime startedAt, Duration length})? timing,
  }) {
    _backend.training.correct(workout, corrections, timing: timing);
    _workoutsChanged();
  }

  /// [exercise] as it is usually planned, for adding it somewhere.
  PlannedExercise usualPlan(ExerciseDefinition exercise) =>
      _backend.training.planFor(exercise);

  /// Removes a finished workout; [restoreWorkout] takes it back.
  void deleteWorkout(String id) {
    _backend.training.delete(id);
    _workoutsChanged();
  }

  void restoreWorkout(String id) {
    _backend.training.restore(id);
    _workoutsChanged();
  }

  /// What a finished workout coming or going changes: which one was
  /// last, and each exercise's use.
  void _workoutsChanged() {
    _lastFinishedWorkout = _backend.training.lastFinished();
    _reloadExercises();
    notifyListeners();
  }

  /// [workout] against what came before it.
  WorkoutReview workoutReview(WorkoutSession workout) =>
      _backend.training.review(workout);

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
    if (_routine case final shown?) {
      _routine = _backend.training.routine(shown.id, _exercisesById);
    }
    notifyListeners();
  }

  /// What to do with each planned exercise next time, with the reason.
  /// Nothing is applied until the user accepts it.
  List<(PlannedExercise, ProgressionSuggestion)> get progressionSuggestions =>
      _backend.training.suggestions(_shown);

  /// Writes one suggestion into the template.
  void applySuggestion(
    PlannedExercise planned,
    ProgressionSuggestion suggestion,
  ) {
    _routine = _backend.training.applySuggestion(_shown, planned, suggestion);
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

  /// The year the user was born, as given under 我的.
  int? get birthYear => _backend.journal.birthYear;

  void setBirthYear(int? year) {
    _backend.journal.setBirthYear(year);
    notifyListeners();
  }

  /// Workouts finished, all time.
  int get finishedWorkoutCount =>
      _backend.storage.workouts.completedStarts().length;

  /// The first month holding any record; null before there is one.
  DateTime? get firstRecordMonth => _backend.timeline.earliestMonth();

  /// Whether the demo records show; switched in 我的.
  bool get showsDemo => _backend.provenance.showsDemo;

  bool get hasDemo => _backend.provenance.hasDemo;

  void setShowsDemo(bool shows) => _backend.provenance.setShowsDemo(shows);

  List<ImportRecord> get imports => _backend.provenance.imports();

  List<CatalogueRecord> get catalogues => _backend.provenance.catalogues();

  /// Today's food totals and how complete the day's log is. Plain water
  /// is 喝水's, not a record of food.
  DaySummary get todaySummary => summariseDay([
    for (final meal in _todayMeals)
      if (!meal.isWater) meal,
  ], isOver: false);

  double get todayKcal => todaySummary.kcal;

  @override
  void dispose() {
    _slowRead?.cancel();
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
    _saveModules();
    notifyListeners();
  }

  void _saveModules() => _backend.db.setSetting(
    _modulesKey,
    jsonEncode([for (final m in _enabledModules) m.name]),
  );

  void completeOnboarding() {
    _isOnboarded = true;
    _backend.db.setSetting(_onboardedKey, 'true');
    notifyListeners();
  }

  /// Starts (or picks up) today's workout. Refuses while exercise or a
  /// bath is being timed: ending someone's run for them is not ours to do.
  ///
  /// [routine] is the template shown unless given; muscles in [sore]
  /// get a set fewer on each exercise that works them.
  bool startWorkout({Routine? routine, Set<MuscleGroup> sore = const {}}) {
    if (_session case ActiveActivity() || ActiveBath()) return false;
    _session = ActiveWorkout(
      activeWorkout ?? _backend.training.start(routine ?? _shown, sore: sore),
    );
    notifyListeners();
    return true;
  }

  /// A workout written as text, line by line: each line with the
  /// exercise it most likely names, planned at the sets, reps and weight
  /// it gave (the usual ones where it gave none); null for a line whose
  /// name matches nothing.
  List<(WorkoutLine, PlannedExercise?)> draftWorkout(String text) =>
      _planLines(parseWorkoutText(text));

  /// The same, read by the chosen AI, for text the rules could not read
  /// all of. Throws [AiException].
  Future<List<(WorkoutLine, PlannedExercise?)>> draftWorkoutWithAi(
    String text,
  ) async => _planLines(await _ai.draftWorkout(text));

  List<(WorkoutLine, PlannedExercise?)> _planLines(List<WorkoutLine> lines) => [
    for (final line in lines)
      if (_backend.catalog.bestMatch([line.name, ?line.otherName])
          case final exercise?)
        (line, planLine(line, exercise))
      // A line with no exercise and no figures is a column heading or
      // a remark around the list (a rest of 90 s too), not an exercise to
      // pick.
      else if (line.sets != null ||
          line.reps != null ||
          line.weightKg != null ||
          line.meters != null)
        (line, null),
  ];

  /// [exercise] planned as [line] says, set by set when it gave each
  /// set, the usual figures where it is silent.
  PlannedExercise planLine(WorkoutLine line, ExerciseDefinition exercise) {
    final usual = _backend.training.planFor(exercise);
    return line.loads.isNotEmpty
        ? PlannedExercise.ofLoads(usual, line.loads)
        // Only the figures the exercise is recorded by are taken.
        : usual.copyWith(
            sets: line.sets,
            reps: exercise.trackingType.usesReps ? line.reps : null,
            targetWeightKg: exercise.trackingType.usesWeight
                ? line.weightKg
                : null,
            targetSeconds: exercise.trackingType.usesTime ? line.seconds : null,
            targetMeters: exercise.trackingType.usesDistance
                ? line.meters
                : null,
          );
  }

  /// Starts a workout planned as [planned]. Refuses while exercise is
  /// being timed.
  bool startPlannedWorkout(List<PlannedExercise> planned) {
    if (_session is ActiveSession) return false;
    _session = ActiveWorkout(_backend.training.startPlanned(planned));
    notifyListeners();
    return true;
  }

  /// A new template of [planned] called [name], kept for later: saving
  /// it is not opening it.
  Routine createRoutineOf(
    List<PlannedExercise> planned, {
    required String name,
  }) {
    final created = _backend.training.createRoutine(name, exercises: planned);
    notifyListeners();
    return created;
  }

  /// The name a template of [planned] gets: what it trains.
  String routineNameOf(List<PlannedExercise> planned) =>
      routineNameFor(planned, _backend.l10n);

  /// Finished workouts to start a new one from, newest first.
  List<WorkoutSession> get recentWorkouts => _backend.training.recentFinished();

  /// Starts a workout from [exercises] of earlier workouts, at the sets
  /// they were done at. Refuses while exercise is being timed.
  bool startFromPast(List<ExerciseSession> exercises) {
    if (_session is ActiveSession) return false;
    _session = ActiveWorkout(_backend.training.startFrom(exercises));
    notifyListeners();
    return true;
  }

  /// Starts a workout from no template, with [exercises] to begin with.
  /// Refuses while exercise is being timed, as [startWorkout] does.
  bool startFreeWorkout(List<ExerciseDefinition> exercises) {
    if (_session is ActiveSession) return false;
    _session = ActiveWorkout(_backend.training.startFree(exercises));
    notifyListeners();
    return true;
  }

  /// When the rest between sets ends, and how long it was set for; null
  /// when nobody is resting. Kept with [WorkoutTiming], so a rest outlives
  /// the app.
  DateTime? _restEndsAt;
  Duration _restLength = Duration.zero;
  ExerciseDefinition? _restExercise;

  /// When the last rest ran out, while the card for it is still shown
  /// counting the time since: the rest is over, the next set is not yet.
  DateTime? _restEndedAt;

  /// The text last handed to [TrainingService.saveTiming].
  String _savedTiming = '';

  /// When the running rest ends; null once it has, however long the card
  /// goes on showing it ([restEndedAt]).
  DateTime? get restEndsAt => _restEndsAt;
  DateTime? get restEndedAt => _restEndedAt;
  Duration get restLength => _restLength;

  /// Whether the rest card is shown: a rest running, or run out and not
  /// yet dismissed.
  bool get isResting => _restEndsAt != null || _restEndedAt != null;

  /// The exercise whose set the running rest follows.
  ExerciseDefinition? get restExercise => _restExercise;

  /// Starts the rest after a set of [exercise], as long as was set for it;
  /// no rest at all when that is none.
  void startRest(ExerciseDefinition exercise) {
    final length = restFor(exercise);
    if (length == Duration.zero) return;
    _restLength = length;
    _restExercise = exercise;
    _restEndsAt = now().add(length);
    _restEndedAt = null;
    notifyListeners();
  }

  /// Starts the rest after a set of the exercise at [index] when one
  /// follows it: not after the last set of the workout, not while a later
  /// exercise of its superset still has a set to do, and not when the rest
  /// is not set to start by itself. True when it started.
  bool restAfterSet(int index) {
    final workout = activeWorkout;
    if (workout == null ||
        !isAutoRest ||
        workout.completedSets == workout.totalSets ||
        !workout.restsAfter(index) ||
        restFor(workout.exercises[index].exercise) == Duration.zero) {
      return false;
    }
    startRest(workout.exercises[index].exercise);
    return true;
  }

  /// How long the rest after a set of [exercise] lasts.
  Duration restFor(ExerciseDefinition exercise) =>
      _backend.training.restFor(exercise);

  /// Sets how long the rest after a set of [exercise] lasts; the rest
  /// running now is left as it is.
  void setRestFor(ExerciseDefinition exercise, Duration rest) {
    _backend.training.setRest(exercise, rest);
    notifyListeners();
  }

  /// Whether the rest starts by itself when a set is done.
  bool get isAutoRest => _backend.training.isAutoRest;

  void setAutoRest(bool isOn) {
    _backend.training.setAutoRest(isOn);
    notifyListeners();
  }

  /// Whether the end of a rest or a timed set is told by a sound as well
  /// as a vibration.
  bool get isCueSound => _backend.training.isCueSound;

  void setCueSound(bool isOn) {
    _backend.training.setCueSound(isOn);
    notifyListeners();
  }

  /// Lengthens the rest running by [by], or shortens it when negative; a
  /// rest cut to nothing is over.
  void extendRest(Duration by) {
    final endsAt = _restEndsAt;
    if (endsAt == null) return;
    _restLength += by;
    if (_restLength.isNegative) _restLength = Duration.zero;
    _restEndsAt = endsAt.add(by);
    if (!_restEndsAt!.isAfter(now())) _restEndsAt = null;
    notifyListeners();
  }

  /// Ends the rest, or takes the card away once it has run out.
  void skipRest() {
    if (!isResting) return;
    _restEndsAt = null;
    _restEndedAt = null;
    notifyListeners();
  }

  /// Ends the rest once its time is up; the card stays, counting the time
  /// past it. True only for the call that ended it, so whichever clock
  /// notices first gives the one signal.
  bool settleRest() {
    final endsAt = _restEndsAt;
    if (endsAt == null || now().isBefore(endsAt)) return false;
    _restEndsAt = null;
    _restEndedAt = endsAt;
    notifyListeners();
    return true;
  }

  SetTimer? _setTimer;

  /// The set being timed, if any: a plank held, a run under way. Kept
  /// with [WorkoutTiming], so it outlives the app. A timer whose set has
  /// gone from the workout is dropped.
  SetTimer? get setTimer {
    final timer = _setTimer;
    final workout = activeWorkout;
    if (timer != null &&
        (workout == null ||
            !workout.exercises.any(
              (exercise) =>
                  exercise.sets.any((set) => identical(set, timer.set)),
            ))) {
      return _setTimer = null;
    }
    return timer;
  }

  /// Starts timing [set], which begins a workout that is only scheduled,
  /// and drops any other set's timer.
  void startSetTimer(WorkoutSet set) {
    final workout = activeWorkout;
    if (workout == null) return;
    _backend.training.begin(workout);
    _setTimer = SetTimer(set, now());
    _restEndedAt = null;
    notifyListeners();
  }

  /// Holds the timer, or picks it up again.
  void toggleSetTimerPause() {
    final timer = setTimer;
    if (timer == null) return;
    final at = now();
    if (timer.pausedAt case final pausedAt?) {
      timer.startedAt = timer.startedAt.add(at.difference(pausedAt));
      timer.pausedAt = null;
    } else {
      timer.pausedAt = at;
    }
    notifyListeners();
  }

  /// Does what the timer was started for once it reaches the time the set
  /// was planned for: the set is done at that time, and the rest after it
  /// starts. True only for the call that did, so whichever clock notices
  /// first (the page's, the app coming back, a restart) gives the one
  /// signal. A set with no planned time counts up until it is ended.
  bool settleSetTimer() {
    final timer = setTimer;
    final planned = timer?.set.durationSeconds;
    final workout = activeWorkout;
    if (timer == null ||
        workout == null ||
        planned == null ||
        planned <= 0 ||
        timer.elapsedAt(now()).inSeconds < planned) {
      return false;
    }
    final (exerciseIndex, setIndex) = _placeOf(workout, timer.set)!;
    focusExercise(exerciseIndex);
    editSet(
      setIndex,
      weightKg: timer.set.weightKg,
      reps: timer.set.reps,
      rir: timer.set.rir,
      seconds: stopSetTimer(),
    );
    if (!workout.exercises[exerciseIndex].sets[setIndex].isDone) {
      toggleSet(setIndex);
    }
    restAfterSet(exerciseIndex);
    return true;
  }

  /// Ends the timer and gives the whole seconds it counted, no more than
  /// the set was planned for: a timer nobody looked at past its time
  /// logs that time, not the time it ran on. Null when no set is being
  /// timed.
  int? stopSetTimer() {
    final timer = setTimer;
    if (timer == null) return null;
    _setTimer = null;
    notifyListeners();
    final seconds = timer.elapsedAt(now()).inSeconds;
    final planned = timer.set.durationSeconds ?? 0;
    return planned > 0 && seconds > planned ? planned : seconds;
  }

  /// Where [set] is in [workout]: its exercise and its place among that
  /// exercise's sets; null when it is not there.
  static (int, int)? _placeOf(WorkoutSession workout, WorkoutSet set) {
    for (final (exerciseIndex, exercise) in workout.exercises.indexed) {
      final setIndex = exercise.sets.indexWhere(
        (other) => identical(other, set),
      );
      if (setIndex >= 0) return (exerciseIndex, setIndex);
    }
    return null;
  }

  /// The rest and the timed set as [WorkoutTiming] keeps them, null with
  /// no workout under way. Reads the timer without [setTimer]'s dropping
  /// it: a set being edited is briefly not the one the timer holds.
  WorkoutTiming? _timing() {
    final workout = activeWorkout;
    if (workout == null) return null;
    final timer = _setTimer;
    final place = timer == null ? null : _placeOf(workout, timer.set);
    return WorkoutTiming(
      workoutId: workout.id,
      restEndsAt: _restEndsAt,
      restLength: _restLength,
      restExerciseId: _restExercise?.id,
      timerExercise: place?.$1,
      timerSet: place?.$2,
      timerStartedAt: place == null ? null : timer!.startedAt,
      timerPausedAt: place == null ? null : timer!.pausedAt,
    );
  }

  /// Keeps the timing when it changed. Every change to it is announced,
  /// so it is saved from [notifyListeners].
  void _saveTiming() {
    final timing = _timing();
    final encoded = timing == null || timing.isEmpty ? '' : timing.encode();
    if (encoded == _savedTiming) return;
    _savedTiming = encoded;
    _backend.training.saveTiming(timing);
  }

  @override
  void notifyListeners() {
    _saveTiming();
    super.notifyListeners();
  }

  /// Takes up the rest and the timed set kept for [workout]; a rest that
  /// ran out meanwhile is gone, a set past its time is done at that time.
  void _restoreTiming(WorkoutSession workout) {
    final kept = _backend.training.timing(workout.id);
    if (kept == null) return;
    if (kept.restEndsAt case final endsAt? when endsAt.isAfter(now())) {
      _restEndsAt = endsAt;
      _restLength = kept.restLength;
      _restExercise = switch (kept.restExerciseId) {
        final id? => _exercisesById[id],
        null => null,
      };
    }
    final exercises = workout.exercises;
    if (kept.timerExercise case final exerciseIndex? when exerciseIndex >= 0) {
      final sets = exerciseIndex < exercises.length
          ? exercises[exerciseIndex].sets
          : const <WorkoutSet>[];
      if (kept.timerSet case final setIndex?
          when setIndex >= 0 &&
              setIndex < sets.length &&
              !sets[setIndex].isDone) {
        _setTimer = SetTimer(sets[setIndex], kept.timerStartedAt!)
          ..pausedAt = kept.timerPausedAt;
        settleSetTimer();
      }
    }
  }

  /// Whether [set] of [exercise] in the running workout beats every
  /// earlier session of it.
  bool isPersonalRecord(ExerciseDefinition exercise, WorkoutSet set) {
    final workout = activeWorkout;
    return workout != null &&
        _backend.training.isPersonalRecord(workout, exercise, set);
  }

  /// Marks the next pending set of the current exercise as done.
  WorkoutSet? completeNextSet() {
    final workout = activeWorkout;
    if (workout == null) return null;
    final completed = _backend.training.completeNextSet(workout);
    if (completed != null) {
      _restEndedAt = null;
      notifyListeners();
    }
    return completed;
  }

  /// Logs the next set, from the workout page or the watch, and starts
  /// the rest after it unless the superset goes on to its next exercise.
  /// Null when there is no set left to log.
  ({WorkoutSet set, ExerciseDefinition exercise, bool rests})? logNextSet() {
    final workout = activeWorkout;
    if (workout == null) return null;
    final index = workout.currentExerciseIndex;
    final exercise = workout.currentExercise.exercise;
    final set = completeNextSet();
    if (set == null) return null;
    return (set: set, exercise: exercise, rests: restAfterSet(index));
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

  /// Warm-up sets for the current exercise, as many as it needs.
  List<WorkoutSet> addWarmups() {
    final workout = activeWorkout;
    if (workout == null) return const [];
    final sets = _backend.training.addWarmups(workout);
    notifyListeners();
    return sets;
  }

  void toggleSet(int setIndex) {
    final workout = activeWorkout;
    if (workout == null) return;
    _backend.training.toggleSet(workout, setIndex);
    _restEndedAt = null;
    notifyListeners();
  }

  void editSet(
    int setIndex, {
    required double weightKg,
    required int reps,
    required int? rir,
    int? seconds,
    double? meters,
  }) {
    final workout = activeWorkout;
    if (workout == null) return;
    final sets = workout.currentExercise.sets;
    final before = sets[setIndex];
    _backend.training.editSet(
      workout,
      setIndex,
      weightKg: weightKg,
      reps: reps,
      rir: rir,
      seconds: seconds,
      meters: meters,
    );
    // The set is a new object now; a timer running on it goes on.
    if (_setTimer case final timer? when identical(timer.set, before)) {
      timer.set = sets[setIndex];
    }
    notifyListeners();
  }

  /// Takes the set at [setIndex] off the exercise being done. Returns the
  /// way to put it back, until the workout ends.
  VoidCallback? removeSet(int setIndex) {
    final workout = activeWorkout;
    if (workout == null) return null;
    final removed = _backend.training.removeSet(workout, setIndex);
    notifyListeners();
    return () => _restoreSet(workout, removed);
  }

  void _restoreSet(WorkoutSession workout, RemovedSet removed) {
    if (activeWorkout != workout) return;
    _backend.training.restoreSet(workout, removed);
    notifyListeners();
  }

  /// Makes the exercise at [index] the one being done, so a set action
  /// that follows acts on it; nothing is written when it already is.
  void focusExercise(int index) {
    final workout = activeWorkout;
    if (workout == null || workout.currentExerciseIndex == index) return;
    _backend.training.selectExercise(workout, index);
  }

  /// Makes the working sets of the exercise at [index] follow the sets a
  /// scheme made; see `TrainingService.applySets` for which it touches.
  void applyScheme(int index, List<SetLoad> loads) =>
      _applySets(index, loads, 'apply_scheme');

  /// Makes the working sets of the exercise at [index] follow the sets of
  /// an earlier session.
  void loadSession(int index, List<SetLoad> loads) =>
      _applySets(index, loads, 'load_session');

  void _applySets(int index, List<SetLoad> loads, String action) {
    final workout = activeWorkout;
    if (workout == null) return;
    _backend.training.applySets(workout, index, loads, action: action);
    notifyListeners();
  }

  /// The sets done in each finished session of [exercise], newest first.
  List<ExerciseSessionRecord> sessionsOf(ExerciseDefinition exercise) =>
      _backend.training.sessionsOf(exercise);

  /// Takes the last set still to do off the exercise at [index]; returns
  /// the way to put it back, null when there was none.
  VoidCallback? removeLastSet(int index) {
    final workout = activeWorkout;
    if (workout == null) return null;
    final removed = _backend.training.removeLastSet(workout, index);
    if (removed == null) return null;
    notifyListeners();
    return () => _restoreSet(workout, removed);
  }

  /// Takes the exercise at [index] out of today's workout, keeping at
  /// least one; returns the way to put it back, null when it was kept.
  VoidCallback? removeExercise(int index) {
    final workout = activeWorkout;
    if (workout == null) return null;
    final removed = _backend.training.removeExercise(workout, index);
    if (removed == null) return null;
    notifyListeners();
    return () {
      if (activeWorkout != workout) return;
      _backend.training.restoreExercise(workout, removed);
      notifyListeners();
    };
  }

  void selectExercise(int index) {
    final workout = activeWorkout;
    if (workout == null) return;
    _backend.training.selectExercise(workout, index);
    notifyListeners();
  }

  /// Puts the exercise at [from] at [to], the place it ends up in.
  void moveExercise(int from, int to) {
    final workout = activeWorkout;
    if (workout == null) return;
    _backend.training.moveExercise(workout, from, to);
    notifyListeners();
  }

  /// Opens [routine] for editing and starting.
  void selectRoutine(Routine routine) {
    _routine = routine;
    notifyListeners();
  }

  /// Adds an empty template and opens it.
  Routine createRoutine([String? name]) {
    final created = _backend.training.createRoutine(
      name ?? _backend.l10n.routineUntitled,
    );
    selectRoutine(created);
    return created;
  }

  /// Removes [routine]. A template is not the history, which stays
  /// either way. When it was the one shown, the next one left is, if
  /// any.
  void deleteRoutine(Routine routine) {
    _backend.training.deleteRoutine(routine.id);
    if (routine.id == _routine?.id) _routine = routines.firstOrNull;
    notifyListeners();
  }

  /// Puts a removed template back and, when [select], trains from it
  /// again.
  void undeleteRoutine(String id, {bool select = true}) {
    _backend.training.undeleteRoutine(id);
    final restored = _backend.training.routine(id, _exercisesById);
    if (restored != null && select) selectRoutine(restored);
  }

  /// Adds [exercises] to the running workout, or to the template when no
  /// workout is running.
  void addExercises(List<ExerciseDefinition> exercises) {
    final workout = activeWorkout;
    if (workout != null) {
      _backend.training.addExercises(workout, exercises);
    } else {
      _routine = _backend.training.addToRoutine(_shown, exercises);
    }
    notifyListeners();
  }

  /// Plans the open template's exercise at [index] as [loads], set by
  /// set.
  void editLoads(int index, List<SetLoad> loads) {
    _routine = _backend.training.editLoads(_shown, index, loads);
    notifyListeners();
  }

  /// What [workout] did as a plan, to be looked over before it is kept
  /// as a template.
  List<PlannedExercise> planFromWorkout(WorkoutSession workout) =>
      _backend.training.planFrom(workout);

  /// Removes the exercise at [index] from the template.
  void removeRoutineExercise(int index) {
    _routine = _backend.training.removeFromRoutine(_shown, index);
    notifyListeners();
  }

  /// Moves an exercise within the template.
  /// Makes the planned exercise at [index] a superset with the next one,
  /// or ends that.
  void setJoinsNext(int index, {required bool joins}) {
    _routine = _backend.training.setJoinsNext(_shown, index, joins: joins);
    notifyListeners();
  }

  void moveRoutineExercise(int from, int to) {
    _routine = _backend.training.reorderRoutine(_shown, from, to);
    notifyListeners();
  }

  /// Puts a template back as it was, for undoing an edit.
  void restoreRoutine(Routine routine) {
    _routine = routine;
    _backend.training.saveRoutine(routine, action: 'restore');
    notifyListeners();
  }

  void renameRoutine(String name) {
    _routine = _backend.training.renameRoutine(_shown, name);
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
    final plan = id == _routine?.id
        ? _routine
        : _backend.training.routine(id, _exercisesById);
    if (plan == null) return;
    final updated = _backend.training.replaceInRoutine(
      plan,
      replacedId,
      replacement,
    );
    if (updated.id == _routine?.id) _routine = updated;
  }

  /// Pauses whatever is running, or picks it up again.
  /// Sets the ready workout under way: its time runs from here.
  void beginWorkout() {
    final workout = activeWorkout;
    if (workout == null) return;
    _backend.training.begin(workout);
    notifyListeners();
  }

  /// Corrects the time counted for the workout under way by [by].
  void adjustElapsed(Duration by) {
    final workout = activeWorkout;
    if (workout == null) return;
    _backend.training.adjustElapsed(workout, by);
    notifyListeners();
  }

  void togglePause() {
    switch (_session) {
      case ActiveWorkout(:final workout):
        _backend.training.togglePause(workout);
      case ActiveActivity(:final activity):
        _backend.activity.togglePause(activity);
      case ActiveBath() || null:
        return;
    }
    _restEndedAt = null;
    notifyListeners();
  }

  /// Abandons the running workout. Logged sets stay in the audit trail
  /// but the workout does not count as training done.
  void discardWorkout() {
    final workout = activeWorkout;
    if (workout == null) return;
    _backend.training.discard(workout);
    _heartRate = null;
    _heartRateAt = null;
    _session = null;
    _restEndsAt = null;
    _restEndedAt = null;
    _setTimer = null;
    notifyListeners();
  }

  /// Where a page opened from chrome that has no page of its own goes: a
  /// toast after a record was logged, whose screen has usually closed by
  /// the time it is tapped. [HomeShell] sets this while it is mounted, so
  /// such a page lands beside the selected tab's list when the window has
  /// two panes; with no shell mounted there is nowhere to open into.
  Future<void> Function(Widget page)? opensFromChrome;

  /// Opens [page] the way the dock opens one.
  void openFromChrome(Widget page) => opensFromChrome?.call(page);

  void finishWorkout() {
    final workout = activeWorkout;
    if (workout == null) return;
    _backend.training.finish(workout);
    _heartRate = null;
    _heartRateAt = null;
    _lastFinishedWorkout = workout;
    _session = null;
    _restEndsAt = null;
    _restEndedAt = null;
    if (_routine case final shown?) {
      _routine = _backend.training.routine(shown.id, _exercisesById);
    }
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

  /// The weekday a calendar's week starts on: the device's setting once
  /// read, Monday until then.
  int get firstWeekday => _firstWeekday;
  int _firstWeekday = DateTime.monday;

  /// Reads the day a week starts on from the device's settings.
  Future<void> refreshFirstWeekday() async {
    final day = await systemFirstWeekday();
    if (day == null || day == _firstWeekday) return;
    _firstWeekday = day;
    notifyListeners();
  }

  /// Uses Apple Intelligence without asking when it is on and no other
  /// provider was chosen.
  Future<void> refreshOnDeviceAi() async {
    await _ai.refreshOnDevice();
    notifyListeners();
  }

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

  /// Whether a merged meal is named by AI.
  bool get namesMerges => _ai.namesMerges;

  void setNamesMerges(bool isOn) {
    _ai.setNamesMerges(isOn);
    notifyListeners();
  }

  /// A name for a meal made of [itemNames], or null when none should be
  /// asked for or none came.
  Future<String?> nameMeal(
    List<String> itemNames, {
    required String language,
  }) => _ai.nameMeal(itemNames, language: language);

  /// The text in a photo, read on the device. Throws [AiException] when
  /// the device cannot read it.
  Future<String> readPhotoText(String imagePath) =>
      _ai.readPhotoText(imagePath);

  /// Whether the chosen AI can read a food photo.
  Future<bool> readsFoodPhotos() => _ai.readsPhotos();

  /// What a photo shows, as the chosen AI finds it: a nutrition label,
  /// or food with estimated figures; nothing is logged. Throws
  /// [AiException].
  Future<PhotoDraft> draftPhoto(String imagePath, {String note = ''}) =>
      _ai.draftPhoto(imagePath, note: note);

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

  LiveBath? get activeBath => switch (_session) {
    ActiveBath(:final bath) => bath,
    _ => null,
  };

  /// Starts a bath now. Refuses while another session is running, rather
  /// than quietly ending it.
  bool startBath({BathWater? water, BathKind? kind}) {
    if (_session != null) return false;
    _session = ActiveBath(_backend.journal.startBath(water: water, kind: kind));
    notifyListeners();
    return true;
  }

  /// Changes the water or kind of the running bath; null clears it.
  void chooseBath({required BathWater? water, required BathKind? kind}) {
    final bath = activeBath;
    if (bath == null) return;
    bath
      ..water = water
      ..kind = kind;
    _backend.journal.saveRunningBath(bath);
    notifyListeners();
  }

  /// Ends the running bath and keeps it as an entry.
  BathEntry? finishBath() {
    final bath = activeBath;
    if (bath == null) return null;
    final entry = _backend.journal.finishBath(bath);
    _session = null;
    notifyListeners();
    return entry;
  }

  /// Throws the running bath away without recording it.
  void discardBath() {
    if (activeBath == null) return;
    _backend.journal.discardBath();
    _session = null;
    notifyListeners();
  }

  /// The health platform on this device: Apple Health or Health Connect.
  String get healthSourceName => _health.source.nameIn(_backend.l10n);

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

  /// What the health platform recorded during [session], read now.
  Future<ActivityDetail?> activityDetail(ActivitySession session) =>
      _health.detailOf(session);

  /// Heart rate and respiratory rate through a sleep, from the platform.
  Future<Map<OvernightMeasure, List<(DateTime, double)>>> overnightSeries(
    DateTime from,
    DateTime to,
  ) => _health.overnightSeries(from, to);

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

  /// The sync run at launch and whenever the app comes back to the front,
  /// and the one pulling Today down asks for. Nobody is waiting on it, so
  /// a failure is kept for Today and 資料來源 to show rather than thrown
  /// into nowhere. One already running is joined, not started again: a
  /// first sync reads years back, and the app can come back to the front
  /// or be pulled down before it is done.
  Future<void> syncHealthInBackground() {
    if (_backgroundSync case final running?) return running;
    final sync = _syncInBackground();
    _backgroundSync = sync;
    if (isHealthConnected) {
      _slowRead = Timer(_slowReadAfter, () {
        _isHealthReadSlow = true;
        notifyListeners();
      });
    }
    return sync;
  }

  Future<void>? _backgroundSync;

  /// How long a read goes unseen: most finish within it, and a label that
  /// flashes up and away says nothing.
  static const _slowReadAfter = Duration(milliseconds: 1500);
  Timer? _slowRead;

  /// Whether the read under way has outlasted [_slowReadAfter], so Today
  /// says it is reading.
  bool get isHealthReadSlow => _isHealthReadSlow;
  bool _isHealthReadSlow = false;

  Future<void> _syncInBackground() async {
    try {
      await syncHealth();
      _healthSyncFailed = false;
    } on Exception {
      _healthSyncFailed = true;
    } finally {
      _backgroundSync = null;
      _slowRead?.cancel();
      _isHealthReadSlow = false;
    }
    notifyListeners();
  }

  void _reloadAfterImport() => notifyListeners();

  /// Writes to the platform what was logged since the last write, as the
  /// app leaves the front. A failure is kept like a failed sync's; what
  /// was not written goes the next time.
  Future<void> writeHealthInBackground() async {
    try {
      await _health.writeChanges();
    } on Exception {
      _healthSyncFailed = true;
      notifyListeners();
    }
  }

  /// Accepts the AI's routine proposal: it changes the template only, and
  /// the audit log records that the change came from an AI draft.
  void applyAiProposal() {
    final exercises = [
      for (final planned in _shown.exercises)
        switch (planned.exercise.id) {
          'back-squat' => planned.copyWith(sets: _aiProposalSquatSets),
          'leg-curl' => planned.copyWith(sets: _aiProposalLegCurlSets),
          _ => planned,
        },
    ];
    final updated = _shown.copyWith(exercises: exercises);
    _routine = updated;
    _backend.training.saveRoutine(
      updated,
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
