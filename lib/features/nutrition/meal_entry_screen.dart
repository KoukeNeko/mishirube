import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'food_search_screen.dart';
import 'meal_confirm_screen.dart';

/// `昨天 12:40` for the last two days, `9/17 19:20` before that.
String _whenLabel(BuildContext context, DateTime at) {
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

/// "你吃了什麼？" — choose how to log a meal.
class MealEntryScreen extends StatelessWidget {
  const MealEntryScreen({super.key});

  void _logAgain(BuildContext context, RecentMeal recent) {
    AppStoreScope.read(context).copyMeal(recent.meal);
    showToast(context, '已記錄「${recent.label}」', kind: ToastKind.success);
  }

  void _toggleFavorite(BuildContext context, RecentMeal recent) {
    final isFavorite = !recent.meal.isFavorite;
    AppStoreScope.read(context)
        .setMealFavorite(recent.meal, isFavorite: isFavorite);
    showToast(context, isFavorite ? '已加入常用' : '已從常用移除');
  }

  @override
  Widget build(BuildContext context) {
    return DetailPage(
      appBar: const PageAppBar(
        title: '吃了或喝了什麼？',
        subtitle: '午餐 · 9 月 19 日 12:35',
      ),
      children: [
        Gutter(
          child: _MethodCard(
            icon: Icons.photo_camera_outlined,
            title: '拍照',
            subtitle: '辨識料理與成分，確認後才存入',
            isPrimary: true,
            onTap: () => pushPage(context, const MealConfirmScreen()),
          ),
        ),
        Gutter(
          child: _MethodCard(
            icon: Icons.mic_none,
            title: '說出來',
            subtitle: '「牛肉麵一碗，湯喝一半」',
            onTap: () => pushPage(context, const MealConfirmScreen()),
          ),
        ),
        Gutter(
          child: _MethodCard(
            icon: Icons.search,
            title: '搜尋或輸入',
            subtitle: '你自己存的食物和飲料',
            onTap: () => pushPage(context, const FoodSearchScreen()),
          ),
        ),
        if (AppStoreScope.of(context).favoriteMeals case final favorites
            when favorites.isNotEmpty) ...[
          Gutter(child: const SectionLabel('常用')),
          for (final favorite in favorites)
            Gutter(
              child: _RecentFoodRow(
                meal: favorite,
                when: _whenLabel(context, favorite.eatenAt),
                onAdd: () => _logAgain(context, favorite),
                onToggleFavorite: () => _toggleFavorite(context, favorite),
              ),
            ),
        ],
        Gutter(child: const SectionLabel('最近吃過')),
        for (final recent in AppStoreScope.of(context).recentMeals)
          Gutter(
            child: _RecentFoodRow(
              meal: recent,
              when: _whenLabel(context, recent.eatenAt),
              onAdd: () => _logAgain(context, recent),
              onToggleFavorite: () => _toggleFavorite(context, recent),
            ),
          ),
        Gutter(
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final label in const ['掃條碼', '餐點模板', '從網址匯入食譜'])
                ChipButton(
                  label: label,
                  onTap: () => showToast(context, '「$label」尚未設計'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isPrimary = false,
  });

  static const _iconBoxSize = 52.0;

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      tone: isPrimary ? CardTone.nutrition : CardTone.neutral,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: _iconBoxSize,
            height: _iconBoxSize,
            decoration: BoxDecoration(
              color: isPrimary ? AppColors.nutrition : AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.small + 2),
            ),
            child: Icon(
              icon,
              color: isPrimary ? AppColors.textPrimary : AppColors.nutrition,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.pageTitle.copyWith(fontSize: 19),
                ),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentFoodRow extends StatelessWidget {
  const _RecentFoodRow({
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
            '${meal.meal.isEstimated ? '~' : ''}'
            '${formatKcalOrDash(meal.meal.kcal)}',
            style: AppTextStyles.bigNumber.copyWith(fontSize: 20),
          ),
          const SizedBox(width: AppSpacing.xs),
          SquareIconButton(
            icon: meal.meal.isFavorite ? Icons.star : Icons.star_border,
            tooltip: meal.meal.isFavorite ? '從常用移除' : '加入常用',
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
