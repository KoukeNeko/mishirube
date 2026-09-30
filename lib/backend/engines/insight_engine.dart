import '../../domain/domain.dart';
import '../../l10n/app_localizations.dart';
import 'trend_engine.dart';

/// Bumped whenever a rule below changes, so an insight can say which
/// version produced it.
const insightEngineVersion = 2;

/// Weekly weight changes smaller than this are noise, not a trend.
const steadyWeightKgPerWeek = 0.1;

/// A drop in weekly sets worth mentioning.
const _meaningfulVolumeDrop = 0.2;

/// Days of the window that must hold a measurement for the data to count
/// as complete.
const _completeShare = 0.8;

/// Insights are deterministic: same records in, same wording out, and
/// nothing is stated that the records cannot support. When there is too
/// little data the engine returns null rather than guessing.
///
/// Every insight carries its evidence: what it was computed from, how
/// complete that data is, and the window it covers.

/// Where the weight is heading over [trend]'s window.
Insight? weightTrendInsight(
  AppLocalizations l10n,
  MeasurementTrend trend, {
  required int dayCount,
}) {
  final perWeek = trend.changePerWeek;
  if (perWeek == null) return null;
  final size = perWeek.abs();
  final statement = size < steadyWeightKgPerWeek
      ? l10n.weightSteady
      : (perWeek < 0 ? l10n.weightFalling : l10n.weightRising)(
          kg: size.toStringAsFixed(1),
        );
  return Insight(
    statement: statement,
    evidence: [
      l10n.basedOnWeights(count: trend.values.length),
      ..._quality(l10n, trend.values.length, dayCount),
      _window(l10n, trend.days),
    ],
  );
}

/// Whether this week has already met [goalPerWeek] training sessions.
Insight? weeklyTrainingInsight(
  AppLocalizations l10n,
  List<WeeklyBar> weeks, {
  required int goalPerWeek,
}) {
  if (weeks.isEmpty) return null;
  final (_, thisWeek) = weeks.last;
  if (thisWeek == 0) return null;
  final statement = thisWeek >= goalPerWeek
      ? l10n.trainingGoalMet(count: thisWeek, goal: goalPerWeek)
      : l10n.trainingGoalShort(
          count: thisWeek,
          goal: goalPerWeek,
          left: goalPerWeek - thisWeek,
        );
  return Insight(
    statement: statement,
    evidence: [
      l10n.basedOnThisWeek,
      l10n.weeklyGoalTimes(goal: goalPerWeek),
    ],
  );
}

/// A drop in weekly working sets for one exercise, and whether the
/// estimated max followed it down: the first week against the last one
/// that has finished, since the week in progress is not a week's worth
/// yet.
Insight? volumeTrendInsight(
  AppLocalizations l10n,
  String exerciseName,
  List<WeeklyBar> weeklySets, {
  required int sessionCount,
  required bool isMaxHolding,
}) {
  if (weeklySets.length < 3 || sessionCount == 0) return null;
  final first = weeklySets.first.$2;
  final last = weeklySets[weeklySets.length - 2].$2;
  if (first == 0 || last >= first * (1 - _meaningfulVolumeDrop)) return null;
  return Insight(
    statement:
        (isMaxHolding ? l10n.volumeDropMaxHolding : l10n.volumeDropMaxFalling)(
          exercise: exerciseName,
          first: first,
          last: last,
        ),
    evidence: [
      l10n.basedOnWorkouts(count: sessionCount),
      l10n.excludesWarmups,
      _window(l10n, weeklySets.length * DateTime.daysPerWeek),
    ],
  );
}

List<String> _quality(AppLocalizations l10n, int points, int dayCount) => [
  if (dayCount > 0 && points >= dayCount * _completeShare)
    l10n.dataComplete
  else
    l10n.dataIncomplete(points: points, days: dayCount),
];

String _window(AppLocalizations l10n, int days) =>
    days % DateTime.daysPerWeek == 0 && days <= 56
    ? l10n.lastWeeksCount(count: days ~/ DateTime.daysPerWeek)
    : l10n.lastDaysCount(count: days);
