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
import 'food_search_screen.dart';
import 'meal_detail_screen.dart';
import 'meal_group_screen.dart';
import 'nutrition_target_screen.dart';
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

  /// The meals picked to put together, by [_keyOf]; null when not
  /// picking.
  Set<String>? _merging;

  /// What picks a meal: its group, or the record when it is on its own.
  static String _keyOf(List<MealEvent> meal) =>
      meal.first.groupId ?? meal.first.id;

  /// Puts the picked meals together as one, undoably: every item of each
  /// becomes an item of the one meal.
  void _merge(List<List<MealEvent>> meals) {
    final picked = _merging ?? const {};
    final chosen = [
      for (final meal in meals)
        if (picked.contains(_keyOf(meal))) meal,
    ];
    final previous = _nutrition.groupMeals([
      for (final meal in chosen) ...meal,
    ]);
    setState(() => _merging = null);
    ToastScope.read(context).showUndo(
      '已合併 ${chosen.length} 筆',
      onUndo: () => _nutrition.regroupMeals(previous),
    );
  }

  /// Takes one item out of a meal and out of the day, undoably.
  void _removeItem(MealEvent item) {
    _nutrition.deleteMeals([item]);
    ToastScope.read(context).showUndo(
      '已移除「${item.name}」',
      onUndo: () => _nutrition.restoreMeals([item]),
    );
  }

  /// Takes a glass of water back out of the day.
  void _removeWater(MealEvent glass) {
    _nutrition.deleteMeals([glass]);
    ToastScope.read(context).showUndo(
      '已移除 ${glass.millilitres} mL 的水',
      onUndo: () => _nutrition.restoreMeals([glass]),
    );
  }

  /// The day shown: the one opened, then whichever the strip picks.
  late DateTime _day = _dateOf(widget.day ?? AppStoreScope.read(context).now());

  static DateTime _dateOf(DateTime time) =>
      DateTime(time.year, time.month, time.day);

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
    // Plain water is counted under 飲品 below; as a meal it would be a
    // card reading 0.
    final eaten = mealsOf([
      for (final meal in meals)
        if (!meal.isWater) meal,
    ]);
    final summary = _nutrition.summaryOf(day);
    final merging = _merging;
    final water = [
      for (final meal in meals)
        if (meal.isWater) meal,
    ];
    final today = _dateOf(_nutrition.now());
    final targets = _nutrition.targetsOn(day);
    final nutrients = summariseNutrients(meals);
    NutrientTotal? total(Nutrient nutrient) =>
        nutrients.where((total) => total.nutrient == nutrient).firstOrNull;
    return PageScaffold(
      // Any day is a swipe away, the way a calendar's week header works.
      pinned: WeekDayStrip(
        selected: day,
        latest: today,
        firstWeekday: AppStoreScope.of(context).firstWeekday,
        color: AppColors.nutrition,
        markedDays: _nutrition.daysWithMeals([
          for (var back = -35; back <= 35; back++)
            DateTime(day.year, day.month, day.day + back),
        ]),
        onSelected: (picked) => setState(() {
          _day = picked;
          _merging = null;
        }),
      ),
      pinnedHeight: WeekDayStrip.pinnedHeightOf(context),
      appBar: PageAppBar(
        title: '飲食',
        subtitle: '${day.month} 月 ${day.day} 日（週${weekdayLabel(day)}）',
        actions: [
          // Meals logged apart — a draft split item by item — can be put
          // back together.
          if (eaten.length > 1)
            HeaderAction(
              icon: merging == null ? Icons.call_merge : Icons.close,
              label: merging == null ? '合併' : '取消',
              semanticLabel: merging == null ? '合併幾筆紀錄' : '取消合併',
              onTap: () => setState(
                () => _merging = merging == null ? <String>{} : null,
              ),
            ),
        ],
      ),
      footer: merging == null
          ? null
          : BottomActionBar(
              child: PrimaryButton(
                label: merging.length < 2
                    ? '合併成一餐'
                    : '合併 ${merging.length} 筆成一餐',
                onPressed: merging.length < 2 ? null : () => _merge(eaten),
              ),
            ),
      children: [
        if (merging == null) ...[
          Gutter(
            child: SectionLabel(
              MacroLabel.energy,
              trailing: LinkText(
                label: targets.kcal == null ? '設定目標' : '變更',
                color: AppColors.nutrition,
                alignment: Alignment.bottomRight,
                onTap: () => pushPage(context, const NutritionTargetScreen()),
              ),
            ),
          ),
          Gutter(
            child: _EnergyCard(summary: summary, targets: targets),
          ),
          Gutter(child: const SectionLabel('每日指標')),
          Gutter(
            child: _IndicatorsCard(
              fibreGrams: summary.fibreGrams,
              fibreTarget: targets.fibreGrams,
              sugar: total(Nutrient.sugar),
              sodium: total(Nutrient.sodium),
              fluid: summariseFluid(meals),
              caffeineMg: day == today ? _nutrition.estimatedCaffeineMg : null,
            ),
          ),
          Gutter(
            child: SectionLabel(
              '餐點',
              trailing: Text(
                '${summary.mealCount} 餐',
                style: AppTextStyles.caption,
              ),
            ),
          ),
        ],
        if (eaten.isEmpty)
          Gutter(
            child: const EmptyStateCard(
              icon: Icons.no_meals_outlined,
              title: '這一天沒有記錄任何一餐',
            ),
          ),
        if (merging != null)
          for (final meal in eaten)
            Gutter(
              child: Semantics(
                selected: merging.contains(_keyOf(meal)),
                child: NavCard(
                  leading: CheckSquare(
                    isChecked: merging.contains(_keyOf(meal)),
                    checkedColor: AppColors.nutrition,
                  ),
                  title: _nameOf(meal),
                  subtitle:
                      '${meal.first.timeLabel} · '
                      '${formatKcalOrDash(mealKcalOf(meal))} kcal',
                  showChevron: false,
                  onTap: () => setState(() {
                    if (!merging.remove(_keyOf(meal))) {
                      merging.add(_keyOf(meal));
                    }
                  }),
                ),
              ),
            )
        else
          for (final meal in eaten)
            Gutter(
              child: meal.length == 1
                  ? _MealCard(
                      meal: meal.single,
                      isExpanded: (dish) =>
                          _expanded.contains('${meal.single.id}/${dish.name}'),
                      onToggle: (dish) =>
                          _toggle('${meal.single.id}/${dish.name}'),
                      onSplit: (dishIndex) => _split(meal.single, dishIndex),
                    )
                  : _MealGroupCard(items: meal, onRemove: _removeItem),
            ),
        if (water.isNotEmpty && merging == null) ...[
          Gutter(child: const SectionLabel('水')),
          for (final glass in water)
            Gutter(
              child: SwipeAction(
                key: ValueKey(glass.id),
                label: '移除',
                semanticLabel: '移除 ${glass.timeLabel} 的水',
                onAction: () => _removeWater(glass),
                child: NavCard(
                  title: '水',
                  subtitle: '${glass.timeLabel} · ${glass.millilitres} mL',
                  onTap: () => pushPage(context, MealDetailScreen(meal: glass)),
                ),
              ),
            ),
        ],
        // Sugar and sodium are up with the day's limits.
        if ([
              for (final total in nutrients)
                if (total.nutrient != Nutrient.sugar &&
                    total.nutrient != Nutrient.sodium)
                  total,
            ]
            case final rest when rest.isNotEmpty && merging == null) ...[
          Gutter(child: const SectionLabel('其他營養素')),
          Gutter(child: _NutrientTotals(totals: rest)),
        ],
        // Logs to the day shown, as the training page's 新增課表 adds a
        // routine: another day is a swipe away on the strip above.
        if (merging == null)
          Gutter(
            child: DashedActionCard(
              label: '新增紀錄',
              color: AppColors.nutrition,
              onTap: () => pushPage(context, FoodSearchScreen(day: day)),
            ),
          ),
      ],
    );
  }
}

/// A meal's name: its items' names, one after another.
String _nameOf(List<MealEvent> meal) => meal.map((item) => item.name).join('、');

/// A meal of several items: their sum at the top, then each item with
/// its own figures, which open to edit and swipe away.
class _MealGroupCard extends StatelessWidget {
  const _MealGroupCard({required this.items, required this.onRemove});

  final List<MealEvent> items;
  final ValueChanged<MealEvent> onRemove;

  @override
  Widget build(BuildContext context) {
    final first = items.first;
    return GroupedCard(
      children: [
        // The meal opens to its sum, as a single meal's row does.
        InkWell(
          onTap: () => pushPage(context, MealGroupScreen(items: items)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                const AccentBar(color: AppColors.nutrition),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_nameOf(items), style: AppTextStyles.itemTitle),
                      Text(
                        [
                          first.timeLabel,
                          ?first.mealType?.label,
                          '${items.length} 項',
                        ].join(' · '),
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                ValueWithUnit(
                  value: formatKcalOrDash(mealKcalOf(items)),
                  unit: 'kcal',
                  style: AppTextStyles.bigNumber.copyWith(fontSize: 22),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
        for (final item in items)
          SwipeAction(
            key: ValueKey(item.id),
            label: '移除',
            semanticLabel: '移除「${item.name}」',
            radius: 0,
            onAction: () => onRemove(item),
            child: NavRow(
              title: item.name,
              subtitle: _macrosOf(item),
              trailing: Text(
                '${formatKcalOrDash(item.kcal)} kcal',
                style: AppTextStyles.caption,
              ),
              showChevron: true,
              onTap: () => pushPage(context, MealDetailScreen(meal: item)),
            ),
          ),
      ],
    );
  }
}

/// `蛋白質 12 g · 碳水化合物 40 g · 脂肪 9 g`, a dash for a figure not
/// known.
String _macrosOf(MealEvent item) {
  String grams(int? value) => value == null ? '—' : '$value g';
  return [
    '${MacroLabel.protein} ${grams(item.proteinGrams)}',
    '${MacroLabel.carb} ${grams(item.carbGrams)}',
    '${MacroLabel.fat} ${grams(item.fatGrams)}',
  ].join(' · ');
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
    // No padding on the card: each row that can be pressed pads itself,
    // so its highlight reaches the card's edges.
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The meal opens to what it was, as a list row does.
          InkWell(
            onTap: () => pushPage(context, MealDetailScreen(meal: meal)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  const AccentBar(color: AppColors.nutrition),
                  const SizedBox(width: AppSpacing.sm),
                  // The name takes the row and wraps; the time goes under
                  // it so a long name is not squeezed into a column.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(meal.name, style: AppTextStyles.itemTitle),
                        Text(
                          '${meal.timeLabel} · ${meal.qualityTag}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ValueWithUnit(
                    value: formatKcalOrDash(meal.kcal),
                    unit: 'kcal',
                    style: AppTextStyles.bigNumber.copyWith(fontSize: 22),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
          for (var i = 0; i < meal.dishes.length; i++) ...[
            const Divider(
              height: 1,
              indent: AppSpacing.md,
              endIndent: AppSpacing.md,
            ),
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
            padding: const EdgeInsets.all(AppSpacing.md),
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
        if (canExpand && isExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
              ],
            ),
          ),
      ],
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

/// The day's energy against its target, as a ring with what is left,
/// and the three macronutrients against theirs.
class _EnergyCard extends StatelessWidget {
  const _EnergyCard({required this.summary, required this.targets});

  final DaySummary summary;
  final NutritionTargets targets;

  @override
  Widget build(BuildContext context) {
    final target = targets.kcal;
    final eaten = summary.kcal;
    final mark = summary.hasEstimates ? '~' : '';
    final left = target == null ? null : target - eaten;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (summary.mealsWithoutFigures > 0) ...[
            Text(
              '${summary.mealsWithoutFigures} 筆沒有熱量，實際更多',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          LayoutBuilder(
            builder: (context, space) {
              // Side by side where there is room; the ring above the
              // macros at large text sizes.
              final isWide = space.maxWidth >= 300;
              final color = left != null && left < 0
                  ? AppColors.warning
                  : AppColors.nutrition;
              final ring = ProgressRing(
                progress: target == null || target <= 0 ? 0 : eaten / target,
                color: color,
                semanticLabel: target == null
                    ? '已吃 ${formatKcal(eaten)} kcal'
                    : '已吃 ${formatKcal(eaten)} kcal，目標 ${formatKcal(target)} kcal',
                size: 148,
                strokeWidth: 18,
                title: left == null
                    ? '已吃 kcal'
                    : left >= 0
                    ? '剩餘 kcal'
                    : '超過 kcal',
                footer: target == null
                    ? null
                    : '$mark${formatKcal(eaten)}/${formatKcal(target)}',
                child: Text(
                  '$mark${formatKcal(left?.abs() ?? eaten)}',
                  style: AppTextStyles.bigNumber.copyWith(fontSize: 28),
                ),
              );
              final macros = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MacroLine(
                    label: MacroLabel.carb,
                    color: AppColors.macroCarb,
                    grams: summary.carbGrams,
                    target: targets.carbGrams,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _MacroLine(
                    label: MacroLabel.protein,
                    color: AppColors.macroProtein,
                    grams: summary.proteinGrams,
                    target: targets.proteinGrams,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _MacroLine(
                    label: MacroLabel.fat,
                    color: AppColors.macroFat,
                    grams: summary.fatGrams,
                    target: targets.fatGrams,
                  ),
                ],
              );
              return isWide
                  ? Row(
                      children: [
                        ring,
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(child: macros),
                      ],
                    )
                  : Column(
                      children: [
                        ring,
                        const SizedBox(height: AppSpacing.md),
                        macros,
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }
}

class _MacroLine extends StatelessWidget {
  const _MacroLine({
    required this.label,
    required this.color,
    required this.grams,
    required this.target,
  });

  final String label;
  final Color color;
  final int grams;
  final int? target;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(child: Text(label, style: AppTextStyles.caption)),
        ],
      ),
      Text(
        target == null ? '$grams g' : '$grams / $target g',
        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
      ),
      if (target case final target? when target > 0) ...[
        const SizedBox(height: AppSpacing.xxs),
        ProgressLine(progress: grams / target, color: color, height: 6),
      ],
    ],
  );
}

/// The rest of the day at a glance, one row each: fibre against its
/// target, sugar as eaten, sodium against its limit, what was drunk,
/// and, today, the caffeine still in the body.
class _IndicatorsCard extends StatelessWidget {
  const _IndicatorsCard({
    required this.fibreGrams,
    required this.fibreTarget,
    required this.sugar,
    required this.sodium,
    required this.fluid,
    required this.caffeineMg,
  });

  final int fibreGrams;
  final int? fibreTarget;
  final NutrientTotal? sugar;
  final NutrientTotal? sodium;
  final FluidLogged fluid;

  /// Null on a day other than today, which has no "still in the body".
  final double? caffeineMg;

  @override
  Widget build(BuildContext context) {
    const limit = NutritionTargets.sodiumLimitMg;
    final sodiumMg = sodium?.amount;
    final rows = [
      _MeterRow(
        label: MacroLabel.fibre,
        value: fibreTarget == null
            ? '$fibreGrams g'
            : '$fibreGrams / $fibreTarget g',
        progress: fibreTarget == null || fibreTarget == 0
            ? null
            : fibreGrams / fibreTarget!,
        color: AppColors.macroFibre,
      ),
      _MeterRow(
        label: Nutrient.sugar.label,
        value: sugar == null ? '—' : Nutrient.sugar.format(sugar!.amount),
      ),
      _MeterRow(
        label: Nutrient.sodium.label,
        value:
            '${sodiumMg == null ? '—' : formatKcal(sodiumMg.round())}'
            ' / ${formatKcal(limit)} mg',
        progress: sodiumMg == null ? null : sodiumMg / limit,
        color: (sodiumMg ?? 0) > limit ? AppColors.warning : AppColors.body,
      ),
      _MeterRow(
        label: '飲水',
        value: fluid.hasRecords
            ? '${formatKcal(fluid.millilitres)} mL · ${fluid.drinkCount} 筆'
            : '—',
      ),
      if (caffeineMg case final caffeine? when caffeine >= 1)
        _MeterRow(
          label: '估計殘留咖啡因',
          value: '${caffeine.round()} mg',
          note: '依半衰期 $caffeineHalfLifeHours 小時推算',
        ),
    ];
    // Space between the rows only, so the first and last sit the card's
    // own inset from its edge, as every other card's content does.
    return AppCard(
      child: Column(
        children: [
          for (final (index, row) in rows.indexed) ...[
            if (index > 0) const SizedBox(height: AppSpacing.sm),
            row,
          ],
        ],
      ),
    );
  }
}

/// A label, its value on the right, and a bar under them when there is
/// something to measure it against. Every row the same height, so the
/// card reads as one list.
class _MeterRow extends StatelessWidget {
  const _MeterRow({
    required this.label,
    required this.value,
    this.progress,
    this.color = AppColors.nutrition,
    this.note,
  });

  final String label;
  final String value;
  final double? progress;
  final Color color;
  final String? note;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.body)),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      if (note case final note?) Text(note, style: AppTextStyles.caption),
      if (progress case final progress?) ...[
        const SizedBox(height: AppSpacing.xxs),
        ProgressLine(progress: progress, color: color, height: 4),
      ],
    ],
  );
}
