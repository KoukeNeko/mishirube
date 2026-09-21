import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../backend/engines/food_portion.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'portion_screen.dart';

/// `486`, or `≥486` when something on the plate has no calorie figure:
/// the sum of what is known is a floor, not the plate.
String plateKcalLabel(List<FoodPortion> plate) {
  final known = plate.fold(0, (sum, portion) => sum + (portion.kcal ?? 0));
  final isPartial = plate.any((portion) => portion.kcal == null);
  return '${isPartial ? '≥' : ''}${formatKcal(known)}';
}

/// Everything picked so far, each at its portion, before it is logged.
///
/// The plate belongs to the page that opened this one; changes here are
/// made to it directly and reported through [onChanged], so going back
/// keeps them.
class PlateScreen extends StatefulWidget {
  const PlateScreen({
    super.key,
    required this.plate,
    required this.onChanged,
    required this.onLog,
  });

  final List<FoodPortion> plate;
  final VoidCallback onChanged;

  /// Logs the plate and closes the page that owns it.
  final VoidCallback onLog;

  @override
  State<PlateScreen> createState() => _PlateScreenState();
}

class _PlateScreenState extends State<PlateScreen> {
  Future<void> _change(int index) async {
    final current = widget.plate[index];
    final portion = await showPortionScreen(
      context,
      current.food,
      servings: current.servings,
    );
    if (portion == null || !mounted) return;
    setState(() => widget.plate[index] = portion);
    widget.onChanged();
  }

  void _remove(int index) {
    setState(() => widget.plate.removeAt(index));
    widget.onChanged();
    if (widget.plate.isEmpty) Navigator.of(context).pop();
  }

  void _log() {
    // This page first, then the owner closes itself as it logs.
    Navigator.of(context).pop();
    widget.onLog();
  }

  @override
  Widget build(BuildContext context) {
    final plate = widget.plate;
    return DetailPage(
      appBar: PageAppBar(
        title: '這一餐',
        subtitle: '${plate.length} 項 · ${plateKcalLabel(plate)} kcal',
      ),
      footer: PrimaryButton(label: '記錄 ${plate.length} 項', onPressed: _log),
      children: [
        for (final (index, portion) in plate.indexed)
          Gutter(
            child: AppCard(
              padding: EdgeInsets.zero,
              child: Row(
                children: [
                  Expanded(
                    child: NavRow(
                      title: portion.food.displayName,
                      subtitle:
                          '${portion.label} · '
                          '${portion.food.valueType.write(formatKcalOrDash(portion.kcal))}'
                          ' kcal',
                      onTap: () => _change(index),
                    ),
                  ),
                  SquareIconButton(
                    icon: Icons.close,
                    tooltip: '拿掉「${portion.food.displayName}」',
                    onPressed: () => _remove(index),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ),
            ),
          ),
        Gutter(
          child: const Text(
            '點一項可以改份量。記錄後可以在提示中一起復原。',
            style: AppTextStyles.caption,
          ),
        ),
      ],
    );
  }
}
