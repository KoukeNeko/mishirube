import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/navigation.dart';
import '../../shared/widgets/widgets.dart';
import '../journal/weight_entry_screen.dart';

/// What trends look like before there is enough data to judge anything.
class TrendsEmptyScreen extends StatelessWidget {
  const TrendsEmptyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DetailPage(
      appBar: const PageAppBar(title: '趨勢', subtitle: '2026 年 9 月'),
      children: [
        Gutter(
          child: EmptyStateCard(
            icon: Icons.show_chart,
            title: '還不足以判斷趨勢',
            message: '需要 14 天體重紀錄，目前 3 天。',
            action: SizedBox(
              width: 200,
              child: PrimaryButton(
                label: '記錄今天的體重',
                isCompact: true,
                onPressed: () => pushPage(context, const WeightEntryScreen()),
              ),
            ),
          ),
        ),
        Gutter(child: const SectionLabel('其他指標')),
        Gutter(
          child: const _ReadyMetric(
            title: '每週訓練次數',
            value: '3',
            caption: '本週 · 第一個完整的週，沒有上週可比',
          ),
        ),
        Gutter(
          child: const _ReadyMetric(
            title: '飲食完整天數',
            value: '1/3',
            caption: '另外 2 天只記錄了部分的餐，不算入平均',
          ),
        ),
      ],
    );
  }
}

class _ReadyMetric extends StatelessWidget {
  const _ReadyMetric({
    required this.title,
    required this.value,
    required this.caption,
  });

  final String title;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.itemTitle),
                const SizedBox(height: AppSpacing.xxs),
                Text(caption, style: AppTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(value, style: AppTextStyles.bigNumber.copyWith(fontSize: 26)),
        ],
      ),
    );
  }
}
