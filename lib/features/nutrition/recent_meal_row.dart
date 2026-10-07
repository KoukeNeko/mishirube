import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../../l10n/l10n.dart';

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
    0 => context.l10n.todayAt(time: time),
    1 => context.l10n.yesterdayAt(time: time),
    _ => '${context.dates.compactMonthDay(at)} $time',
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
    this.onTap,
  });

  final RecentMeal meal;
  final String when;
  final VoidCallback onAdd;
  final VoidCallback onToggleFavorite;

  /// Opens the meal to choose how much of it, where [onAdd] logs it as it
  /// was.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return NavCard(
      title: meal.label,
      subtitle: when,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatKcalOrDash(meal.meal.kcal),
            style: AppTextStyles.bigNumber.copyWith(fontSize: 20),
          ),
          const SizedBox(width: AppSpacing.xs),
          SquareIconButton(
            icon: meal.meal.isFavorite ? Icons.star : Icons.star_border,
            tooltip: meal.meal.isFavorite
                ? context.l10n.removeFavorite
                : context.l10n.addFavorite,
            color: meal.meal.isFavorite
                ? AppColors.nutrition
                : AppColors.textSecondary,
            onPressed: onToggleFavorite,
          ),
          const SizedBox(width: AppSpacing.xs),
          SquareIconButton(
            icon: Icons.add,
            tooltip: context.l10n.addNamed(name: meal.label),
            color: AppColors.nutrition,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
