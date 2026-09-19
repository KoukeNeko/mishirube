import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'component_list.dart';
import 'split_dish_sheet.dart';

class DailyNutritionScreen extends StatefulWidget {
  const DailyNutritionScreen({super.key});

  @override
  State<DailyNutritionScreen> createState() => _DailyNutritionScreenState();
}

class _DailyNutritionScreenState extends State<DailyNutritionScreen> {
  /// Keys of expanded dishes (`mealId/dishName`); display-only state.
  final Set<String> _expanded = {'lunch/${MockNutrition.sandwich.name}'};

  void _toggle(String key) => setState(() {
    if (!_expanded.remove(key)) _expanded.add(key);
  });

  Future<void> _split(MealEvent meal, int dishIndex) async {
    final store = AppStoreScope.read(context);
    final toast = ToastScope.read(context);
    final shouldSplit = await showSplitDishSheet(
      context,
      meal.dishes[dishIndex],
    );
    if (shouldSplit != true) return;
    final snapshot = store.splitDish(mealId: meal.id, dishIndex: dishIndex);
    if (snapshot == null) return;
    toast.showUndo('已拆成獨立紀錄', onUndo: () => store.undoSplit(snapshot));
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final meals = store.todayMeals;
    return PageScaffold(
      appBar: const PageAppBar(title: '飲食', subtitle: '9 月 19 日（週六）'),
      footer: _DailyTotalBar(
        kcal: store.todayKcal,
        mealCount: meals.length,
        isLunchLogged: store.isLunchLogged,
      ),
      children: [
        for (final meal in meals)
          Gutter(
            child: _MealCard(
              meal: meal,
              isExpanded: (dish) =>
                  _expanded.contains('${meal.id}/${dish.name}'),
              onToggle: (dish) => _toggle('${meal.id}/${dish.name}'),
              onSplit: (dishIndex) => _split(meal, dishIndex),
            ),
          ),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.meal,
    required this.isExpanded,
    required this.onToggle,
    required this.onSplit,
  });

  final MealEvent meal;
  final bool Function(DishEntry dish) isExpanded;
  final ValueChanged<DishEntry> onToggle;
  final ValueChanged<int> onSplit;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AccentBar(color: AppColors.nutrition),
              const SizedBox(width: AppSpacing.sm),
              Text(
                meal.name,
                style: AppTextStyles.pageTitle.copyWith(fontSize: 19),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(meal.timeLabel, style: AppTextStyles.caption),
              const Spacer(),
              Text(
                '~${meal.kcal}',
                style: AppTextStyles.bigNumber.copyWith(fontSize: 26),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TagChip(label: meal.qualityTag, tone: TagTone.nutrition),
          for (var i = 0; i < meal.dishes.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _DishRow(
              dish: meal.dishes[i],
              isExpanded: isExpanded(meal.dishes[i]),
              onToggle: () => onToggle(meal.dishes[i]),
              onSplit: () => onSplit(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _DishRow extends StatelessWidget {
  const _DishRow({
    required this.dish,
    required this.isExpanded,
    required this.onToggle,
    required this.onSplit,
  });

  final DishEntry dish;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onSplit;

  @override
  Widget build(BuildContext context) {
    final canExpand = dish.isComposite;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: canExpand ? onToggle : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dish.name, style: AppTextStyles.itemTitle),
                      Text(dish.subtitle, style: AppTextStyles.caption),
                    ],
                  ),
                ),
                Text(
                  dish.quantityLabel,
                  style: AppTextStyles.bigNumber.copyWith(fontSize: 18),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: canExpand
                      ? AppColors.textSecondary
                      : Colors.transparent,
                ),
              ],
            ),
          ),
        ),
        if (canExpand && isExpanded) ...[
          ComponentList(components: dish.components),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              ChipButton(
                label: '拆成獨立紀錄',
                tone: TagTone.nutrition,
                onTap: onSplit,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Text('展開只改變顯示', style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _DailyTotalBar extends StatelessWidget {
  const _DailyTotalBar({
    required this.kcal,
    required this.mealCount,
    required this.isLunchLogged,
  });

  final int kcal;
  final int mealCount;
  final bool isLunchLogged;

  @override
  Widget build(BuildContext context) {
    final pending = isLunchLogged ? '晚餐未記錄' : '午餐、晚餐未記錄';
    return BottomActionBar(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          StatBlock(
            value: '~${formatKcal(kcal)}',
            label: '今日合計',
            valueStyle: AppTextStyles.hugeNumber,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '$mealCount 餐 · $pending',
              textAlign: TextAlign.right,
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }
}
