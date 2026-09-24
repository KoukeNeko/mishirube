import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../backend/application/activity_service.dart';
import '../../backend/application/insights_service.dart';
import '../../app/theme.dart';
import '../../shared/widgets/widgets.dart';
import 'insight_detail_screen.dart';
import 'exercise_trends_screen.dart';
import 'muscle_load_card.dart';
import 'muscle_trends_screen.dart';
import 'personal_records_screen.dart';
import 'trends_view_model.dart';

enum _TrendRange {
  fourWeeks('近 4 週', Duration(days: 28)),
  threeMonths('3 個月', Duration(days: 91)),
  all('全部', Duration(days: 365));

  const _TrendRange(this.label, this.window);

  final String label;
  final Duration window;
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
        title: '訓練',
        subtitle: '${_date(overview.from)} – ${_date(overview.to)}',
      ),
      children: [
        Gutter(
          child: SegmentedChoice(
            options: _TrendRange.values,
            selected: _range,
            labelOf: (range) => range.label,
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
        Gutter(child: const SectionLabel('肌群')),
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
            title: '每週組數',
            subtitle: '近 8 週',
            showChevron: true,
            onTap: () => pushPage(context, const MuscleTrendsScreen()),
          ),
        ),
        Gutter(child: const SectionLabel('動作')),
        Gutter(
          child: AccentRow(
            color: AppColors.training,
            title: '估計最大重量',
            showChevron: true,
            onTap: () => pushPage(context, const ExerciseTrendsScreen()),
          ),
        ),
        Gutter(
          child: AccentRow(
            color: AppColors.training,
            title: '個人紀錄',
            showChevron: true,
            onTap: () => pushPage(context, const PersonalRecordsScreen()),
          ),
        ),
        Gutter(
          child: AccentRow(
            color: AppColors.training,
            title: '訓練量',
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

  static String _date(DateTime day) => '${day.month} 月 ${day.day} 日';
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.overview, required this.activity});

  final TrendsOverview overview;
  final ActivitySummary activity;

  @override
  Widget build(BuildContext context) {
    final workoutsTile = _SummaryTile(
      category: '每週訓練',
      color: AppColors.training,
      value: '${overview.workoutsThisWeek}',
      unit: '次 · 本週',
      chart: MiniBarChart(bars: overview.weeklyWorkouts, height: 40),
    );
    // Exercise stands beside training rather than inside it: a run is
    // not a workout, and folding them together hides both.
    final activityTile = _SummaryTile(
      category: '每週運動',
      color: AppColors.activity,
      value: '${activity.thisWeek}',
      unit: '次 · 本週',
      caption: _activityCaption(activity),
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
String _activityCaption(ActivitySummary activity) {
  if (!activity.hasRecords) return '沒有運動紀錄';
  final minutes = activity.minutesThisWeek;
  final typical = activity.typicalWeeklyMinutes;
  if (typical == null) return '$minutes 分';
  return '$minutes 分 · 平常 $typical 分';
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
