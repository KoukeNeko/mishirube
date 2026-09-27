import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/engines/nutrition_summary.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'meal_detail_screen.dart';
import 'nutrition_view_model.dart';
import '../../l10n/l10n.dart';

/// A meal of several items as one: their sum at the top, as a single
/// meal's page shows its own, then each item, which opens to its page.
/// Taking the meal apart is here, not on the day's list.
class MealGroupScreen extends StatefulWidget {
  const MealGroupScreen({super.key, required this.items});

  /// The items as the day's page had them; the page reads them again,
  /// so an item corrected from here shows its new figures.
  final List<MealEvent> items;

  @override
  State<MealGroupScreen> createState() => _MealGroupScreenState();
}

class _MealGroupScreenState extends State<MealGroupScreen> {
  late final _nutrition = NutritionViewModel(
    AppStoreScope.read(context).backend,
  );

  @override
  void dispose() {
    _nutrition.dispose();
    super.dispose();
  }

  /// Takes the meal apart into its items, undoably, and leaves: there is
  /// no meal left to show.
  void _ungroup(List<MealEvent> items) {
    final toast = ToastScope.read(context);
    final previous = _nutrition.ungroupMeals(items);
    Navigator.of(context).pop();
    toast.showUndo(
      context.l10n.splitIntoCount(count: items.length),
      onUndo: () => _nutrition.regroupMeals(previous),
    );
  }

  /// Blank calls the meal by its items again, which the field shows.
  Future<void> _rename(String groupId, List<MealEvent> items) async {
    final typed = await showTextDialog(
      context,
      title: context.l10n.nameSection,
      initial: _nutrition.mealGroupName(groupId) ?? '',
      hint: mealNameOf(items),
    );
    if (typed == null || !mounted) return;
    _nutrition.nameMealGroup(groupId, typed);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _nutrition,
    builder: (context, _) {
      final groupId = widget.items.first.groupId;
      final items = groupId == null
          ? widget.items
          : _nutrition.mealGroup(groupId);
      return _page(items.isEmpty ? widget.items : items);
    },
  );

  Widget _page(List<MealEvent> items) {
    final total = mealTotal(items, name: _nutrition.nameOfMeal(items));
    final groupId = items.first.groupId;
    final eatenAt = _nutrition.eatenAtOf(items.first.id);
    final convention = _nutrition.convention;
    final nutrients = [
      for (final nutrient in summariseNutrients(items, convention: convention))
        if (!energyNutrients.contains(nutrient.nutrient) &&
            !convention.foldedAway.contains(nutrient.nutrient))
          nutrient,
    ];
    return DetailPage(
      appBar: PageAppBar(
        title: total.name,
        subtitle: eatenAt == null
            ? total.timeLabel
            : '${context.dates.dayWithWeekday(eatenAt)} · ${total.timeLabel}',
      ),
      children: [
        Gutter(
          child: MealSummaryCard(
            meal: total,
            convention: convention,
            details: [
              ?total.mealType?.labelIn(context.l10n),
              context.l10n.itemsCountShort(count: items.length),
            ],
          ),
        ),
        if (nutrients.isNotEmpty)
          PageSection(
            label: context.l10n.nutrientsSection,
            children: [
              Gutter(
                child: GroupedCard(
                  children: [
                    for (final nutrient in nutrients)
                      KeyValueRow(
                        label: convention.nameOf(
                          context.l10n,
                          nutrient.nutrient,
                        ),
                        value: nutrient.labelIn(context.l10n),
                      ),
                  ],
                ),
              ),
            ],
          ),
        PageSection(
          label: context.l10n.contentsSection,
          children: [
            Gutter(
              child: GroupedCard(
                children: [
                  for (final item in items)
                    NavRow(
                      title: item.name,
                      trailing: Text(
                        '${formatKcalOrDash(item.kcal)} kcal',
                        style: AppTextStyles.caption,
                      ),
                      showChevron: true,
                      onTap: () =>
                          pushPage(context, MealDetailScreen(meal: item)),
                    ),
                ],
              ),
            ),
          ],
        ),
        Gutter(
          child: GroupedCard(
            children: [
              if (groupId != null)
                NavRow(
                  title: context.l10n.rename,
                  onTap: () => _rename(groupId, items),
                ),
              NavRow(
                title: context.l10n.splitThisMeal,
                showChevron: false,
                onTap: () => _ungroup(items),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
