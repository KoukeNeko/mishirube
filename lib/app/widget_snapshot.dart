import '../backend/engines/caffeine.dart';
import '../backend/engines/nutrition_summary.dart';
import '../backend/engines/sleep_metrics.dart';
import '../domain/domain.dart';
import '../l10n/l10n.dart';
import '../shared/format.dart';
import 'app_store.dart';

/// Bumped when the snapshot's shape changes, so a widget built for an
/// older one (`ios/RestActivity/WidgetSnapshot.swift`) can tell.
const widgetSnapshotVersion = 1;

/// How many days of active days the widgets are given: a week in
/// progress and the one before, so a week turning over while the app is
/// closed is still drawn right.
const _activeDaysBack = 14;

/// Nights drawn on the sleep widget.
const _sleepNights = 7;

String _dayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

double _rounded(double value) => (value * 10).round() / 10;

/// Everything the home-screen widgets draw, as plain values the widget
/// extension reads from the shared container: figures it cannot work out
/// itself (targets, engines, the health platform's) and the words, which
/// come from the app's own strings so a widget says what the app says.
///
/// A widget is drawn later than this is written and may be drawn after
/// midnight with the app closed, so what depends on the day carries the
/// [day] it is for, and what moves with the clock (the caffeine curve) is
/// given whole for the widget to read at its own time.
Map<String, Object?> widgetSnapshot(AppStore store, AppLocalizations l10n) {
  final backend = store.backend;
  final now = store.now();
  final today = DateTime(now.year, now.month, now.day);
  final modules = store.enabledModules;

  final food = store.todaySummary;
  final targets = backend.nutrition.targetsOn(today);
  final water = summariseWater(backend.nutrition.mealsOn(today));
  final caffeine = backend.nutrition.caffeineNow();
  final goal = backend.goal.overview();
  final night = store.lastNight;
  final sleepGoal = backend.sleep.goal;
  final nights = backend.sleep.sleepDays(today, _sleepNights);
  final weight = store.weightSummary;
  final workout = backend.training.lastFinished();
  final activity = backend.activity.dayTotals(today);

  return {
    'version': widgetSnapshotVersion,
    'generatedAt': now.millisecondsSinceEpoch,
    'day': _dayKey(today),
    'modules': [for (final module in modules) module.name],
    'text': {
      'today': l10n.tabToday,
      'nutrition': l10n.moduleNutrition,
      'water': l10n.healthDataWater,
      'caffeine': l10n.nutrientCaffeine,
      'goal': l10n.weeklyGoal,
      'sleep': l10n.moduleSleep,
      'weight': l10n.moduleWeight,
      'training': l10n.moduleTraining,
      'activity': l10n.activityMetricSteps,
      'protein': l10n.macroProtein,
      'carb': l10n.macroCarb,
      'fat': l10n.macroFat,
      'remainingKcal': l10n.remainingKcalTitle,
      'empty': l10n.noEntriesShort,
    },
    'nutrition': {
      'kcal': food.kcal,
      'kcalTarget': targets.kcal,
      'meals': food.mealCount,
      'protein': food.proteinGrams,
      'proteinTarget': targets.proteinGrams,
      'carb': food.carbGrams,
      'carbTarget': targets.carbGrams,
      'fat': food.fatGrams,
      'fatTarget': targets.fatGrams,
    },
    'water': {
      'ml': water.millilitres,
      'reference': backend.nutrition.waterReferenceMl,
      'times': water.times,
      'timesText': water.times == 0
          ? null
          : l10n.timesCount(count: water.times),
      'lastTime': water.lastTimeLabel,
    },
    'caffeine': caffeine == null
        ? null
        : {
            'start': caffeine.curve.first.$1.millisecondsSinceEpoch,
            'stepMinutes': caffeine.curve[1].$1
                .difference(caffeine.curve.first.$1)
                .inMinutes,
            'values': [for (final (_, mg) in caffeine.curve) _rounded(mg)],
            'reference': caffeineBedtimeReferenceMg,
            'referenceText': l10n.caffeineReference(
              mg: formatAmount(caffeineBedtimeReferenceMg),
            ),
          },
    'goal': {
      'enabled': goal.isEnabled && goal.hasGoal,
      'target': goal.hasGoal ? goal.thisWeek.targetDays : null,
      'activeDays': [
        for (final day in goal.activeDays)
          if (!day.isBefore(
            DateTime(today.year, today.month, today.day - _activeDaysBack),
          ))
            _dayKey(day),
      ],
      'streak': goal.streak.current,
      'streakText': goal.streak.hasRun
          ? l10n.streakWeeks(count: goal.streak.current)
          : null,
      'isPaused': goal.isPaused,
    },
    'sleep': {
      'asleepMinutes': night?.entry.duration.inMinutes,
      'wokeAt': night?.entry.sleptAt.millisecondsSinceEpoch,
      'asleepText': night == null
          ? null
          : formatHoursMinutes(night.entry.duration),
      'goalMinutes': sleepGoal?.inMinutes,
      'goalText': sleepGoal == null
          ? null
          : l10n.goalValue(goal: formatHoursMinutes(sleepGoal)),
      'nights': [
        for (final SleepDay(:day, :slept) in nights)
          {'day': _dayKey(day), 'minutes': slept?.inMinutes},
      ],
      'shortMinutes': shortfallOf(nights, backend.sleep.need).short.inMinutes,
    },
    'weight': {
      'kg': weight.latest?.weightKg,
      'measuredAt': weight.latest?.measuredAt.millisecondsSinceEpoch,
      'changeText': switch (weight.weekChange) {
        final change? => l10n.weightChange7Days(
          change:
              '${change < 0 ? '−' : '+'}'
              '${formatWeight((change.abs() * 10).round() / 10)}',
        ),
        null => null,
      },
      'trend': [
        for (final (at, reading, trend) in weight.week)
          {
            'at': at.millisecondsSinceEpoch,
            'weight': _rounded(reading),
            'trend': _rounded(trend),
          },
      ],
    },
    'training': workout == null
        ? null
        : {
            'name': workout.routineName,
            'at': workout.startedAt.millisecondsSinceEpoch,
            'detail': l10n.setsAndMinutes(
              sets: workout.completedSets,
              minutes: workout.elapsedAt(workout.finishedAt ?? now).inMinutes,
            ),
          },
    'activity': {
      'steps': activity[ActivityMetric.steps],
      'activeKcal': activity[ActivityMetric.activeEnergy],
    },
  };
}
