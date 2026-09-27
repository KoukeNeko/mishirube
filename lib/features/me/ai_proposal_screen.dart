import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../shared/widgets/widgets.dart';
import '../../l10n/l10n.dart';

enum _ChangeKind { removed, added, unchanged }

class _ProposedChange {
  const _ProposedChange(
    this.kind,
    this.exercise,
    this.sets,
    this.reps, {
    this.rir,
  });

  final _ChangeKind kind;
  final String exercise;
  final int sets;
  final int reps;
  final int? rir;

  String prescription(AppLocalizations l10n) => [
    l10n.setsTimesRepsShort(sets: sets, reps: reps),
    if (rir case final rir?) 'RIR $rir',
  ].join(' · ');
}

// The demo proposal's exercises and routine are the seed's own, named
// as the seed names them.
// l10n-ignore: demo data.
const _routine = '下肢 A';

const _changes = [
  // l10n-ignore: demo data.
  _ProposedChange(_ChangeKind.removed, '槓鈴深蹲', 4, 5, rir: 2),
  // l10n-ignore: demo data.
  _ProposedChange(_ChangeKind.added, '槓鈴深蹲', 5, 5, rir: 2),
  // l10n-ignore: demo data.
  _ProposedChange(_ChangeKind.removed, '腿彎舉', 3, 12),
  // l10n-ignore: demo data.
  _ProposedChange(_ChangeKind.added, '腿彎舉', 4, 12),
  // l10n-ignore: demo data.
  _ProposedChange(_ChangeKind.unchanged, '羅馬尼亞硬舉', 3, 8),
];

/// A draft change from AI, shown as a diff that only applies on accept.
class AiProposalScreen extends StatelessWidget {
  const AiProposalScreen({super.key});

  void _accept(BuildContext context) {
    AppStoreScope.read(context).applyAiProposal();
    showToast(
      context,
      context.l10n.appliedTo(routine: _routine),
      kind: ToastKind.success,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DetailPage(
      appBar: PageAppBar(
        title: context.l10n.aiProposalTitle,
        subtitle: context.l10n.aiProposalSubtitle(routine: _routine),
      ),
      footer: ButtonPair(
        secondary: SecondaryButton(
          label: context.l10n.reject,
          onPressed: () => Navigator.of(context).pop(),
        ),
        primaryFlex: 2,
        primary: PrimaryButton(
          label: context.l10n.acceptAndApply,
          onPressed: () => _accept(context),
        ),
      ),
      children: [
        Gutter(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.questionLabel, style: AppTextStyles.overline),
                const SizedBox(height: AppSpacing.xs),
                Text(context.l10n.proposalQuestion, style: AppTextStyles.body),
              ],
            ),
          ),
        ),
        Gutter(child: SectionLabel(context.l10n.changesCount(count: 2))),
        for (final change in _changes)
          Gutter(child: _ChangeRow(change: change)),
        Gutter(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.reasonLabel, style: AppTextStyles.overline),
                const SizedBox(height: AppSpacing.xs),
                Text(context.l10n.proposalReason, style: AppTextStyles.body),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    TagChip(label: context.l10n.proposalDataSent),
                    TagChip(label: context.l10n.proposalModel),
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
        context.l10n.removeAction,
        AppColors.nutrition,
      ),
      _ChangeKind.added => (
        CardTone.training,
        '+',
        context.l10n.addedLabel,
        AppColors.training,
      ),
      _ChangeKind.unchanged => (
        CardTone.neutral,
        '·',
        context.l10n.unchangedLabel,
        AppColors.textSecondary,
      ),
    };
    return NavCard(
      tone: tone,
      leading: SizedBox(
        width: 16,
        child: Text(
          symbol,
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: change.exercise,
      subtitle: change.prescription(context.l10n),
      trailing: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }
}
