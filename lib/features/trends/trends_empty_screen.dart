import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../shared/widgets/widgets.dart';

/// What trends look like before there is enough data to judge anything.
class TrendsEmptyScreen extends StatelessWidget {
  const TrendsEmptyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DetailPage(
      appBar: const PageAppBar(title: '趨勢', subtitle: '2026 年 9 月'),
      children: [
        EmptyStateCard(
          icon: Icons.show_chart,
          title: '還不足以判斷趨勢',
          message: '體重的短期波動很大，至少要 14 天的紀錄才分得出趨勢和雜訊。目前有 3 天。',
          action: SizedBox(
            width: 200,
            child: PrimaryButton(
              label: '記錄今天的體重',
              isCompact: true,
              onPressed: () => showToast(context, '體重輸入畫面尚未設計'),
            ),
          ),
        ),
        const SectionLabel('已經可以看的'),
        const _ReadyMetric(
          title: '每週訓練次數',
          value: '3',
          caption: '本週 · 這是第一個完整的週，沒有可比較的上週',
        ),
        const _ReadyMetric(
          title: '飲食完整天數',
          value: '1/3',
          caption: '另外 2 天只有部分餐點，不會拿來算平均攝取',
        ),
        const InfoBanner(message: '資料不夠的時候，這裡會說「目前無法可靠判斷」，不會生出一個看起來很篤定的數字。'),
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
