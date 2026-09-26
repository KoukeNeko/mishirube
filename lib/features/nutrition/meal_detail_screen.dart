import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/engines/nutrition_summary.dart';
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
          child: MealSummaryCard(
            meal: meal,
            details: [
              ?meal.mealType?.label,
              if (meal.kind != ConsumptionKind.unknown) meal.kind.label,
              if (meal.millilitres case final millilitres?) '$millilitres mL',
            ],
          ),
        ),
        // What the card above does not show already.
        if ([
              for (final nutrient in meal.nutrients.keys)
                if (!energyNutrients.contains(nutrient)) nutrient,
            ]
            case final rest when rest.isNotEmpty)
          PageSection(
            label: '營養素',
            children: [
              Gutter(
                child: GroupedCard(
                  children: [
                    for (final nutrient in rest)
                      KeyValueRow(
                        label: nutrient.label,
                        value: nutrient.format(meal.nutrients[nutrient]!),
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

/// A meal's energy, what it was, and the parts that energy came from:
/// the top of a meal's page and of a group's, which shows their sum.
class MealSummaryCard extends StatelessWidget {
  const MealSummaryCard({
    super.key,
    required this.meal,
    this.details = const [],
  });

  final MealEvent meal;

  /// What else to say under the energy: the sitting, a drink's volume.
  final List<String> details;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueWithUnit(
          value: formatKcalOrDash(meal.kcal),
          unit: 'kcal',
          style: AppTextStyles.hugeNumber.copyWith(color: AppColors.nutrition),
        ),
        if (details.isNotEmpty)
          Text(details.join(' · '), style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.md),
        _Macros(meal: meal),
        if (meal.qualityTag.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          TagWrap(labels: [meal.qualityTag]),
        ],
      ],
    ),
  );
}

/// Everything in the meal that carries energy, as shares of it: one bar
/// split by colour, the three macronutrients under it with their grams
/// and energy, and what else the meal holds of fibre, sugar alcohols
/// and alcohol, the smaller parts, in a quieter row below. The energy
/// is [energyParts]'s, worked out from the grams; a label's own
/// carbohydrate grams are shown as printed.
class _Macros extends StatelessWidget {
  const _Macros({required this.meal});

  final MealEvent meal;

  @override
  Widget build(BuildContext context) {
    final energy = energyParts(meal);
    final main = [
      (MacroLabel.carb, AppColors.macroCarb, meal.carbGrams, energy.carb),
      (
        MacroLabel.protein,
        AppColors.macroProtein,
        meal.proteinGrams,
        energy.protein,
      ),
      (MacroLabel.fat, AppColors.macroFat, meal.fatGrams, energy.fat),
    ];
    final minor = [
      if (meal.fibreGrams case final grams?)
        (MacroLabel.fibre, AppColors.macroFibre, grams, energy.fibre!),
      if (meal.nutrients[Nutrient.polyols] case final grams?)
        (
          Nutrient.polyols.label,
          AppColors.macroPolyols,
          grams,
          energy.polyols!,
        ),
      if (meal.nutrients[Nutrient.alcohol] case final grams?)
        (
          Nutrient.alcohol.label,
          AppColors.macroAlcohol,
          grams,
          energy.alcohol!,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentBar(
          segments: [
            for (final (_, color, _, kcal) in main)
              ((kcal ?? 0).toDouble(), color),
            for (final (_, color, _, kcal) in minor) (kcal.toDouble(), color),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (label, color, grams, kcal) in main)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CategoryLabel(label: label, color: color),
                    // Under the name, not the dot.
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: CategoryLabel.textInset,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            grams == null ? '—' : '$grams g',
                            style: AppTextStyles.itemTitle,
                          ),
                          if (kcal != null)
                            Text(
                              '${formatKcal(kcal)} kcal',
                              style: AppTextStyles.caption,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (minor.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          // On the same three columns as the row above, from its left.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (label, color, grams, kcal) in minor)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CategoryLabel(label: label, color: color),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: CategoryLabel.textInset,
                        ),
                        child: Text(
                          '${formatAmount(grams.toDouble())} g · '
                          '${formatKcal(kcal)} kcal',
                          style: AppTextStyles.caption,
                        ),
                      ),
                    ],
                  ),
                ),
              if (minor.length < 3) Spacer(flex: 3 - minor.length),
            ],
          ),
        ],
      ],
    );
  }
}

/// The nutrients [MealSummaryCard] shows with their energy, which a
/// page's nutrient list leaves out.
const energyNutrients = {Nutrient.polyols, Nutrient.alcohol};
