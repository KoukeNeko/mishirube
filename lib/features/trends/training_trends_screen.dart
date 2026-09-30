import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../backend/application/activity_service.dart';
import '../../backend/application/insights_service.dart';
import '../../app/theme.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'insight_detail_screen.dart';
import 'exercise_trends_screen.dart';
import 'muscle_load_card.dart';
import 'muscle_trends_screen.dart';
import 'personal_records_screen.dart';
import 'trends_view_model.dart';
import '../../l10n/l10n.dart';

enum _TrendRange {
  fourWeeks(Duration(days: 28)),
  threeMonths(Duration(days: 91)),
  all(Duration(days: 365));

  const _TrendRange(this.window);

  final Duration window;

  String labelIn(AppLocalizations l10n) => switch (this) {
    fourWeeks => l10n.last4Weeks,
    threeMonths => l10n.monthsCount(count: 3),
    all => l10n.logFilterAll,
  };
}

/// Training over a chosen range: how often, what was worked, and each
/// exercise's progress. The Trends page lifts a change from here only
/// when it is worth noticing.
class TrainingTrendsScreen extends StatefulWidget {
  const TrainingTrendsScreen({super.key});

  @override
  State<TrainingTrendsScreen> createState() => _TrainingTrendsScreenState();
}

class _TrainingTrendsScreenState extends State<TrainingTrendsScreen> {
  _TrendRange _range = _TrendRange.fourWeeks;
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
    final overview = _model.overview(_range.window);
    final volume = _model.volumeReport(window: _range.window);
    final activity = _model.activity(_range.window);
    return DetailPage(
      appBar: PageAppBar(
        title: context.l10n.moduleTraining,
        subtitle:
            '${context.dates.monthDay(overview.from)} – '
            '${context.dates.monthDay(overview.to)}',
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
        if (_model.trainingTotals(_range.window) case final totals
            when totals.workouts > 0) ...[
          Gutter(child: SectionLabel(context.l10n.statsSection)),
          Gutter(child: FigureGrid(figures: _totalFigures(context, totals))),
        ],
        Gutter(child: SectionLabel(context.l10n.musclesTitle)),
        Gutter(
          child: MuscleLoadCard(
            load: _model.muscleLoad(_range.window),
            figure: _model.muscleFigure,
            onFigure: _model.setMuscleFigure,
          ),
        ),
        Gutter(
          child: AccentRow(
            color: AppColors.training,
            title: context.l10n.weeklySetsTitle,
            subtitle: context.l10n.last8Weeks,
            showChevron: true,
            onTap: () => pushPage(context, const MuscleTrendsScreen()),
          ),
        ),
        Gutter(child: SectionLabel(context.l10n.exercisesLabel)),
        Gutter(
          child: AccentRow(
            color: AppColors.training,
            title: context.l10n.estimatedMax,
            showChevron: true,
            onTap: () => pushPage(context, const ExerciseTrendsScreen()),
          ),
        ),
        Gutter(
          child: AccentRow(
            color: AppColors.training,
            title: context.l10n.personalRecords,
            showChevron: true,
            onTap: () => pushPage(context, const PersonalRecordsScreen()),
          ),
        ),
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
        value: formatHoursMinutes(totals.time),
        unit: null,
        color: null,
      ),
    if (totals.averageLength case final length?)
      (
        label: l10n.averageStage(stage: l10n.durationLabel),
        value: formatHoursMinutes(length),
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
