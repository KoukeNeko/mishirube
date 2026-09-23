import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';

/// `昨天 12:40` for the last two days, `9/17 19:20` before that.
String mealWhenLabel(BuildContext context, DateTime at) {
  final today = AppStoreScope.read(context).now();
  final days = DateTime(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime(at.year, at.month, at.day)).inDays;
  final time = formatTimeOfDay(at);
  return switch (days) {
    0 => '今天 $time',
    1 => '昨天 $time',
    _ => '${at.month}/${at.day} $time',
  };
}

/// A meal eaten before, offered for logging again.
///
/// It lives beside the search field rather than on a menu of its own:
/// what someone ate yesterday is the answer to the search they were
/// about to type, not a separate feature.
class RecentMealRow extends StatelessWidget {
  const RecentMealRow({
    super.key,
    required this.meal,
    required this.when,
    required this.onAdd,
    required this.onToggleFavorite,
  });

  final RecentMeal meal;
  final String when;
  final VoidCallback onAdd;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      radius: AppRadius.small + 4,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meal.label, style: AppTextStyles.itemTitle),
                Text(when, style: AppTextStyles.caption),
              ],
            ),
          ),
          Text(
            formatKcalOrDash(meal.meal.kcal),
            style: AppTextStyles.bigNumber.copyWith(fontSize: 20),
          ),
          const SizedBox(width: AppSpacing.xs),
          SquareIconButton(
            icon: meal.meal.isFavorite ? Icons.star : Icons.star_border,
            tooltip: meal.meal.isFavorite ? '取消收藏' : '加入收藏',
            color: meal.meal.isFavorite
                ? AppColors.nutrition
                : AppColors.textSecondary,
            onPressed: onToggleFavorite,
          ),
          const SizedBox(width: AppSpacing.xs),
          SquareIconButton(
            icon: Icons.add,
            tooltip: '加入${meal.label}',
            color: AppColors.nutrition,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
