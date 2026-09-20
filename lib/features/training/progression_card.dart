import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../backend/engines/progression_engine.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';

/// One suggestion for next time: what to do, why, and the two answers to
/// it. The reason is shown with the number — advice without its argument
/// is just an instruction.
class ProgressionCard extends StatelessWidget {
  const ProgressionCard({
    super.key,
    required this.planned,
    required this.suggestion,
    required this.onApply,
    required this.onSkip,
  });

  final PlannedExercise planned;
  final ProgressionSuggestion suggestion;
  final VoidCallback onApply;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final target = '${formatWeight(suggestion.targetWeightKg)} kg';
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  planned.exercise.name,
                  style: AppTextStyles.itemTitle,
                ),
              ),
              TagChip(label: _moveLabel(suggestion.move)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${formatWeight(planned.targetWeightKg)} kg → $target · '
            '${planned.sets} × ${suggestion.reps}',
            style: AppTextStyles.cardTitle,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(suggestion.reason, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: '維持原本',
                  isCompact: true,
                  onPressed: onSkip,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: PrimaryButton(
                  label: '套用',
                  isCompact: true,
                  onPressed: onApply,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _moveLabel(ProgressionMove move) => switch (move) {
    ProgressionMove.increase => '加重',
    ProgressionMove.hold => '維持',
    ProgressionMove.deload => '退一階',
  };
}

/// The suggestions for a template, or nothing at all: with no history
/// there is nothing to suggest, and an empty section says that better
/// than a card full of hedging.
class ProgressionSection extends StatefulWidget {
  const ProgressionSection({super.key, required this.routine});

  final Routine routine;

  @override
  State<ProgressionSection> createState() => _ProgressionSectionState();
}

class _ProgressionSectionState extends State<ProgressionSection> {
  /// Exercises the user has answered for, so an answered suggestion does
  /// not keep asking. Kept for the visit only: it is a reading of the
  /// records, not a decision worth storing.
  final _answered = <String>{};

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final suggestions = [
      for (final (planned, suggestion) in store.progressionSuggestions)
        if (!_answered.contains(planned.exercise.id) &&
            suggestion.changesWeight)
          (planned, suggestion),
    ];
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        Gutter(child: const SectionLabel('下次的建議')),
        for (final (planned, suggestion) in suggestions)
          Gutter(
            child: ProgressionCard(
              planned: planned,
              suggestion: suggestion,
              onApply: () {
                store.applySuggestion(planned, suggestion);
                setState(() => _answered.add(planned.exercise.id));
                showToast(
                  context,
                  '${planned.exercise.name} 改為 '
                  '${formatWeight(suggestion.targetWeightKg)} kg',
                  kind: ToastKind.success,
                );
              },
              onSkip: () => setState(() => _answered.add(planned.exercise.id)),
            ),
          ),
        Gutter(
          child: const Text(
            '建議只看你自己的紀錄：做滿計畫的組數與次數就加一階，連續沒做滿才退一階。',
            style: AppTextStyles.caption,
          ),
        ),
      ],
    );
  }
}
