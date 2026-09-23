import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';

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
          Text('要把這道料理拆成 $count 筆獨立紀錄嗎？', style: AppTextStyles.pageTitle),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '拆開後每項成分各自成為一筆紀錄，可以單獨編輯、移到別餐或刪除，'
            '「${dish.name}」這一層就不存在了。',
            style: AppTextStyles.caption.copyWith(fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.lg),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _StructurePreview(
                    title: '現在',
                    lines: ['午餐', '└ ${dish.name}', '    └ $count 項成分'],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                Expanded(
                  child: _StructurePreview(
                    title: '拆開後',
                    tone: CardTone.nutrition,
                    lines: [
                      '午餐',
                      for (final component in dish.components.take(
                        _previewComponentCount,
                      ))
                        '├ ${component.name}',
                      '└ 其他 ${count - _previewComponentCount} 項',
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.undo, size: 18, color: AppColors.textSecondary),
              SizedBox(width: AppSpacing.xs),
              Expanded(child: Text('30 秒內可以復原。', style: AppTextStyles.caption)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ButtonPair(
            secondary: SecondaryButton(
              label: '取消',
              onPressed: () => Navigator.of(context).pop(false),
            ),
            primaryFlex: 2,
            primary: NutritionButton(
              label: '拆成獨立紀錄',
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
      padding: const EdgeInsets.all(AppSpacing.md),
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
