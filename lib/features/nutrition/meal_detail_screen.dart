import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'food_edit_screen.dart';
import 'nutrition_view_model.dart';

/// One logged meal as it was: what it came to and what it held. Changing
/// it is the pencil's, which opens the same form foods are added with.
class MealDetailScreen extends StatefulWidget {
  const MealDetailScreen({super.key, required this.meal});

  final MealEvent meal;

  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  late final _nutrition = NutritionViewModel(
    AppStoreScope.read(context).backend,
  );

  @override
  void dispose() {
    _nutrition.dispose();
    super.dispose();
  }

  /// The form closes itself; a meal deleted there takes this page with it.
  Future<void> _edit(MealEvent meal) async {
    final deleted = await pushPage<bool>(context, FoodEditScreen(meal: meal));
    if (deleted == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _nutrition,
    builder: (context, _) =>
        _page(_nutrition.mealById(widget.meal.id) ?? widget.meal),
  );

  Widget _page(MealEvent meal) {
    final eatenAt = _nutrition.eatenAtOf(meal.id);
    String grams(int? value) => value == null ? '—' : '$value g';
    return DetailPage(
      appBar: PageAppBar(
        title: meal.name,
        subtitle: eatenAt == null
            ? meal.timeLabel
            : '${eatenAt.month} 月 ${eatenAt.day} 日（週${weekdayLabel(eatenAt)}）'
                  ' · ${meal.timeLabel}',
        actions: [
          HeaderAction(
            icon: Icons.edit_outlined,
            label: '編輯',
            semanticLabel: '編輯這一餐',
            onTap: () => _edit(meal),
          ),
        ],
      ),
      children: [
        Gutter(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueWithUnit(
                  value: formatKcalOrDash(meal.kcal),
                  unit: 'kcal',
                  style: AppTextStyles.hugeNumber.copyWith(
                    color: AppColors.nutrition,
                  ),
                ),
                if ([
                      ?meal.mealType?.label,
                      if (meal.kind != ConsumptionKind.unknown) meal.kind.label,
                      if (meal.millilitres case final millilitres?)
                        '$millilitres mL',
                    ]
                    case final details when details.isNotEmpty)
                  Text(details.join(' · '), style: AppTextStyles.caption),
                const SizedBox(height: AppSpacing.md),
                _Macros(meal: meal),
                const SizedBox(height: AppSpacing.md),
                TagWrap(labels: [meal.qualityTag]),
              ],
            ),
          ),
        ),
        PageSection(
          label: '營養素',
          children: [
            Gutter(
              child: GroupedCard(
                children: [
                  KeyValueRow(
                    label: MacroLabel.fibre,
                    value: grams(meal.fibreGrams),
                  ),
                  for (final MapEntry(key: nutrient, value: amount)
                      in meal.nutrients.entries)
                    KeyValueRow(
                      label: nutrient.label,
                      value: nutrient.format(amount),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (meal.dishes.isNotEmpty)
          PageSection(
            label: '內容',
            children: [
              Gutter(
                child: GroupedCard(
                  children: [
                    for (final dish in meal.dishes)
                      KeyValueRow(label: dish.name, value: dish.quantityLabel),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// The three macronutrients as shares of the energy they carry, one bar
/// split by colour, and under it each one's colour, name, grams and
/// share. The shares need all three: with one unknown, the bar shows
/// what is known and no percentages are claimed.
class _Macros extends StatelessWidget {
  const _Macros({required this.meal});

  final MealEvent meal;

  @override
  Widget build(BuildContext context) {
    // 4, 4 and 9 kcal a gram: the Atwater factors labels use.
    final macros = [
      (MacroLabel.carb, AppColors.macroCarb, meal.carbGrams, 4),
      (MacroLabel.protein, AppColors.macroProtein, meal.proteinGrams, 4),
      (MacroLabel.fat, AppColors.macroFat, meal.fatGrams, 9),
    ];
    final energies = [
      for (final (_, _, grams, factor) in macros) (grams ?? 0) * factor,
    ];
    final total = energies.fold(0, (sum, kcal) => sum + kcal);
    final isKnown = macros.every((macro) => macro.$3 != null) && total > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentBar(
          segments: [
            for (final (index, (_, color, _, _)) in macros.indexed)
              (energies[index].toDouble(), color),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (index, (label, color, grams, _)) in macros.indexed)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CategoryLabel(label: label, color: color),
                    Text(
                      grams == null ? '—' : '$grams g',
                      style: AppTextStyles.itemTitle,
                    ),
                    if (isKnown)
                      Text(
                        '${(energies[index] * 100 / total).round()}%',
                        style: AppTextStyles.caption,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
