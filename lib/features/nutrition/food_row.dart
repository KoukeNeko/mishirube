import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../backend/engines/food_portion.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';

/// One food in a list: first whether it is the one, then what tapping
/// it starts from.
///
/// The name leads; the brand and where the figures come from follow on
/// a quieter line; the last line is the portion the food opens at and
/// what it comes to — not the per-100 g basis, which belongs on the
/// food's own page. Tapping the row opens that page to choose the
/// portion; the ＋ at its end puts the portion on the last line straight
/// on the plate, which is what a food eaten again usually wants.
class FoodRow extends StatelessWidget {
  const FoodRow({
    super.key,
    required this.food,
    required this.adds,
    required this.isOnPlate,
    required this.onTap,
    this.onQuickAdd,
  });

  final FoodItem food;

  /// What the food opens at, already written: `上次 200 g · 330 kcal`.
  final String adds;
  final bool isOnPlate;

  /// Choose the portion.
  final VoidCallback onTap;

  /// Put [adds] on the plate as it is; null when there is a choice to
  /// make first, such as a cup size.
  final VoidCallback? onQuickAdd;

  @override
  Widget build(BuildContext context) {
    final source = [
      if (food.brand.isNotEmpty) food.brandLabel,
      if (food.isBuiltIn) '官方資料',
    ].join(' · ');
    return Semantics(
      selected: isOnPlate,
      child: NavCard(
        title: food.sizeName.isEmpty
            ? food.name
            : '${food.name} ${food.sizeName}',
        subtitle: [if (source.isNotEmpty) source, adds].join('\n'),
        onTap: onTap,
        trailing: switch (onQuickAdd) {
          final add? => SquareIconButton(
            icon: Icons.add,
            tooltip: '加入「${food.name}」',
            color: AppColors.nutrition,
            onPressed: add,
          ),
          null => null,
        },
        tone: isOnPlate ? CardTone.nutrition : CardTone.neutral,
      ),
    );
  }
}

/// `330 kcal`, marked for what kind of figure it is, or a dash.
String kcalOf(FoodItem food, int? kcal) => '${formatKcalOrDash(kcal)} kcal';

/// What a food last eaten at [portion] opens at.
String addsLastPortion(FoodPortion portion) =>
    '上次 ${portion.label} · ${kcalOf(portion.food, portion.kcal)}';

/// What a food not eaten before opens at: one serving, or the choice of
/// a cup when it comes in sizes.
String addsFirstPortion(FoodItem food, {required int sizeCount}) {
  if (sizeCount > 0) return '$sizeCount 種杯型';
  return '一份 ${food.servingDescription} · ${kcalOf(food, food.kcal?.round())}';
}
