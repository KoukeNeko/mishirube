import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/engines/caffeine.dart';
import '../../backend/engines/nutrition_summary.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'component_list.dart';
import 'meal_edit_screen.dart';
import 'nutrition_view_model.dart';
import 'split_dish_sheet.dart';

class DailyNutritionScreen extends StatefulWidget {
  const DailyNutritionScreen({super.key, this.day});

  /// Which day to show; today when null.
  final DateTime? day;

  @override
  State<DailyNutritionScreen> createState() => _DailyNutritionScreenState();
}

class _DailyNutritionScreenState extends State<DailyNutritionScreen> {
  late final NutritionViewModel _nutrition;

  @override
  void initState() {
    super.initState();
    _nutrition = NutritionViewModel(AppStoreScope.read(context).backend);
  }

  @override
  void dispose() {
    _nutrition.dispose();
    super.dispose();
  }

  /// Keys of expanded dishes (`mealId/dishName`); display-only state.
  final Set<String> _expanded = {};

  DateTime get _day => widget.day ?? AppStoreScope.read(context).now();

  void _toggle(String key) => setState(() {
    if (!_expanded.remove(key)) _expanded.add(key);
  });

  Future<void> _split(MealEvent meal, int dishIndex) async {
    final toast = ToastScope.read(context);
    final day = _day;
    final shouldSplit = await showSplitDishSheet(
      context,
      meal.dishes[dishIndex],
    );
    if (shouldSplit != true) return;
    final snapshot = _nutrition.splitDish(
      mealId: meal.id,
      dishIndex: dishIndex,
      day: day,
    );
    if (snapshot == null) return;
    toast.showUndo('已拆成獨立紀錄', onUndo: () => _nutrition.undoSplit(snapshot));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _nutrition,
    builder: (context, _) => _page(context),
  );

  Widget _page(BuildContext context) {
    final day = _day;
    final meals = _nutrition.mealsOn(day);
    final summary = _nutrition.summaryOf(day);
    return PageScaffold(
      appBar: PageAppBar(
        title: '飲食',
        subtitle: '${day.month} 月 ${day.day} 日（週${weekdayLabel(day)}）',
      ),
      footer: _DailyTotalBar(
        kcal: summary.kcal,
        mealCount: summary.mealCount,
        mealsWithoutFigures: summary.mealsWithoutFigures,
      ),
      children: [
        if (meals.isEmpty)
          Gutter(
            child: const EmptyStateCard(
              icon: Icons.no_meals_outlined,
              title: '這一天沒有記錄任何一餐',
            ),
          ),
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
        if (summariseFluid(meals) case final fluid when fluid.hasRecords) ...[
          Gutter(child: const SectionLabel('飲品')),
          Gutter(child: _FluidLogged(fluid: fluid)),
        ],
        if (_nutrition.estimatedCaffeineMg case final caffeine
            when caffeine >= 1)
          Gutter(child: _CaffeineEstimate(milligrams: caffeine)),
        if (summariseNutrients(meals) case final nutrients
            when nutrients.isNotEmpty) ...[
          Gutter(child: const SectionLabel('其他營養素')),
          Gutter(child: _NutrientTotals(totals: nutrients)),
        ],
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
                formatKcalOrDash(meal.kcal),
                style: AppTextStyles.bigNumber.copyWith(fontSize: 26),
              ),
              const SizedBox(width: AppSpacing.xs),
              SquareIconButton(
                icon: Icons.edit_outlined,
                tooltip: '編輯${meal.name}',
                color: AppColors.nutrition,
                size: 36,
                onPressed: () => pushPage(context, MealEditScreen(meal: meal)),
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
    required this.mealsWithoutFigures,
    required this.mealCount,
  });

  final int kcal;

  /// Meals logged without a calorie figure. The total is a floor while
  /// any of them is in the day.
  final int mealsWithoutFigures;
  final int mealCount;

  @override
  Widget build(BuildContext context) {
    final unknown = mealsWithoutFigures == 0
        ? ''
        : ' · $mealsWithoutFigures 餐沒有熱量';
    return BottomActionBar(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          StatBlock(
            value: '~${formatKcal(kcal)}',
            label: mealsWithoutFigures == 0 ? '今日合計' : '今日合計（至少）',
            valueStyle: AppTextStyles.hugeNumber,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '$mealCount 餐$unknown',
              textAlign: TextAlign.right,
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }
}

/// The day's other nutrients, each saying how much of the day it could
/// see. A nutrient nobody recorded is not listed at all — it would read
/// as zero, and zero is a claim this screen cannot make.
class _NutrientTotals extends StatelessWidget {
  const _NutrientTotals({required this.totals});

  final List<NutrientTotal> totals;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final total in totals)
            KeyValueRow(label: total.nutrient.label, value: total.label),
        ],
      ),
    );
  }
}

/// What was drunk today, as recorded.
///
/// There is no goal bar and no percentage. Every reference value for
/// daily water is either a population figure or, in the apps that show
/// one, a number nobody publishes the working for — and a goal with a
/// progress bar is exactly the design that pushes people to drink more
/// than they should.
class _FluidLogged extends StatelessWidget {
  const _FluidLogged({required this.fluid});

  final FluidLogged fluid;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          StatBlock(
            value: '${fluid.millilitres}',
            unit: 'mL',
            label: '今日已記錄',
            valueStyle: AppTextStyles.bigNumber,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '${fluid.drinkCount} 筆',
              textAlign: TextAlign.right,
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }
}

/// Roughly how much caffeine is still in the body.
///
/// Written as an estimate with its method attached, because that is what
/// it is: half-lives differ several-fold between people. There is
/// deliberately no bedtime threshold and no "you can still have another
/// X mg" — no such figure has been validated.
class _CaffeineEstimate extends StatelessWidget {
  const _CaffeineEstimate({required this.milligrams});

  final double milligrams;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatBlock(
                value: '${milligrams.round()}',
                unit: 'mg',
                label: '估計殘留咖啡因',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '依半衰期 $caffeineHalfLifeHours 小時推算',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
