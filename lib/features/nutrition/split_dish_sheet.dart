import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import '../../l10n/l10n.dart';

const _previewComponentCount = 2;

/// Asks before turning a dish into standalone entries; resolves to `true`
/// when the user confirms.
Future<bool?> showSplitDishSheet(BuildContext context, DishEntry dish) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (_) => _SplitDishSheet(dish: dish),
  );
}

class _SplitDishSheet extends StatelessWidget {
  const _SplitDishSheet({required this.dish});

  final DishEntry dish;

  @override
  Widget build(BuildContext context) {
    final count = dish.components.length;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.screenGutter,
        AppSpacing.screenGutter,
        AppSpacing.screenGutter + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.splitDishTitle(count: count),
            style: AppTextStyles.pageTitle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.l10n.splitDishMessage(dish: dish.name),
            style: AppTextStyles.caption.copyWith(fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.lg),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _StructurePreview(
                    title: context.l10n.nowLabel,
                    lines: [
                      context.l10n.mealTypeLunch,
                      '└ ${dish.name}',
                      '    └ ${context.l10n.componentsCount(count: count)}',
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                Expanded(
                  child: _StructurePreview(
                    title: context.l10n.afterSplit,
                    tone: CardTone.nutrition,
                    lines: [
                      context.l10n.mealTypeLunch,
                      for (final component in dish.components.take(
                        _previewComponentCount,
                      ))
                        '├ ${component.name}',
                      '└ ${context.l10n.otherCount(count: count - _previewComponentCount)}',
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.undo, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  context.l10n.undoWithin30s,
                  style: AppTextStyles.caption,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ButtonPair(
            secondary: SecondaryButton(
              label: context.l10n.commonCancel,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            primaryFlex: 2,
            primary: NutritionButton(
              label: context.l10n.splitIntoEntry,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _StructurePreview extends StatelessWidget {
  const _StructurePreview({
    required this.title,
    required this.lines,
    this.tone = CardTone.raised,
  });

  final String title;
  final List<String> lines;
  final CardTone tone;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      tone: tone,
      radius: AppRadius.small + 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.xs),
          for (final line in lines)
            Text(
              line,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
        ],
      ),
    );
  }
}
