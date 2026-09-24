import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../backend/application/activity_service.dart';
import '../../backend/application/insights_service.dart';
import '../../app/theme.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../body/body_screen.dart';
import '../nutrition/daily_nutrition_screen.dart';
import '../sleep/sleep_screen.dart';
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

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
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
    return CollapsingPage(
      title: '趨勢',
      subtitle: '${_date(overview.from)} – ${_date(overview.to)}',
      compactBar: CompactBarBehavior.none,
      // The range drives every chart below, so it stays pinned.
      pinned: Gutter(
        child: SegmentedChoice(
          options: _TrendRange.values,
          selected: _range,
          labelOf: (range) => range.label,
          onChanged: (range) => setState(() => _range = range),
        ),
      ),
      children: [
        if (overview.insights.isEmpty)
          Gutter(child: const InfoBanner(message: '紀錄還不夠多。'))
        else
          for (final insight in overview.insights)
            Gutter(
              child: InsightCard(
                insight: insight,
                onTap: insight == volume?.insight
                    ? () => pushPage(
                        context,
                        InsightDetailScreen(exerciseId: volume?.exercise.id),
                      )
                    : null,
              ),
            ),
        Gutter(child: const SectionLabel('摘要')),
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
        Gutter(child: const SectionLabel('其他')),
        Gutter(
          child: AccentRow(
            color: AppColors.nutrition,
            title: '飲食',
            showChevron: true,
            onTap: () => pushPage(context, const DailyNutritionScreen()),
          ),
        ),
        Gutter(
          child: AccentRow(
            color: AppColors.body,
            title: '身體',
            showChevron: true,
            onTap: () => pushPage(context, const BodyScreen()),
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

  /// Narrowest a tile reads well at: a value, its unit and a small chart.
  static const _minTileWidth = 180.0;

  @override
  Widget build(BuildContext context) {
    final weight = overview.weight;
    final change = weight.change;
    final foodDays = overview.foodDaysTracked;
    final weightTile = _SummaryTile(
      category: '體重',
      color: AppColors.body,
      value: weight.latest == null ? '—' : formatWeight(weight.latest!),
      // A single measurement is a number, not a change.
      delta: change == null
          ? null
          : '${change < 0 ? '−' : '+'}'
                '${formatWeight(change.abs())}',
      caption: weight.values.isEmpty ? '沒有體重紀錄' : null,
      chart: weight.values.length < 2 ? null : Sparkline(values: weight.values),
    );
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
    final sleepTile = _SummaryTile(
      category: '平均睡眠',
      value: overview.averageSleep == null
          ? '—'
          : formatHoursMinutes(overview.averageSleep!),
      caption: overview.averageSleep == null ? '沒有睡眠紀錄' : null,
      onTap: () => pushPage(context, const SleepScreen()),
    );
    final foodTile = _SummaryTile(
      category: '飲食完整天數',
      value: foodDays == 0 ? '—' : '${overview.foodDaysComplete}/$foodDays',
      caption: foodDays == 0 ? '沒有飲食紀錄' : '其餘天數只記錄了部分的餐',
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Three across once the column has room, as a dashboard uses a wide
        // pane; on a phone, exercise gets a row of its own between pairs.
        final isWide =
            constraints.maxWidth >= _minTileWidth * 3 + AppSpacing.sm * 2;
        final rows = isWide
            ? [
                [weightTile, workoutsTile, activityTile],
                [sleepTile, foodTile],
              ]
            : [
                [weightTile, workoutsTile],
                [activityTile],
                [sleepTile, foodTile],
              ];
        final columns = isWide ? 3 : 1;
        return Column(
          children: [
            for (final (index, row) in rows.indexed) ...[
              if (index > 0) const SizedBox(height: AppSpacing.sm),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, tile) in row.indexed) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.sm),
                      Expanded(child: tile),
                    ],
                    // A short last row keeps the grid's column widths.
                    for (var i = row.length; i < columns; i++) ...[
                      const SizedBox(width: AppSpacing.sm),
                      const Expanded(child: SizedBox()),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
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
    this.delta,
    this.caption,
    this.chart,
    this.onTap,
  });

  final String category;
  final Color? color;
  final String value;
  final String? unit;
  final String? delta;
  final String? caption;
  final Widget? chart;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (color != null)
            CategoryLabel(label: category, color: color!)
          else
            Text(category, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: ValueWithUnit(value: value, unit: unit),
                ),
              ),
              if (delta != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Text(
                  delta!,
                  style: const TextStyle(
                    color: AppColors.body,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          if (caption != null) Text(caption!, style: AppTextStyles.caption),
          if (chart != null) ...[const SizedBox(height: AppSpacing.sm), chart!],
        ],
      ),
    );
  }
}
