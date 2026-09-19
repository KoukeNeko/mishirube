import 'package:flutter/material.dart';

import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../shared/widgets/widgets.dart';
import '../nutrition/daily_nutrition_screen.dart';
import 'insight_detail_screen.dart';
import 'trends_empty_screen.dart';

enum _TrendRange {
  fourWeeks('近 4 週'),
  threeMonths('3 個月'),
  all('全部');

  const _TrendRange(this.label);

  final String label;
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
    return CollapsingPage(
      title: '趨勢',
      subtitle: '8 / 23 – 9 / 19・你的訓練與身體變化',
      autoHide: true,
      // The range drives every chart below, so it stays pinned.
      pinned: SegmentedChoice(
        options: _TrendRange.values,
        selected: _range,
        labelOf: (range) => range.label,
        onChanged: (range) => setState(() => _range = range),
      ),
      children: [
        const InsightCard(title: '結論', insight: MockInsights.weightTrend),
        InsightCard(
          title: '結論',
          insight: MockInsights.squatVolumeShort,
          onTap: () => pushPage(context, const InsightDetailScreen()),
        ),
        const SectionLabel('摘要'),
        const _SummaryGrid(),
        const SectionLabel('看得更細'),
        AccentRow(
          color: AppColors.training,
          title: '訓練的詳細圖表',
          showChevron: true,
          onTap: () => pushPage(context, const InsightDetailScreen()),
        ),
        AccentRow(
          color: AppColors.nutrition,
          title: '飲食的詳細圖表',
          showChevron: true,
          onTap: () => pushPage(context, const DailyNutritionScreen()),
        ),
        AccentRow(
          color: AppColors.body,
          title: '身體的詳細圖表',
          showChevron: true,
          onTap: () => pushPage(context, const TrendsEmptyScreen()),
        ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid();

  @override
  Widget build(BuildContext context) {
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
                  value: '72.4',
                  delta: '−1.2',
                  chart: Sparkline(values: MockInsights.weightSeries),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SummaryTile(
                  category: '每週訓練',
                  color: AppColors.training,
                  value: '3',
                  unit: '次 · 本週',
                  chart: MiniBarChart(
                    bars: MockInsights.weeklyWorkouts,
                    height: 40,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Row(
          children: [
            Expanded(
              child: _SummaryTile(
                category: '平均睡眠',
                value: '6:58',
                caption: '26 / 28 天有資料',
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _SummaryTile(
                category: '飲食完整天數',
                value: '19/28',
                caption: '其餘只有部分餐點',
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
