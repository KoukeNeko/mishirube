import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/view_model.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../shared/widgets/widgets.dart';
import '../me/ai_proposal_screen.dart';
import 'trends_view_model.dart';

/// Explains one insight: conclusion, evidence, data quality and next step.
class InsightDetailScreen extends StatelessWidget {
  const InsightDetailScreen({super.key, this.exerciseId});

  /// Which exercise's volume to explain; the most trained one by default.
  final String? exerciseId;

  @override
  Widget build(BuildContext context) => ViewModelBuilder(
    create: TrendsViewModel.new,
    builder: (context, trends) => _page(context, trends),
  );

  Widget _page(BuildContext context, TrendsViewModel trends) {
    final store = AppStoreScope.of(context);
    final report = trends.volumeReport(exerciseId: exerciseId);
    if (report == null) {
      return const DetailPage(
        appBar: PageAppBar(title: '訓練量', subtitle: '值得注意'),
        children: [Gutter(child: InfoBanner(message: '訓練紀錄不足。'))],
      );
    }
    final weeks = report.weeklySets.length;
    final estimate = report.history.estimatedOneRepMaxKg;
    final first = report.weeklySets.first.$2;
    final last = report.weeklySets.last.$2;
    return DetailPage(
      appBar: PageAppBar(
        title: '${report.exercise.name}的訓練量',
        subtitle: '值得注意 · 近 $weeks 週',
      ),
      children: [
        Gutter(
          child: _Section(
            label: '值得注意',
            child: Text(
              report.insight?.statement ??
                  '每週工作組數維持在 $last 組，估計最大重量 '
                      '${estimate == null ? '尚無法估計' : '約 ${estimate.round()} kg'}。',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            ),
          ),
        ),
        Gutter(
          child: _Section(
            label: '依據',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '每週工作組數，取自 ${report.sessionCount} 次訓練紀錄。',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: AppSpacing.md),
                MiniBarChart(bars: report.weeklySets),
              ],
            ),
          ),
        ),
        Gutter(
          child: _Section(
            label: '資料品質與完整度',
            child: TagWrap(
              labels: [
                '${report.sessionCount} 次訓練皆有紀錄',
                '重量與次數為手動輸入',
                if (estimate != null) 'Epley 估計',
              ],
            ),
          ),
        ),
        Gutter(
          child: _Section(
            label: '時間範圍',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_date(store.now().subtract(Duration(days: weeks * 7)))}'
                  ' → ${_date(store.now())}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text('$weeks 個完整週', style: AppTextStyles.caption),
              ],
            ),
          ),
        ),
        Gutter(
          child: _Section(
            label: '可採取的行動',
            showDivider: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  last < first
                      ? '每週組數比這段期間開始時少。要繼續進步，拉回 $first 組左右。'
                      : '目前的組數穩定。要繼續進步，小幅增加每週組數或重量。',
                  style: AppTextStyles.body,
                ),
                if (store.selectedRoutine case final routine?) ...[
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: '調整「${routine.name}」的組數',
                    isCompact: true,
                    onPressed: () =>
                        pushPage(context, const AiProposalScreen()),
                  ),
                ],
              ],
            ),
          ),
        ),
        Gutter(child: Text('這是訓練紀錄的描述，不是醫療建議。', style: AppTextStyles.caption)),
        Gutter(
          child: LinkText(
            label: '查看這段期間的原始紀錄',
            onTap: () => returnToTab(context, HomeTab.log),
          ),
        ),
      ],
    );
  }

  static String _date(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
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
