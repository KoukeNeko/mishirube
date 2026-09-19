import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../shared/widgets/widgets.dart';
import '../me/ai_proposal_screen.dart';

/// Explains one insight: conclusion, evidence, data quality and next step.
class InsightDetailScreen extends StatelessWidget {
  const InsightDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DetailPage(
      appBar: const PageAppBar(title: '深蹲的訓練量', subtitle: '洞察 · 近 4 週'),
      children: [
        const _Section(
          label: '結論',
          child: Text(
            '每週組數從 12 掉到 8，估計最大重量維持在 114 – 117 公斤。',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
        ),
        const _Section(
          label: '依據',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('每週有效組數（不含熱身組），取自 12 次訓練紀錄。', style: AppTextStyles.body),
              SizedBox(height: AppSpacing.md),
              MiniBarChart(bars: MockInsights.weeklySquatSets),
            ],
          ),
        ),
        const _Section(
          label: '資料品質與完整度',
          child: TagWrap(
            labels: ['12 / 12 次訓練皆有紀錄', '重量與次數為手動輸入', '最大重量為 Epley 公式估計，非實測'],
          ),
        ),
        const _Section(
          label: '時間範圍',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '2026-08-23 → 2026-09-19',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text('4 個完整週', style: AppTextStyles.caption),
            ],
          ),
        ),
        _Section(
          label: '可採取的行動',
          showDivider: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '想維持肌力但減少疲勞，目前的組數合理。想繼續進步，可以把每週組數拉回 10 – 12 組。',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: '調整「下肢 A」的組數',
                isCompact: true,
                onPressed: () => pushPage(context, const AiProposalScreen()),
              ),
            ],
          ),
        ),
        const Text(
          '由訓練引擎 v0.4 的規則計算，同樣的資料會得到同樣的結果。'
          '這是訓練紀錄的描述，不是醫療建議。',
          style: AppTextStyles.caption,
        ),
        LinkText(
          label: '查看這段期間的原始紀錄',
          onTap: () => returnToTab(context, HomeTab.log),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.child,
    this.showDivider = true,
  });

  final String label;
  final Widget child;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.overline),
        const SizedBox(height: AppSpacing.sm),
        child,
        if (showDivider) const Divider(height: AppSpacing.xxl),
      ],
    );
  }
}
