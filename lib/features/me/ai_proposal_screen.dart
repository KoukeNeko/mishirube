import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../shared/widgets/widgets.dart';

enum _ChangeKind { removed, added, unchanged }

class _ProposedChange {
  const _ProposedChange(this.kind, this.exercise, this.prescription);

  final _ChangeKind kind;
  final String exercise;
  final String prescription;
}

const _changes = [
  _ProposedChange(_ChangeKind.removed, '槓鈴深蹲', '4 組 × 5 次 · RIR 2'),
  _ProposedChange(_ChangeKind.added, '槓鈴深蹲', '5 組 × 5 次 · RIR 2'),
  _ProposedChange(_ChangeKind.removed, '腿彎舉', '3 組 × 12 次'),
  _ProposedChange(_ChangeKind.added, '腿彎舉', '4 組 × 12 次'),
  _ProposedChange(_ChangeKind.unchanged, '羅馬尼亞硬舉', '3 組 × 8 次'),
];

/// A draft change from AI, shown as a diff that only applies on accept.
class AiProposalScreen extends StatelessWidget {
  const AiProposalScreen({super.key});

  void _accept(BuildContext context) {
    AppStoreScope.read(context).applyAiProposal();
    showToast(context, '已套用到「下肢 A」', kind: ToastKind.success);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DetailPage(
      appBar: const PageAppBar(title: 'AI 建議的修改', subtitle: '訓練模板「下肢 A」· 尚未套用'),
      footer: ButtonPair(
        secondary: SecondaryButton(
          label: '拒絕',
          onPressed: () => Navigator.of(context).pop(),
        ),
        primaryFlex: 2,
        primary: PrimaryButton(
          label: '接受並套用',
          onPressed: () => _accept(context),
        ),
      ),
      children: [
        Gutter(
          child: const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('提問', style: AppTextStyles.overline),
                SizedBox(height: AppSpacing.xs),
                Text('「最近深蹲的組數是不是太少了？幫我加回來。」', style: AppTextStyles.body),
              ],
            ),
          ),
        ),
        Gutter(child: const SectionLabel('改動 2 個動作')),
        for (final change in _changes)
          Gutter(child: _ChangeRow(change: change)),
        Gutter(
          child: const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('理由', style: AppTextStyles.overline),
                SizedBox(height: AppSpacing.xs),
                Text(
                  '每週工作組數從 12 降到 8，依「肌力維持」目標，'
                  '訓練引擎建議的區間是 10 – 12 組。',
                  style: AppTextStyles.body,
                ),
                SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    TagChip(label: '送出的資料：近 4 週訓練紀錄'),
                    TagChip(label: '模型：自架端點'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.change});

  final _ProposedChange change;

  @override
  Widget build(BuildContext context) {
    final (tone, symbol, label, color) = switch (change.kind) {
      _ChangeKind.removed => (
        CardTone.nutrition,
        '−',
        '移除',
        AppColors.nutrition,
      ),
      _ChangeKind.added => (CardTone.training, '+', '新增', AppColors.training),
      _ChangeKind.unchanged => (
        CardTone.neutral,
        '·',
        '不變',
        AppColors.textSecondary,
      ),
    };
    return AppCard(
      tone: tone,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              symbol,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(change.exercise, style: AppTextStyles.itemTitle),
                Text(change.prescription, style: AppTextStyles.caption),
              ],
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
