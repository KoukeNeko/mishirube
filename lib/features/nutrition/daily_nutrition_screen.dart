import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/engines/caffeine.dart';
import '../../backend/engines/nutrition_summary.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/motion.dart';
import '../../shared/widgets/widgets.dart';
import 'component_list.dart';
import 'food_search_screen.dart';
import 'meal_change_preview_screen.dart';
import 'meal_detail_screen.dart';
import 'meal_group_screen.dart';
import 'nutrition_target_screen.dart';
import 'nutrition_view_model.dart';
import 'split_dish_sheet.dart';
import '../../l10n/l10n.dart';

/// A heading here is as tall as a touch target, so those that carry a
/// link (変更, 佔比) sit as far above their group as those that do not.
const _headingHeight = 44.0;

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

  /// Whether each meal shows its share of the day's energy.
  bool _showsShare = false;

  /// The meals picked to put together, by [_keyOf]; null when not
  /// picking.
  Set<String>? _merging;

  /// What picks a meal: its group, or the record when it is on its own.
  static String _keyOf(List<MealEvent> meal) =>
      meal.first.groupId ?? meal.first.id;

  /// Puts the picked meals together as one, undoably: every item of each
  /// becomes an item of the one meal, under the name set on the preview
  /// first — a picked meal's own name to start from, blank for its items'.
  Future<void> _merge(List<List<MealEvent>> meals) async {
    final picked = _merging ?? const {};
    final chosen = [
      for (final meal in meals)
        if (picked.contains(_keyOf(meal))) meal,
    ];
    final items = [for (final meal in chosen) ...meal];
    // The earliest item's time and the first sitting named: where the
    // meal would start from on its own.
    final eatenAt = items
        .map((item) => _nutrition.eatenAtOf(item.id))
        .nonNulls
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final choice = await pushModalPage<MergeChoice>(
      context,
      MealChangePreviewScreen.merge(
        items: items,
        convention: _nutrition.convention,
        name:
            chosen
                .map((meal) => meal.first.groupId)
                .nonNulls
                .map(_nutrition.mealGroupName)
                .nonNulls
                .firstOrNull ??
            '',
        mealType: items.map((item) => item.mealType).nonNulls.firstOrNull,
        eatenAt: eatenAt,
        latest: _nutrition.now(),
      ),
    );
    if (choice == null || !mounted) return;
    final before = _nutrition.mergeMeals(
      items,
      name: choice.name,
      mealType: choice.mealType,
      // Left alone, each item keeps its own time.
      eatenAt: choice.eatenAt == eatenAt ? null : choice.eatenAt,
    );
    setState(() => _merging = null);
    ToastScope.read(context).showUndo(
      context.l10n.mergedCount(count: chosen.length),
      onUndo: () => _nutrition.unmergeMeals(before),
    );
  }

  /// Takes one item out of a meal and out of the day, undoably.
  void _removeItem(MealEvent item) {
    _nutrition.deleteMeals([item]);
    ToastScope.read(context).showUndo(
      context.l10n.removedNamed(name: item.name),
      onUndo: () => _nutrition.restoreMeals([item]),
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
    final l10n = context.l10n;
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
    toast.showUndo(
      l10n.splitDone,
      onUndo: () => _nutrition.undoSplit(snapshot),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _nutrition,
    builder: (context, _) => _page(context),
  );

  Widget _page(BuildContext context) {
    final day = _day;
    final meals = _nutrition.mealsOn(day);
    // Plain water has a page of its own; as a meal it would be a card
    // reading 0.
    final eaten = mealsOf([
      for (final meal in meals)
        if (!meal.isWater) meal,
    ]);
    final summary = _nutrition.summaryOf(day);
    final merging = _merging;
    final today = _dateOf(_nutrition.now());
    final targets = _nutrition.targetsOn(day);
    final convention = _nutrition.convention;
    final nutrients = summariseNutrients(meals, convention: convention);
    NutrientTotal? total(Nutrient nutrient) =>
        nutrients.where((total) => total.nutrient == nutrient).firstOrNull;
    // Each meal's share of what the day's meals add up to so far, for
    // each figure drawn as a bar above, in that bar's colour and order;
    // a figure the meal did not record, or the day holds none of, has
    // no share. Every meal has the same parts in the same places, so a
    // figure reads down the list as one column.
    final eatenDay = summariseDay([for (final meal in eaten) ...meal]);
    List<_Share> sharesOf(List<MealEvent> meal) {
      final own = summariseDay(meal);
      _Share share(
        String label,
        Color color,
        num part,
        num whole,
        int unseen,
      ) => (
        label: label,
        color: color,
        percent: switch (unseen == meal.length || whole <= 0
            ? 0
            : (part * 100 / whole).round()) {
          // A share that rounds to nothing is left empty.
          0 => null,
          final percent => percent,
        },
      );
      final salt = summariseNutrients(
        meal,
        convention: convention,
      ).where((total) => total.nutrient == convention.saltMeasure).firstOrNull;
      final l10n = context.l10n;
      return [
        share(
          convention.energyName(l10n),
          AppColors.nutrition,
          own.kcal,
          eatenDay.kcal,
          own.mealsWithoutFigures,
        ),
        convention.countsAvailableCarb
            ? share(
                convention.carbName(l10n),
                AppColors.macroCarb,
                own.availableCarbGrams,
                eatenDay.availableCarbGrams,
                own.mealsWithoutAvailableCarb,
              )
            : share(
                convention.carbName(l10n),
                AppColors.macroCarb,
                own.carbGrams,
                eatenDay.carbGrams,
                own.mealsWithoutCarb,
              ),
        share(
          convention.proteinName(l10n),
          AppColors.macroProtein,
          own.proteinGrams,
          eatenDay.proteinGrams,
          own.mealsWithoutProtein,
        ),
        share(
          convention.fatName(l10n),
          AppColors.macroFat,
          own.fatGrams,
          eatenDay.fatGrams,
          own.mealsWithoutFat,
        ),
        share(
          convention.fibreName(l10n),
          AppColors.macroFibre,
          own.fibreGrams,
          eatenDay.fibreGrams,
          own.mealsWithoutFibre,
        ),
        share(
          convention.nameOf(l10n, convention.saltMeasure),
          AppColors.body,
          salt?.amount ?? 0,
          total(convention.saltMeasure)?.amount ?? 0,
          salt == null ? meal.length : 0,
        ),
      ];
    }

    final showsShare = _showsShare && eaten.length > 1;

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
        title: context.l10n.moduleNutrition,
        subtitle: context.dates.dayWithWeekday(day),
        actions: [
          // Meals logged apart — a draft split item by item — can be put
          // back together.
          if (eaten.length > 1)
            HeaderAction(
              icon: merging == null ? Icons.call_merge : Icons.close,
              label: merging == null
                  ? context.l10n.mergeAction
                  : context.l10n.commonCancel,
              semanticLabel: merging == null
                  ? context.l10n.mergeEntries
                  : context.l10n.cancelMerge,
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
                    ? context.l10n.mergeIntoMeal
                    : context.l10n.mergeCountIntoMeal(count: merging.length),
                onPressed: merging.length < 2 ? null : () => _merge(eaten),
              ),
            ),
      children: [
        if (merging == null) ...[
          Gutter(
            child: _EnergyGroup(
              summary: summary,
              targets: targets,
              convention: convention,
              onTarget: () => pushPage(context, const NutritionTargetScreen()),
            ),
          ),
          Gutter(
            child: _IndicatorsGroup(
              convention: convention,
              carbPart: total(convention.carbPart),
              salt: total(convention.saltMeasure),
              saltMeasure: convention.saltMeasure,
              saltLimit: _nutrition.saltLimit,
              caffeineMg: day == today ? _nutrition.estimatedCaffeineMg : null,
            ),
          ),
        ],
        Gutter(
          child: CategoryGroup(
            headingHeight: _headingHeight,
            label: context.l10n.mealsSection,
            color: AppColors.nutrition,
            // A text action like 變更 above, naming what a tap does.
            tag: merging == null && eaten.length > 1
                ? LinkText(
                    label: showsShare
                        ? context.l10n.mealShareHide
                        : context.l10n.mealShare,
                    color: AppColors.nutrition,
                    alignment: Alignment.bottomRight,
                    onTap: () => setState(() => _showsShare = !_showsShare),
                  )
                : null,
            children: [
              SegmentedGroup(
                rows: [
                  if (eaten.isEmpty)
                    [
                      Segment(
                        child: SegmentRow(
                          leading: const Icon(
                            Icons.no_meals_outlined,
                            color: AppColors.textTertiary,
                          ),
                          title: context.l10n.noMealsThisDay,
                        ),
                      ),
                    ]
                  else
                    for (final meal in eaten)
                      [
                        if (merging != null)
                          Segment(
                            onTap: () => setState(() {
                              if (!merging.remove(_keyOf(meal))) {
                                merging.add(_keyOf(meal));
                              }
                            }),
                            child: Semantics(
                              selected: merging.contains(_keyOf(meal)),
                              child: SegmentRow(
                                leading: CheckSquare(
                                  isChecked: merging.contains(_keyOf(meal)),
                                  checkedColor: AppColors.nutrition,
                                ),
                                title: _nutrition.nameOfMeal(meal),
                                caption:
                                    '${meal.first.timeLabel} · '
                                    '${formatKcalOrDash(mealKcalOf(meal))} kcal',
                              ),
                            ),
                          )
                        else if (meal.length == 1)
                          Segment(
                            // The meal opens to what it was, as a list row
                            // does; its dishes open on their own.
                            onTap: () => pushPage(
                              context,
                              MealDetailScreen(meal: meal.single),
                            ),
                            child: _MealCard(
                              meal: meal.single,
                              shares: showsShare ? sharesOf(meal) : const [],
                              isExpanded: (dish) => _expanded.contains(
                                '${meal.single.id}/${dish.name}',
                              ),
                              onToggle: (dish) =>
                                  _toggle('${meal.single.id}/${dish.name}'),
                              onSplit: (dishIndex) =>
                                  _split(meal.single, dishIndex),
                            ),
                          )
                        else
                          Segment(
                            onTap: () =>
                                pushPage(context, MealGroupScreen(items: meal)),
                            child: _MealGroupCard(
                              items: meal,
                              shares: showsShare ? sharesOf(meal) : const [],
                              name: _nutrition.nameOfMeal(meal),
                              convention: convention,
                              onRemove: _removeItem,
                            ),
                          ),
                      ],
                ],
              ),
            ],
          ),
        ),
        // Sugar and salt are up with the day's limits, salt in one measure
        // with the other folded into it.
        if ([
              for (final total in nutrients)
                if (total.nutrient != convention.carbPart &&
                    total.nutrient != convention.saltMeasure &&
                    !convention.foldedAway.contains(total.nutrient))
                  total,
            ]
            case final rest when rest.isNotEmpty && merging == null)
          Gutter(
            child: _NutrientsGroup(totals: rest, convention: convention),
          ),
        // Logs to the day shown, as the training page's 新增課表 adds a
        // routine: another day is a swipe away on the strip above, and the
        // label says so.
        if (merging == null)
          Gutter(
            child: DashedActionCard(
              label: day == today
                  ? context.l10n.dockAddEntry
                  : context.l10n.addEntryToDay(
                      date: context.dates.monthDay(day),
                    ),
              color: AppColors.nutrition,
              onTap: () => pushPage(context, FoodSearchScreen(day: day)),
            ),
          ),
      ],
    );
  }
}

/// One figure's share of the day that a meal holds, in the colour that
/// figure's bar has above; null when it holds none.
typedef _Share = ({String label, Color color, int? percent});

/// A meal's shares of the day so far in one bar, drawn as the meal
/// page's [SegmentBar]: a part for each figure, filled to the meal's
/// share of it in the colour of that figure's bar above, which names it,
/// with the percent at the part's end, clear of the fill until the
/// share is large. The fills rise one after another as the bar opens.
class _MealShares extends StatelessWidget {
  const _MealShares({required this.shares});

  final List<_Share> shares;

  static const _height = 20.0;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(_height),
      child: SizedBox(
        height: _height,
        child: ChartEntrance(
          shows: [for (final share in shares) share.percent],
          builder: (context, drawn) => Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 2,
            children: [
              for (final (index, share) in shares.indexed)
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: AppColors.surfaceRaised),
                      if (share.percent case final percent?) ...[
                        FractionallySizedBox(
                          alignment: AlignmentDirectional.centerStart,
                          widthFactor:
                              (percent / 100).clamp(0.0, 1.0) *
                              staggeredProgress(drawn, index, shares.length),
                          child: ColoredBox(color: share.color),
                        ),
                        Semantics(
                          label: '${share.label} $percent%',
                          excludeSemantics: true,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                            ),
                            // Six parts share a card's width; a large text
                            // size shrinks to fit rather than overflowing.
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerEnd,
                              child: Text(
                                '$percent%',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Where a meal card's share bar opens and closes, growing rather than
/// jumping the cards below it.
class _SharesSlot extends StatelessWidget {
  const _SharesSlot({required this.shares});

  /// Empty while shares are not shown.
  final List<_Share> shares;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: chromeDuration(context, const Duration(milliseconds: 200)),
    curve: Curves.easeOut,
    alignment: Alignment.topCenter,
    child: shares.isEmpty
        ? const SizedBox(width: double.infinity)
        : _MealShares(shares: shares),
  );
}

/// A meal of several items: their sum at the top, then each item with
/// its own figures, which open to edit and swipe away.
class _MealGroupCard extends StatelessWidget {
  const _MealGroupCard({
    required this.items,
    required this.shares,
    required this.name,
    required this.convention,
    required this.onRemove,
  });

  final List<MealEvent> items;

  /// Its share of the day so far, per figure; empty when not shown.
  final List<_Share> shares;
  final String name;
  final NutritionConvention convention;
  final ValueChanged<MealEvent> onRemove;

  @override
  Widget build(BuildContext context) {
    final first = items.first;
    return Column(
      children: [
        // The meal opens to its sum, as a single meal's row does.
        Padding(
          padding: segmentPadding,
          child: Column(
            children: [
              Row(
                children: [
                  const AccentBar(color: AppColors.nutrition),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: AppTextStyles.itemTitle),
                        Text(
                          [
                            first.timeLabel,
                            ?first.mealType?.labelIn(context.l10n),
                            context.l10n.itemsCountShort(count: items.length),
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
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
              _SharesSlot(shares: shares),
            ],
          ),
        ),
        for (final item in items) ...[
          const Divider(
            height: 1,
            indent: AppSpacing.md,
            endIndent: AppSpacing.md,
          ),
          SwipeAction(
            key: ValueKey(item.id),
            label: context.l10n.removeAction,
            semanticLabel: context.l10n.removeNamed(name: item.name),
            radius: 0,
            onAction: () => onRemove(item),
            child: NavRow(
              title: item.name,
              // What it was first, when there is anything to say.
              subtitle: mealContentsOf(item).isEmpty
                  ? _macrosOf(context.l10n, item, convention)
                  : mealContentsOf(item).join(' · '),
              detail: mealContentsOf(item).isEmpty
                  ? null
                  : _macrosOf(context.l10n, item, convention),
              trailing: Text(
                '${formatKcalOrDash(item.kcal)} kcal',
                style: AppTextStyles.caption,
              ),
              showChevron: true,
              onTap: () => pushPage(context, MealDetailScreen(meal: item)),
            ),
          ),
        ],
      ],
    );
  }
}

/// `蛋白質 12 g · 碳水化合物 40 g · 脂肪 9 g`, in [convention]'s words,
/// a dash for a figure not known.
String _macrosOf(
  AppLocalizations l10n,
  MealEvent item,
  NutritionConvention convention,
) {
  String grams(double? value) =>
      value == null ? '—' : '${formatAmount(value)} g';
  return [
    '${convention.proteinName(l10n)} ${grams(item.proteinGrams)}',
    '${convention.carbName(l10n)} ${grams(item.carbGrams)}',
    '${convention.fatName(l10n)} ${grams(item.fatGrams)}',
  ].join(' · ');
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.meal,
    required this.shares,
    required this.isExpanded,
    required this.onToggle,
    required this.onSplit,
  });

  final MealEvent meal;

  /// Its share of the day so far, per figure; empty when not shown.
  final List<_Share> shares;
  final bool Function(DishEntry dish) isExpanded;
  final ValueChanged<DishEntry> onToggle;
  final ValueChanged<int> onSplit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: segmentPadding,
          child: Column(
            children: [
              Row(
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
                          [
                            meal.timeLabel,
                            if (meal.amount.isNotEmpty) meal.amount,
                          ].join(' · '),
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
              _SharesSlot(shares: shares),
            ],
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
                  child: Text(dish.name, style: AppTextStyles.itemTitle),
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
                      label: context.l10n.splitIntoEntry,
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
class _NutrientsGroup extends StatelessWidget {
  const _NutrientsGroup({required this.totals, required this.convention});

  final List<NutrientTotal> totals;
  final NutritionConvention convention;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CategoryGroup(
      headingHeight: _headingHeight,
      label: l10n.otherNutrients,
      color: AppColors.textSecondary,
      children: [
        SegmentedGroup(
          rows: [
            for (var i = 0; i < totals.length; i += 2)
              [
                for (final total in totals.skip(i).take(2))
                  Segment(
                    child: SegmentStat(
                      label: convention.nameOf(l10n, total.nutrient),
                      color: AppColors.textSecondary,
                      placeholder: '—',
                      value: total.labelIn(l10n),
                      valueSize: 18,
                    ),
                  ),
              ],
          ],
        ),
      ],
    );
  }
}

/// The day's energy against its target with what is left, and under it
/// the macronutrients and fibre against theirs, as the figures of 今天.
class _EnergyGroup extends StatelessWidget {
  const _EnergyGroup({
    required this.summary,
    required this.targets,
    required this.convention,
    required this.onTarget,
  });

  final NutritionConvention convention;
  final DaySummary summary;
  final NutritionTargets targets;
  final VoidCallback onTarget;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final target = targets.kcal;
    final eaten = summary.kcal;
    final mark = summary.hasEstimates ? '~' : '';
    final left = target == null ? null : target - eaten;
    Segment macro(String name, Color color, double grams, double? goal) =>
        Segment(
          child: SegmentStat(
            label: name,
            color: color,
            mark: segmentDot,
            placeholder: '—',
            value: goal == null
                ? formatAmount(grams)
                : '${formatAmount(grams)} / ${formatAmount(goal)}',
            unit: 'g',
            valueSize: 20,
            progress: goal != null && goal > 0 ? grams / goal : null,
          ),
        );
    return CategoryGroup(
      headingHeight: _headingHeight,
      label: convention.energyName(l10n),
      color: AppColors.nutrition,
      tag: LinkText(
        label: target == null ? l10n.setGoal : l10n.changeAction,
        color: AppColors.nutrition,
        alignment: Alignment.bottomRight,
        onTap: onTarget,
      ),
      children: [
        SegmentedGroup(
          rows: [
            [
              Segment(
                surface: AppColors.surfaceRaised,
                semanticLabel: target == null
                    ? l10n.eatenKcal(kcal: formatKcal(eaten))
                    : l10n.eatenOfTarget(
                        kcal: formatKcal(eaten),
                        target: formatKcal(target),
                      ),
                child: SegmentHero(
                  label: left == null
                      ? l10n.eatenKcalTitle
                      : left >= 0
                      ? l10n.remainingKcalTitle
                      : l10n.overKcalTitle,
                  color: AppColors.nutrition,
                  value: '$mark${formatKcal(left?.abs() ?? eaten)}',
                  unit: target == null
                      ? null
                      : '$mark${formatKcal(eaten)} / ${formatKcal(target)}',
                  progress: target == null || target <= 0
                      ? null
                      : eaten / target,
                ),
              ),
            ],
            [
              macro(
                convention.proteinName(l10n),
                AppColors.macroProtein,
                summary.proteinGrams,
                targets.proteinGrams?.toDouble(),
              ),
              macro(
                convention.carbName(l10n),
                AppColors.macroCarb,
                convention.countsAvailableCarb
                    ? summary.availableCarbGrams
                    : summary.carbGrams,
                targets.carbGrams?.toDouble(),
              ),
            ],
            [
              macro(
                convention.fatName(l10n),
                AppColors.macroFat,
                summary.fatGrams,
                targets.fatGrams?.toDouble(),
              ),
              macro(
                convention.fibreName(l10n),
                AppColors.macroFibre,
                summary.fibreGrams,
                targets.fibreGrams?.toDouble(),
              ),
            ],
          ],
        ),
        if (summary.mealsWithoutFigures > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              l10n.entriesWithoutKcal(count: summary.mealsWithoutFigures),
              style: AppTextStyles.caption,
            ),
          ),
      ],
    );
  }
}

/// The rest of the day at a glance: sugar (or 糖質) as eaten, salt against
/// its limit, and, today, the caffeine still in the body.
class _IndicatorsGroup extends StatelessWidget {
  const _IndicatorsGroup({
    required this.convention,
    required this.carbPart,
    required this.salt,
    required this.saltMeasure,
    required this.saltLimit,
    required this.caffeineMg,
  });

  final NutritionConvention convention;

  /// Sugar, or 糖質 read the Japanese way: [NutritionConvention.carbPart].
  final NutrientTotal? carbPart;

  /// Salt in [saltMeasure]: sodium in mg, or salt equivalent in g.
  final NutrientTotal? salt;
  final Nutrient saltMeasure;
  final double saltLimit;

  /// Null on a day other than today, which has no "still in the body".
  final double? caffeineMg;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final amount = salt?.amount;
    // Sodium to the mg, salt to a tenth of a gram, as labels print them.
    String figure(double value) => saltMeasure.unit == NutrientUnit.milligram
        ? formatKcal(value.round())
        : formatAmount((value * 10).round() / 10);
    return CategoryGroup(
      headingHeight: _headingHeight,
      label: l10n.dailyIndicators,
      color: AppColors.textSecondary,
      children: [
        SegmentedGroup(
          rows: [
            [
              Segment(
                child: SegmentStat(
                  label: convention.nameOf(l10n, convention.carbPart),
                  color: AppColors.nutrition,
                  mark: segmentDot,
                  placeholder: '—',
                  value: carbPart?.nutrient.format(
                    (carbPart!.amount * 10).round() / 10,
                  ),
                  valueSize: 20,
                  caption: carbPart?.isWorkedOut == true
                      ? l10n.workedOut
                      : null,
                ),
              ),
              Segment(
                child: SegmentStat(
                  label: convention.nameOf(l10n, saltMeasure),
                  color: AppColors.body,
                  mark: segmentDot,
                  placeholder: '—',
                  value:
                      '${amount == null ? '—' : figure(amount)}'
                      ' / ${figure(saltLimit)}',
                  unit: saltMeasure.unit.label,
                  valueSize: 20,
                  progress: amount == null ? null : amount / saltLimit,
                  caption: salt?.isWorkedOut == true ? l10n.workedOut : null,
                ),
              ),
            ],
            if (caffeineMg case final caffeine? when caffeine >= 1)
              [
                Segment(
                  child: SegmentStat(
                    label: l10n.caffeineRemaining,
                    color: AppColors.caffeine,
                    mark: segmentDot,
                    placeholder: '—',
                    value: '${caffeine.round()} mg',
                    valueSize: 20,
                    caption: l10n.halfLifeBasis(
                      hours: formatAmount(caffeineHalfLifeHours),
                    ),
                  ),
                ),
              ],
          ],
        ),
      ],
    );
  }
}
