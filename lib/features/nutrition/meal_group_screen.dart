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
      '已拆成 ${items.length} 筆',
      onUndo: () => _nutrition.regroupMeals(previous),
    );
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
    final total = mealTotal(items);
    final eatenAt = _nutrition.eatenAtOf(items.first.id);
    final nutrients = [
      for (final nutrient in summariseNutrients(items))
        if (!energyNutrients.contains(nutrient.nutrient)) nutrient,
    ];
    return DetailPage(
      appBar: PageAppBar(
        title: total.name,
        subtitle: eatenAt == null
            ? total.timeLabel
            : '${eatenAt.month} 月 ${eatenAt.day} 日（週${weekdayLabel(eatenAt)}）'
                  ' · ${total.timeLabel}',
      ),
      children: [
        Gutter(
          child: MealSummaryCard(
            meal: total,
            details: [?total.mealType?.label, '${items.length} 項'],
          ),
        ),
        if (nutrients.isNotEmpty)
          PageSection(
            label: '營養素',
            children: [
              Gutter(
                child: GroupedCard(
                  children: [
                    for (final nutrient in nutrients)
                      KeyValueRow(
                        label: nutrient.nutrient.label,
                        value: nutrient.label,
                      ),
                  ],
                ),
              ),
            ],
          ),
        PageSection(
          label: '內容',
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
              NavRow(
                title: '拆開這一餐',
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
