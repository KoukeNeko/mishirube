import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../backend/application/activity_service.dart';
import '../../backend/application/insights_service.dart';
import '../../app/theme.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../nutrition/daily_nutrition_screen.dart';
import 'insight_detail_screen.dart';
import 'trends_empty_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final overview = store.trends(window: _range.window);
    final volume = store.volumeReport(window: _range.window);
    final activity = store.activitySummary(window: _range.window);
    return CollapsingPage(
      title: '趨勢',
      subtitle: '${_date(overview.from)} – ${_date(overview.to)}・你的訓練與身體變化',
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
          Gutter(child: const InfoBanner(message: '紀錄還不夠多，累積之後這裡會說明看得出什麼。'))
        else
          for (final insight in overview.insights)
            Gutter(
              child: InsightCard(
                title: '結論',
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
        Gutter(child: const SectionLabel('看得更細')),
        Gutter(
          child: AccentRow(
            color: AppColors.training,
            title: '訓練的詳細圖表',
            showChevron: true,
            onTap: () => pushPage(
              context,
              InsightDetailScreen(exerciseId: volume?.exercise.id),
            ),
          ),
        ),
        Gutter(
          child: AccentRow(
            color: AppColors.nutrition,
            title: '飲食的詳細圖表',
            showChevron: true,
            onTap: () => pushPage(context, const DailyNutritionScreen()),
          ),
        ),
        Gutter(
          child: AccentRow(
            color: AppColors.body,
            title: '身體的詳細圖表',
            showChevron: true,
            onTap: () => pushPage(context, const TrendsEmptyScreen()),
          ),
        ),
      ],
    );
  }

  static String _date(DateTime day) => '${day.month} / ${day.day}';
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.overview, required this.activity});

  final TrendsOverview overview;
  final ActivitySummary activity;

  @override
  Widget build(BuildContext context) {
    final weight = overview.weight;
    final change = weight.change;
    final foodDays = overview.foodDaysTracked;
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _SummaryTile(
                  category: '體重',
                  color: AppColors.body,
                  value: weight.latest == null
                      ? '—'
                      : formatWeight(weight.latest!),
                  // A single measurement is a number, not a change.
                  delta: change == null
                      ? null
                      : '${change < 0 ? '−' : '+'}'
                            '${formatWeight(change.abs())}',
                  caption: weight.values.isEmpty ? '尚未記錄體重' : null,
                  chart: weight.values.length < 2
                      ? null
                      : Sparkline(values: weight.values),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SummaryTile(
                  category: '每週訓練',
                  color: AppColors.training,
                  value: '${overview.workoutsThisWeek}',
                  unit: '次 · 本週',
                  chart: MiniBarChart(
                    bars: overview.weeklyWorkouts,
                    height: 40,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Exercise stands beside training rather than inside it: a run is
        // not a workout, and folding them together hides both.
        _SummaryTile(
          category: '每週運動',
          color: AppColors.activity,
          value: '${activity.thisWeek}',
          unit: '次 · 本週',
          caption: activity.hasRecords
              ? '${activity.time.inMinutes} 分鐘'
              : '尚未記錄運動',
          chart: activity.hasRecords
              ? MiniBarChart(bars: activity.weekly, height: 40)
              : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _SummaryTile(
                category: '平均睡眠',
                value: overview.averageSleep == null
                    ? '—'
                    : formatHoursMinutes(overview.averageSleep!),
                caption: overview.averageSleep == null ? '尚未記錄睡眠' : null,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _SummaryTile(
                category: '飲食完整天數',
                value: foodDays == 0
                    ? '—'
                    : '${overview.foodDaysComplete}/$foodDays',
                caption: foodDays == 0 ? '尚未記錄飲食' : '其餘只有部分餐點',
              ),
            ),
          ],
        ),
      ],
    );
  }
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
  });

  final String category;
  final Color? color;
  final String value;
  final String? unit;
  final String? delta;
  final String? caption;
  final Widget? chart;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
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
