import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/seed/demo_content.dart';
import 'package:mishirube/features/activity/activity_detail_screen.dart';
import 'package:mishirube/features/activity/activity_type_picker.dart';
import 'package:mishirube/features/activity/record_activity_screen.dart';
import 'package:mishirube/features/exercise/create_exercise_screen.dart';
import 'package:mishirube/features/exercise/exercise_detail_screen.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/exercise/exercise_filter_screen.dart';
import 'package:mishirube/features/exercise/exercise_picker_screen.dart';
import 'package:mishirube/features/me/ai_permissions_screen.dart';
import 'package:mishirube/features/me/ai_proposal_screen.dart';
import 'package:mishirube/features/me/import_screen.dart';
import 'package:mishirube/features/me/sync_screen.dart';
import 'package:mishirube/features/nutrition/daily_nutrition_screen.dart';
import 'package:mishirube/features/nutrition/meal_confirm_screen.dart';
import 'package:mishirube/features/nutrition/meal_entry_screen.dart';
import 'package:mishirube/features/onboarding/onboarding_screen.dart';
import 'package:mishirube/features/shell/home_shell.dart';
import 'package:mishirube/features/training/active_workout_screen.dart';
import 'package:mishirube/features/journal/sleep_entry_screen.dart';
import 'package:mishirube/features/journal/weight_entry_screen.dart';
import 'package:mishirube/features/journal/wellness_entry_screen.dart';
import 'package:mishirube/features/training/rest_timer_screen.dart';
import 'package:mishirube/features/training/routine_detail_screen.dart';
import 'package:mishirube/features/training/substitute_exercise_screen.dart';
import 'package:mishirube/features/training/workout_summary_screen.dart';
import 'package:mishirube/features/trends/insight_detail_screen.dart';
import 'package:mishirube/features/trends/trends_empty_screen.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

import 'support/harness.dart';

/// Each case builds a store in the state the screen needs.
typedef _StoreSetup = void Function(AppStore store);

void _noSetup(AppStore store) {}

void _withWorkout(AppStore store) => store.startWorkout();

void _withLunch(AppStore store) => store.confirmLunch();

void _withActivity(AppStore store) => store.logActivity(
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
  'wellness entry': ((_) => const WellnessEntryScreen(), _noSetup),
  'shell / today morning': ((_) => const HomeShell(), _noSetup),
  'shell / today in workout': ((_) => const HomeShell(), _withWorkout),
  'routine detail': ((_) => const RoutineDetailScreen(), _noSetup),
  'active workout': ((_) => const ActiveWorkoutScreen(), _withWorkout),
  'rest timer': (
    (store) => RestTimerScreen(
      exerciseName: '槓鈴深蹲',
      completedSet: store.activeWorkout!.currentExercise.sets.first,
      isPersonalRecord: true,
    ),
    _withWorkout,
  ),
  'workout summary (sample)': ((_) => const WorkoutSummaryScreen(), _noSetup),
  'substitute exercise': (
    (_) => const SubstituteExerciseScreen(),
    _withWorkout,
  ),
  'exercise picker': (
    (_) => const ExercisePickerScreen(targetName: '下肢 A'),
    _noSetup,
  ),
  'exercise filter': (
    (_) =>
        const ExerciseFilterScreen(initial: ExerciseFilter.defaultForLowerBody),
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
  'activity detail': (
    (store) => ActivityDetailScreen(
      activityId: store.activitiesOn(store.now()).last.id,
    ),
    _withActivity,
  ),
  'activity type picker': ((_) => const ActivityTypePicker(), _noSetup),
  'meal entry': ((_) => const MealEntryScreen(), _noSetup),
  'meal confirm': ((_) => const MealConfirmScreen(), _noSetup),
  'daily nutrition': ((_) => const DailyNutritionScreen(), _withLunch),
  'insight detail': ((_) => const InsightDetailScreen(), _noSetup),
  'trends empty': ((_) => const TrendsEmptyScreen(), _noSetup),
  'ai permissions': ((_) => const AiPermissionsScreen(), _noSetup),
  'ai proposal': ((_) => const AiProposalScreen(), _noSetup),
  'import': ((_) => const ImportScreen(), _noSetup),
  'sync': ((_) => const SyncScreen(), _noSetup),
};

/// Pages that intentionally skip the shared app bar.
const _screensWithoutAppBar = {
  // Full-screen countdown; any chrome would compete with the timer.
  'rest timer',
};

void main() {
  for (final MapEntry(key: name, value: (build, setup)) in _screens.entries) {
    testWidgets('$name renders without layout errors', (tester) async {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true);
      setup(store);

      await pumpScreen(tester, build(store), store: store);

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

  for (final phase in DayPhase.values) {
    testWidgets('today in $phase renders every tab', (tester) async {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true);
      while (store.phase != phase) {
        store.cyclePhase();
      }
      await pumpScreen(tester, const HomeShell(), store: store);

      for (final tab in HomeTab.values) {
        store.selectTab(tab);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'tab $tab');
      }
      await disposeTree(tester);
    });
  }
}
