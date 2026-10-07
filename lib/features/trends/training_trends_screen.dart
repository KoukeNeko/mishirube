import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../backend/application/activity_service.dart';
import '../../backend/application/insights_service.dart';
import '../../backend/engines/trend_engine.dart';
import '../../backend/engines/workout_review.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../exercise/exercise_detail_screen.dart';
import 'insight_detail_screen.dart';
import 'muscle_load_card.dart';
import 'trends_view_model.dart';
import '../../l10n/l10n.dart';

/// Weeks before this one that a muscle's usual range is read from.
const _usualWeeks = 4;

enum _TrendRange {
  // Whole weeks, so a week's figures are not thinned by a part week.
  month(Duration(days: 28)),
  threeMonths(Duration(days: 91)),
  all(null);

  const _TrendRange(this.window);

  /// Null for everything since the first record.
  final Duration? window;

  String labelIn(AppLocalizations l10n) => switch (this) {
    month => l10n.chartRangeMonth,
    threeMonths => l10n.monthsCount(count: 3),
    all => l10n.logFilterAll,
  };
}

/// Training over a chosen range: how often, what was worked, and each
/// exercise's progress and best. The muscles' weeks and the exercises are
/// here in full, not a tap away.
class TrainingTrendsScreen extends StatefulWidget {
  const TrainingTrendsScreen({super.key});

  @override
  State<TrainingTrendsScreen> createState() => _TrainingTrendsScreenState();
}

class _TrainingTrendsScreenState extends State<TrainingTrendsScreen> {
  _TrendRange _range = _TrendRange.month;
  late final _model = TrendsViewModel(AppStoreScope.read(context).backend);

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: _model, builder: (context, _) => _page());

  Widget _page() {
    final window = _range.window ?? _model.trainingSpan;
    final overview = _model.overview(window);
    final volume = _model.volumeReport(window: window);
    final activity = _model.activity(window);
    final muscles = _model.muscleWeeks();
    final exercises = _model.exerciseHistories();
    final records = {
      for (final bests in _model.personalRecords()) bests.exercise.id: bests,
    };
    return DetailPage(
      appBar: PageAppBar(
        title: context.l10n.trainingAnalysis,
        subtitle: context.dates.span(overview.from, overview.to),
      ),
      children: [
        Gutter(
          child: SegmentedChoice(
            options: _TrendRange.values,
            selected: _range,
            labelOf: (range) => range.labelIn(context.l10n),
            onChanged: (range) => setState(() => _range = range),
          ),
        ),
        if (volume?.insight case final insight?)
          Gutter(
            child: InsightCard(
              insight: insight,
              onTap: () => pushPage(
                context,
                InsightDetailScreen(exerciseId: volume?.exercise.id),
              ),
            ),
          ),
        Gutter(
          child: _SummaryGrid(overview: overview, activity: activity),
        ),
        if (_model.trainingTotals(window) case final totals
            when totals.workouts > 0) ...[
          Gutter(child: SectionLabel(context.l10n.statsSection)),
          Gutter(child: FigureGrid(figures: _totalFigures(context, totals))),
        ],
        Gutter(child: SectionLabel(context.l10n.musclesTitle)),
        Gutter(
          child: MuscleLoadCard(
            load: _model.muscleLoad(window),
            figure: _model.muscleFigure,
          ),
        ),
        // A week of no sets at all says nothing yet: the weeks need a
        // muscle that has been trained in them.
        if (muscles.any((muscle) => muscle.$2.any((week) => week.$2 > 0))) ...[
          Gutter(child: SectionLabel(context.l10n.weeklySetsLast8)),
          for (final (muscle, weeks) in muscles)
            Gutter(
              child: _MuscleCard(muscle: muscle, weeks: weeks),
            ),
        ],
        Gutter(child: SectionLabel(context.l10n.exercisesLabel)),
        Gutter(
          child: AccentRow(
            color: AppColors.training,
            title: context.l10n.volumeTitle,
            showChevron: true,
            onTap: () => pushPage(
              context,
              InsightDetailScreen(exerciseId: volume?.exercise.id),
            ),
          ),
        ),
        if (exercises.isEmpty)
          Gutter(
            child: EmptyStateCard(
              icon: Icons.fitness_center,
              title: context.l10n.noEntriesShort,
            ),
          )
        else ...[
          for (final (exercise, history) in exercises)
            Gutter(
              child: _ExerciseCard(
                exercise: exercise,
                history: history,
                bests: records[exercise.id],
              ),
            ),
          Gutter(child: TagWrap(labels: [context.l10n.epleyEstimate])),
        ],
      ],
    );
  }
}

/// What the range's training adds up to.
List<Figure> _totalFigures(
  BuildContext context,
  ({
    int workouts,
    int sets,
    double volume,
    Duration time,
    Duration? averageLength,
    int records,
  })
  totals,
) {
  final l10n = context.l10n;
  return [
    (
      label: l10n.workoutsTotal,
      value: l10n.timesValue(count: '${totals.workouts}'),
      unit: null,
      color: null,
    ),
    (label: l10n.totalSets, value: '${totals.sets}', unit: null, color: null),
    if (totals.volume > 0)
      (
        label: l10n.totalVolume,
        value: formatKcal(totals.volume.round()),
        unit: 'kg',
        color: null,
      ),
    if (totals.time > Duration.zero)
      (
        label: l10n.totalTime,
        value: formatDuration(context.l10n, totals.time),
        unit: null,
        color: null,
      ),
    if (totals.averageLength case final length?)
      (
        label: l10n.averageStage(stage: l10n.durationLabel),
        value: formatDuration(context.l10n, length),
        unit: null,
        color: null,
      ),
    (
      label: l10n.personalRecords,
      value: '${totals.records}',
      unit: null,
      color: null,
    ),
  ];
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.overview, required this.activity});

  final TrendsOverview overview;
  final ActivitySummary activity;

  @override
  Widget build(BuildContext context) {
    final workoutsTile = _SummaryTile(
      category: context.l10n.weeklyWorkouts,
      color: AppColors.training,
      value: '${overview.workoutsThisWeek}',
      unit: context.l10n.timesThisWeekUnit,
      chart: MiniBarChart(bars: overview.weeklyWorkouts, height: 40),
    );
    // Exercise stands beside training rather than inside it: a run is
    // not a workout, and folding them together hides both.
    final activityTile = _SummaryTile(
      category: context.l10n.weeklyActivities,
      color: AppColors.activity,
      value: '${activity.thisWeek}',
      unit: context.l10n.timesThisWeekUnit,
      caption: _activityCaption(context.l10n, activity),
      chart: activity.hasRecords
          ? MiniBarChart(bars: activity.weekly, height: 40)
          : null,
    );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: workoutsTile),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: activityTile),
        ],
      ),
    );
  }
}

/// What the week's minutes mean: against a normal week once there is one,
/// and plainly until then.
String _activityCaption(AppLocalizations l10n, ActivitySummary activity) {
  if (!activity.hasRecords) return l10n.noActivityEntries;
  final minutes = activity.minutesThisWeek;
  final typical = activity.typicalWeeklyMinutes;
  if (typical == null) return l10n.durationMinutes(minutes: minutes);
  return l10n.minutesVersusUsual(minutes: minutes, usual: typical);
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.category,
    required this.value,
    this.color,
    this.unit,
    this.caption,
    this.chart,
  });

  final String category;
  final Color? color;
  final String value;
  final String? unit;
  final String? caption;
  final Widget? chart;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (color != null)
            CategoryLabel(label: category, color: color!)
          else
            Text(category, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: ValueWithUnit(value: value, unit: unit),
          ),
          if (caption != null) Text(caption!, style: AppTextStyles.caption),
          if (chart != null) ...[const SizedBox(height: AppSpacing.sm), chart!],
        ],
      ),
    );
  }
}

/// One muscle's working sets week by week: this week against what the
/// weeks before it usually came to, not against a textbook target.
class _MuscleCard extends StatelessWidget {
  const _MuscleCard({required this.muscle, required this.weeks});

  final MuscleGroup muscle;
  final List<WeeklyBar> weeks;

  /// The lowest and highest of the finished weeks just before this one;
  /// null before there are any with sets.
  (int, int)? get _usual {
    final before = weeks
        .take(weeks.length - 1)
        .toList()
        .reversed
        .take(_usualWeeks)
        .map((week) => week.$2)
        .where((sets) => sets > 0)
        .toList();
    if (before.isEmpty) return null;
    return (
      before.reduce((a, b) => a < b ? a : b),
      before.reduce((a, b) => a > b ? a : b),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usual = _usual;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  muscle.labelIn(context.l10n),
                  style: AppTextStyles.itemTitle,
                ),
              ),
              ValueWithUnit(
                value: '${weeks.last.$2}',
                unit: context.l10n.setsThisWeekUnit,
                style: AppTextStyles.bigNumber.copyWith(fontSize: 22),
              ),
            ],
          ),
          if (usual != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              context.l10n.priorWeeksSets(
                weeks: _usualWeeks,
                sets: usual.$1 == usual.$2
                    ? '${usual.$1}'
                    : '${usual.$1}–${usual.$2}',
              ),
              style: AppTextStyles.caption,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            label: context.l10n.muscleSetsChart(
              muscle: muscle.labelIn(context.l10n),
              sets: joinList(context.l10n, weeks.map((week) => '${week.$2}')),
            ),
            excludeSemantics: true,
            child: MiniBarChart(bars: weeks, height: 56),
          ),
        ],
      ),
    );
  }
}

/// One trained exercise: its estimated max over its sessions and its
/// best set; it opens its history.
class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.history,
    required this.bests,
  });

  final ExerciseDefinition exercise;
  final ExerciseHistory history;

  /// Null when no counted set gives a best.
  final ExerciseBests? bests;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final last = history.last!;
    final estimates = [
      for (final entry in history.recent.reversed) ?entry.oneRepMaxKg,
    ];
    return AppCard(
      onTap: () => pushPage(context, ExerciseDetailScreen(exercise: exercise)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exercise.name, style: AppTextStyles.itemTitle),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            [
              if (estimates.isNotEmpty)
                l10n.estimatedMaxValue(weight: estimates.last.round()),
              l10n.timesCount(count: history.sessionCount),
              l10n.lastSetOn(
                date: context.dates.monthDay(last.date),
                set: last.figuresIn(l10n, exercise.trackingType),
              ),
            ].join(' · '),
            style: AppTextStyles.caption,
          ),
          if (bests case final bests?)
            Text(_record(context, bests), style: AppTextStyles.caption),
          if (estimates.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              label: l10n.estimatedMaxTrend(count: estimates.length),
              excludeSemantics: true,
              child: Sparkline(
                values: estimates,
                color: AppColors.training,
                height: 40,
                isEstimate: true,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              [
                '${l10n.statHighest} '
                    '${formatWeight(_tenth(estimates.reduce(math.max)))} kg',
                '${l10n.periodChange} '
                    '${_signed(estimates.last - estimates.first)} kg',
              ].join(' · '),
              style: AppTextStyles.caption,
            ),
          ],
        ],
      ),
    );
  }

  /// What a record is depends on how the exercise is recorded.
  String _record(BuildContext context, ExerciseBests bests) {
    final l10n = context.l10n;
    final set = bests.best.figuresIn(l10n, exercise.trackingType);
    final date = context.dates.monthDay(bests.best.date);
    return switch (exercise.trackingType) {
      TrackingType.weightReps ||
      TrackingType.weightDuration => l10n.heaviestSet(set: set, date: date),
      TrackingType.reps => l10n.mostRepsSet(set: set, date: date),
      TrackingType.duration => l10n.longestSet(set: set, date: date),
      TrackingType.distance => l10n.furthestSet(set: set, date: date),
    };
  }
}

double _tenth(double value) => (value * 10).round() / 10;

/// `+2.5` or `−1`: a change with its sign, a true minus for a fall.
String _signed(double change) =>
    '${change < 0 ? '−' : '+'}${formatWeight(_tenth(change.abs()))}';
