import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/engines/food_portion.dart';
import 'package:mishirube/backend/seed/demo_content.dart';
import 'package:mishirube/features/activity/activity_detail_screen.dart';
import 'package:mishirube/features/activity/activity_type_picker.dart';
import 'package:mishirube/features/activity/live_activity_screen.dart';
import 'package:mishirube/features/activity/record_activity_screen.dart';
import 'package:mishirube/features/exercise/create_exercise_screen.dart';
import 'package:mishirube/features/goal/goal_screen.dart';
import 'package:mishirube/features/goal/goal_setup_sheet.dart';
import 'package:mishirube/features/exercise/exercise_detail_screen.dart';
import 'package:mishirube/backend/storage/database.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/exercise/exercise_filter_screen.dart';
import 'package:mishirube/features/exercise/exercise_picker_screen.dart';
import 'package:mishirube/features/me/ai_proposal_screen.dart';
import 'package:mishirube/features/body/body_screen.dart';
import 'package:mishirube/features/today/today_layout_screen.dart';
import 'package:mishirube/features/journal/body_reading_entry_screen.dart';
import 'package:mishirube/features/journal/weight_entry_screen.dart';
import 'package:mishirube/features/journal/journal_detail_screen.dart';
import 'package:mishirube/features/me/ai_settings_screen.dart';
import 'package:mishirube/features/me/data_sources_screen.dart';
import 'package:mishirube/features/me/privacy_screen.dart';
import 'package:mishirube/features/me/export_screen.dart';
import 'package:mishirube/features/nutrition/brand_menu_screen.dart';
import 'package:mishirube/features/nutrition/daily_nutrition_screen.dart';
import 'package:mishirube/features/nutrition/describe_meal_screen.dart';
import 'package:mishirube/features/nutrition/food_library_screen.dart';
import 'package:mishirube/features/nutrition/camera_screen.dart';
import 'package:mishirube/features/nutrition/food_edit_screen.dart';
import 'package:mishirube/features/nutrition/food_search_screen.dart';
import 'package:mishirube/features/nutrition/plate_screen.dart';
import 'package:mishirube/features/nutrition/portion_screen.dart';
import 'package:mishirube/features/nutrition/meal_edit_screen.dart';
import 'package:mishirube/features/onboarding/onboarding_screen.dart';
import 'package:mishirube/features/shell/home_shell.dart';
import 'package:mishirube/features/training/active_workout_screen.dart';
import 'package:mishirube/features/journal/measurement_entry_screen.dart';
import 'package:mishirube/features/journal/sleep_entry_screen.dart';
import 'package:mishirube/features/journal/wellness_entry_screen.dart';
import 'package:mishirube/features/training/rest_timer_screen.dart';
import 'package:mishirube/features/training/routine_detail_screen.dart';
import 'package:mishirube/features/training/routine_list_screen.dart';
import 'package:mishirube/features/training/substitute_exercise_screen.dart';
import 'package:mishirube/features/training/workout_summary_screen.dart';
import 'package:mishirube/features/sleep/sleep_screen.dart';
import 'package:mishirube/features/activity/activity_metric_screen.dart';
import 'package:mishirube/features/activity/daily_activity_screen.dart';
import 'package:mishirube/features/trends/exercise_trends_screen.dart';
import 'package:mishirube/features/trends/insight_detail_screen.dart';
import 'package:mishirube/features/trends/muscle_trends_screen.dart';
import 'package:mishirube/features/trends/personal_records_screen.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

import 'support/harness.dart';

/// Each case builds a store in the state the screen needs.
typedef _StoreSetup = void Function(AppStore store);

void _noSetup(AppStore store) {}

/// A month of what a phone and a watch counted: steps, distance and
/// energy through the waking hours, a resting heart rate each morning,
/// and a VO₂ max now and then.
void _withMovement(AppStore store) {
  final today = store.now();
  store.backend.storage.activitySamples.sync(
    [
      for (var daysAgo = 30; daysAgo >= 0; daysAgo--)
        for (var hour = 7; hour <= 21; hour++)
          for (final (metric, value) in [
            (ActivityMetric.steps, 300.0 + hour * 40 + daysAgo * 7),
            (ActivityMetric.distance, 220.0 + hour * 25),
            (ActivityMetric.activeEnergy, 18.0 + hour),
          ])
            ActivitySample(
              metric: metric,
              start: DateTime(
                today.year,
                today.month,
                today.day - daysAgo,
                hour,
              ),
              end: DateTime(
                today.year,
                today.month,
                today.day - daysAgo,
                hour + 1,
              ),
              value: value,
            ),
      for (var daysAgo = 30; daysAgo >= 0; daysAgo--)
        ActivitySample(
          metric: ActivityMetric.restingHeartRate,
          start: DateTime(today.year, today.month, today.day - daysAgo),
          end: DateTime(today.year, today.month, today.day - daysAgo + 1),
          value: 58.0 + daysAgo % 5,
        ),
      for (var daysAgo = 28; daysAgo >= 0; daysAgo -= 7)
        ActivitySample(
          metric: ActivityMetric.vo2Max,
          start: DateTime(today.year, today.month, today.day - daysAgo),
          end: DateTime(today.year, today.month, today.day - daysAgo + 1),
          value: 44.5 - daysAgo / 28,
        ),
    ],
    idPrefix: 'healthkit',
    source: ChangeSource.healthKit,
  );
}

void _withWorkout(AppStore store) => store.startWorkout();

void _resting(AppStore store) {
  store
    ..startWorkout()
    ..completeNextSet()
    ..startRest(store.activeWorkout!.currentExercise.exercise);
}

/// Last night from a watch, with stages, overnight readings, a second
/// source and a nap, so the sleep page draws every section.
void _withStagedNight(AppStore store) {
  final journal = store.backend.storage.journal;
  final woke = store.now().subtract(const Duration(hours: 1));
  final start = woke.subtract(const Duration(hours: 8));
  SleepSample stretch(SleepStage stage, int from, int to, String source) =>
      SleepSample(
        start: start.add(Duration(minutes: from)),
        end: start.add(Duration(minutes: to)),
        stage: stage,
        source: source,
        sourceName: source == 'watch' ? 'Apple Watch' : 'Oura',
      );
  journal.addSleep(
    SleepEntry(
      id: 'night',
      sleptAt: woke,
      duration: const Duration(hours: 8),
      startedAt: start,
      sourceName: 'Apple Watch',
    ),
    source: ChangeSource.healthKit,
  );
  journal.replaceSleepSegments('night', [
    stretch(SleepStage.core, 0, 120, 'watch'),
    stretch(SleepStage.deep, 120, 200, 'watch'),
    stretch(SleepStage.awake, 200, 210, 'watch'),
    stretch(SleepStage.rem, 210, 480, 'watch'),
    stretch(SleepStage.asleep, 5, 470, 'ring'),
  ], source: ChangeSource.healthKit);
  journal.replaceSleepReadings('night', const [
    OvernightReading(
      measure: OvernightMeasure.heartRate,
      minimum: 52,
      maximum: 67,
      average: 58,
      count: 100,
    ),
    OvernightReading(
      measure: OvernightMeasure.skinTemperatureChange,
      minimum: -0.2,
      maximum: 0.3,
      average: 0.1,
      count: 20,
    ),
    OvernightReading(
      measure: OvernightMeasure.breathingDisturbances,
      minimum: 3,
      maximum: 3,
      average: 3,
      count: 1,
      isElevated: false,
    ),
  ], source: ChangeSource.healthKit);
  journal.addSleep(
    SleepEntry(
      id: 'nap',
      sleptAt: woke.subtract(const Duration(minutes: 1)),
      duration: const Duration(minutes: 30),
      startedAt: woke.subtract(const Duration(minutes: 31)),
      kind: SleepKind.nap,
      sourceName: 'Apple Watch',
    ),
    source: ChangeSource.healthKit,
  );
}

void _withLunch(AppStore store) => store.confirmLunch();

/// The states Today has to hold up in: as seeded, with the day's records,
/// after a workout, and with one running.
final _todayStates = <(String, _StoreSetup)>[
  ('as seeded', _noSetup),
  ('with records', (store) {
    _withLunch(store);
    _withBody(store);
    _withStagedNight(store);
    _withMovement(store);
  }),
  ('after a workout', (store) {
    store
      ..startWorkout()
      ..completeNextSet()
      ..finishWorkout();
  }),
  ('during a workout', _withWorkout),
];

/// Weighings over a month, height, a scale's reading and a waist.
void _withBody(AppStore store) {
  final journal = store.backend.journal;
  for (var day = 30; day >= 0; day -= 2) {
    journal.recordWeight(
      72 - day / 30,
      at: store.now().subtract(Duration(days: day)),
    );
  }
  journal
    ..recordBodyReadings({
      BodyMetric.height: 175,
      BodyMetric.bodyFat: 18.2,
      BodyMetric.skeletalMuscle: 33.1,
      BodyMetric.leanMass: 58,
    })
    ..recordMeasurement(MeasurementSite.waist, 82)
    ..recordMeasurement(MeasurementSite.hips, 96);
}

void _withFood(AppStore store) => store.backend.nutrition.saveFood(
  FoodItem(
    id: store.backend.nutrition.newFoodId(),
    name: '雞胸肉',
    brand: '大成',
    servingLabel: '一片',
    servingAmount: 100,
    servingUnit: ServingUnit.gram,
    kcal: 165,
    proteinGrams: 31,
    carbGrams: 0,
    fatGrams: 4,
  ),
);

void _withoutRoutines(AppStore store) {
  for (final routine in store.routines) {
    store.deleteRoutine(routine);
  }
}

void _withGoal(AppStore store) =>
    store.backend.goal.setGoal(3, applyThisWeek: true);

void _withActivity(AppStore store) => store.backend.activity.log(
  type: ActivityTypes.running,
  startedAt: store.now().subtract(const Duration(minutes: 30)),
  duration: const Duration(minutes: 30),
  distanceMeters: 5000,
  effort: 6,
  note: '河濱，風很大',
);

final _screens = <String, (Widget Function(AppStore), _StoreSetup)>{
  'onboarding': ((_) => const OnboardingScreen(), _noSetup),
  'weight entry': ((_) => const WeightEntryScreen(), _noSetup),
  'sleep entry': ((_) => const SleepEntryScreen(), _noSetup),
  'measurement entry': ((_) => const MeasurementEntryScreen(), _noSetup),
  'data sources': ((_) => const DataSourcesScreen(), _noSetup),
  'ai settings': ((_) => const AiSettingsScreen(), _noSetup),
  'food library': ((_) => const FoodLibraryScreen(), _noSetup),
  'privacy': ((_) => const PrivacyScreen(), _noSetup),
  'sleep': ((_) => const SleepScreen(), _withStagedNight),
  'activity': (
    (_) => const DailyActivityScreen(),
    (store) {
      _withMovement(store);
      _withActivity(store);
    },
  ),
  'activity, nothing recorded': ((_) => const DailyActivityScreen(), _noSetup),
  'activity metric, counted': (
    (store) =>
        ActivityMetricScreen(metric: ActivityMetric.steps, day: store.now()),
    _withMovement,
  ),
  'activity metric, measured': (
    (store) =>
        ActivityMetricScreen(metric: ActivityMetric.vo2Max, day: store.now()),
    _withMovement,
  ),
  'sleep, nothing recorded': (
    (store) =>
        SleepScreen(day: store.now().subtract(const Duration(days: 400))),
    _noSetup,
  ),
  'describe a meal': ((_) => const DescribeMealScreen(), _noSetup),
  'photo estimate': (
    (_) => const DescribeMealScreen(
      draft: MealDraft(
        items: [
          DraftItem(name: '白飯', amount: '約 180 g（150–220 g）', kcal: 250),
          DraftItem(name: '滷雞腿', amount: '約 120 g', kcal: 300),
        ],
        provider: AiProviderKind.anthropic,
        model: 'claude',
        warnings: ['滷汁的油量看不出來'],
      ),
    ),
    _noSetup,
  ),
  'brand menu': (
    (_) => BrandMenuScreen(
      brand: '星巴克',
      rowFor: (food, _) => Text(food.name),
      footer: () => null,
      plateChanges: ValueNotifier(0),
    ),
    _noSetup,
  ),
  'plate': (
    (_) => PlateScreen(
      plate: [
        FoodPortion(const FoodItem(id: 'rice', name: '白飯', kcal: 130), 1.5),
        FoodPortion(const FoodItem(id: 'egg', name: '蛋'), 2),
      ],
      onChanged: () {},
      onLog: () {},
    ),
    _noSetup,
  ),
  'weight detail': (
    (store) {
      final weight = store.backend.journal
          .recentWeights(const Duration(days: 28))
          .last;
      return JournalDetailScreen(id: weight.id, at: weight.measuredAt);
    },
    _noSetup,
  ),
  'wellness entry': ((_) => const WellnessEntryScreen(), _noSetup),
  'shell / today morning': ((_) => const HomeShell(), _noSetup),
  'shell / today in workout': ((_) => const HomeShell(), _withWorkout),
  'routine detail': ((_) => const RoutineDetailScreen(), _noSetup),
  'routine list': ((_) => const RoutineListScreen(), _noSetup),
  'routine list (none)': ((_) => const RoutineListScreen(), _withoutRoutines),
  'goal (not set up)': ((_) => const GoalScreen(), _noSetup),
  'goal': ((_) => const GoalScreen(), _withGoal),
  'goal setup': (
    (store) => GoalSetupScreen(overview: store.backend.goal.overview()),
    _withGoal,
  ),
  'active workout': ((_) => const ActiveWorkoutScreen(), _withWorkout),
  'active workout (resting)': ((_) => const ActiveWorkoutScreen(), _resting),
  'rest timer': (
    (store) => RestTimerScreen(
      exerciseName: '槓鈴深蹲',
      completedSet: store.activeWorkout!.currentExercise.sets.first,
      isPersonalRecord: true,
    ),
    _resting,
  ),
  'personal records': ((_) => const PersonalRecordsScreen(), _noSetup),
  'muscle trends': ((_) => const MuscleTrendsScreen(), _noSetup),
  'exercise trends': ((_) => const ExerciseTrendsScreen(), _noSetup),
  'workout summary (sample)': ((_) => const WorkoutSummaryScreen(), _noSetup),
  'substitute exercise': (
    (_) => const SubstituteExerciseScreen(),
    _withWorkout,
  ),
  'exercise picker': (
    (_) => const ExercisePickerScreen(
      targetName: '下肢 A',
      purpose: PickerPurpose.template,
    ),
    _noSetup,
  ),
  'exercise browse': (
    (_) => const ExercisePickerScreen(purpose: PickerPurpose.browse),
    _noSetup,
  ),
  'exercise filter': (
    (_) => const ExerciseFilterScreen(
      initial: ExerciseFilter(
        muscles: {MuscleGroup.quads, MuscleGroup.glutes},
        equipment: {Equipment.barbell},
      ),
    ),
    _noSetup,
  ),
  'exercise detail': (
    (_) => const ExerciseDetailScreen(
      exercise: DemoExercises.backSquat,
      canAdd: true,
    ),
    _noSetup,
  ),
  'create exercise': (
    (_) => const CreateExerciseScreen(initialName: '啞鈴臥推'),
    _noSetup,
  ),
  'record activity': ((_) => const RecordActivityScreen(), _noSetup),
  'edit activity': (
    (store) =>
        RecordActivityScreen(activity: store.activitiesOn(store.now()).last),
    _withActivity,
  ),
  'live activity': (
    (_) => const LiveActivityScreen(),
    (store) => store.startActivity(ActivityTypes.running),
  ),
  'activity detail': (
    (store) => ActivityDetailScreen(
      activityId: store.activitiesOn(store.now()).last.id,
    ),
    _withActivity,
  ),
  'activity type picker': ((_) => const ActivityTypePicker(), _noSetup),
  'daily nutrition': ((_) => const DailyNutritionScreen(), _withLunch),
  'daily nutrition (a day with nothing)': (
    (store) => DailyNutritionScreen(
      day: store.now().subtract(const Duration(days: 400)),
    ),
    _noSetup,
  ),
  'meal edit': (
    (store) => MealEditScreen(meal: store.todayMeals.last),
    _withLunch,
  ),
  'food search (empty)': ((_) => const FoodSearchScreen(), _noSetup),
  'food search': ((_) => const FoodSearchScreen(), _withFood),
  'quick record': ((_) => const FoodEditScreen(logsOnce: true), _noSetup),
  'camera': (
    (_) => CameraScreen(
      title: '食物',
      pickFromLibrary: () async => null,
      findCameras: () async => const [],
    ),
    _noSetup,
  ),
  'food edit (new)': ((_) => const FoodEditScreen(), _noSetup),
  'portion': (
    (store) =>
        PortionScreen(food: store.backend.nutrition.searchFoods('').single),
    _withFood,
  ),
  'food edit': (
    (store) =>
        FoodEditScreen(editing: store.backend.nutrition.searchFoods('').single),
    _withFood,
  ),
  'insight detail': ((_) => const InsightDetailScreen(), _noSetup),
  'body': ((_) => const BodyScreen(), _noSetup),
  'today layout': ((_) => const TodayLayoutScreen(), _noSetup),
  'body, measured': ((_) => const BodyScreen(), _withBody),
  'body reading entry': ((_) => const BodyReadingEntryScreen(), _noSetup),
  'ai proposal': ((_) => const AiProposalScreen(), _noSetup),
  'export': ((_) => const ExportScreen(), _noSetup),
};

/// Pages that intentionally skip the shared app bar.
const _screensWithoutAppBar = {
  // Full-screen countdown; any chrome would compete with the timer.
  'rest timer',
  // A viewfinder: a header over the preview would cover what is framed.
  'camera',
};

/// Every screen at each window it must survive; the phone's cases keep
/// their plain names.
const _windows = [phone, phoneLandscape, tablet];

String _named(String name, WindowCase window) =>
    window == phone ? name : '$name ($window)';

void main() {
  for (final window in _windows) {
    for (final MapEntry(key: name, value: (build, setup)) in _screens.entries) {
      testWidgets(_named('$name renders without layout errors', window), (
        tester,
      ) async {
        final store = AppStore(clock: FakeClock().now, isOnboarded: true);
        setup(store);

        await pumpScreen(tester, build(store), store: store, window: window);

        expect(tester.takeException(), isNull);
        if (!_screensWithoutAppBar.contains(name)) {
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is SliverPersistentHeader &&
                  widget.delegate is CollapsingHeaderDelegate,
            ),
            findsWidgets,
            reason: '$name uses the shared app bar',
          );
        }
        await disposeTree(tester);
      });
    }
  }

  for (final window in _windows) {
    for (final (state, setUp) in _todayStates) {
      testWidgets(_named('today $state renders every tab', window), (
        tester,
      ) async {
        final store = AppStore(clock: FakeClock().now, isOnboarded: true);
        setUp(store);
        await pumpScreen(
          tester,
          const HomeShell(),
          store: store,
          window: window,
        );

        for (final tab in HomeTab.values) {
          store.selectTab(tab);
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'tab $tab');
        }
        await disposeTree(tester);
      });
    }
  }
}
