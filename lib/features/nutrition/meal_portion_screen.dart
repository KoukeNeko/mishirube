import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../backend/engines/food_portion.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'meal_detail_screen.dart';
import 'nutrition_view_model.dart';
import 'portion_screen.dart';
import 'recent_meal_row.dart';
import '../../l10n/l10n.dart';

/// Asks how much of [recent] is eaten this time, in servings of what it
/// was, and resolves to that; null when the user backed out.
Future<double?> showMealPortionScreen(
  BuildContext context,
  RecentMeal recent,
) => pushPage<double>(context, MealPortionScreen(recent: recent));

/// A meal eaten before, at the portion about to be logged: its figures
/// scaled to the servings typed, as they will be written.
class MealPortionScreen extends StatefulWidget {
  const MealPortionScreen({super.key, required this.recent});

  final RecentMeal recent;

  @override
  State<MealPortionScreen> createState() => _MealPortionScreenState();
}

class _MealPortionScreenState extends State<MealPortionScreen> {
  /// What a meal is most often eaten as, against what it was.
  static const _presets = [0.5, 1.0, 1.5, 2.0];

  late final _nutrition = NutritionViewModel(
    AppStoreScope.read(context).backend,
  );
  final _servings = TextEditingController(text: '1');

  double get _factor => double.tryParse(_servings.text.trim()) ?? 0;

  @override
  void initState() {
    super.initState();
    _servings.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _servings.dispose();
    _nutrition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final serving = ServingUnit.serving.labelIn(l10n);
    final factor = _factor;
    return DetailPage(
      appBar: PageAppBar(
        title: widget.recent.label,
        subtitle: mealWhenLabel(context, widget.recent.eatenAt),
      ),
      footer: PrimaryButton(
        label: l10n.addPortion(portion: '${formatAmount(factor)} $serving'),
        onPressed: factor > 0 ? () => Navigator.of(context).pop(factor) : null,
      ),
      children: [
        Gutter(
          child: PortionField(
            label: l10n.servingsLabel,
            controller: _servings,
            suffix: serving,
          ),
        ),
        Gutter(
          child: ChipWrap(
            options: _presets,
            labelOf: (preset) => '${formatAmount(preset)} $serving',
            isSelected: (preset) => preset == factor,
            onTap: (preset) => _servings.text = formatAmount(preset),
          ),
        ),
        ...mealFigures(
          context,
          scaledMeal(widget.recent.meal, factor),
          _nutrition.convention,
        ),
      ],
    );
  }
}
