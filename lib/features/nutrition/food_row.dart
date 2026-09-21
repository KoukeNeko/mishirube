import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../backend/engines/food_portion.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';

/// One food in a list: first whether it is the one, then what ＋ would
/// add.
///
/// The name leads; the brand and where the figures come from follow on
/// a quieter line; the last line is the portion ＋ puts on the plate and
/// what it comes to — not the per-100 g basis, which belongs on the
/// food's own page.
class FoodRow extends StatelessWidget {
  const FoodRow({
    super.key,
    required this.food,
    required this.adds,
    required this.isOnPlate,
    required this.onTap,
    required this.onAdd,
    this.showsAdd = true,
  });

  final FoodItem food;

  /// What ＋ would add, already written: `上次 200 g · 330 kcal`.
  final String adds;
  final bool isOnPlate;

  /// Choose the portion first.
  final VoidCallback onTap;

  /// Onto the plate at [adds], or off it again when it is already there.
  final VoidCallback onAdd;

  /// False where ＋ could only do what tapping the row does — a list in
  /// which every drink still needs its cup chosen.
  final bool showsAdd;

  @override
  Widget build(BuildContext context) {
    final source = [
      if (food.brand.isNotEmpty) food.brand,
      if (food.isBuiltIn) '官方資料',
    ].join(' · ');
    return AppCard(
      padding: EdgeInsets.zero,
      tone: isOnPlate ? CardTone.nutrition : CardTone.neutral,
      child: Row(
        children: [
          Expanded(
            child: NavRow(
              title: food.sizeName.isEmpty
                  ? food.name
                  : '${food.name} ${food.sizeName}',
              subtitle: [if (source.isNotEmpty) source, adds].join('\n'),
              onTap: onTap,
            ),
          ),
          if (showsAdd) ...[
            Semantics(
              selected: isOnPlate,
              child: SquareIconButton(
                icon: isOnPlate ? Icons.check : Icons.add,
                tooltip: isOnPlate
                    ? '從這一餐拿掉「${food.displayName}」'
                    : '加入「${food.displayName}」',
                onPressed: onAdd,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

/// `330 kcal`, marked for what kind of figure it is, or a dash.
String kcalOf(FoodItem food, int? kcal) =>
    '${food.valueType.write(formatKcalOrDash(kcal))} kcal';

/// What ＋ adds for a food last eaten at [portion].
String addsLastPortion(FoodPortion portion) =>
    '上次 ${portion.label} · ${kcalOf(portion.food, portion.kcal)}';

/// What ＋ adds for a food not eaten before: one serving, or the choice
/// of a cup when it comes in sizes.
String addsFirstPortion(FoodItem food, {required int sizeCount}) =>
    sizeCount > 0
    ? '$sizeCount 種杯型 · 選一種'
    : '一份 ${food.servingDescription} · ${kcalOf(food, food.kcal)}';
