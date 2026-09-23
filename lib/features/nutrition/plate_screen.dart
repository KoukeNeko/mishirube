import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../backend/engines/food_portion.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'portion_screen.dart';

/// The calories of everything on the plate that has a figure. Anything
/// without one is left out and said so beside it ([plateMissingLabel]),
/// not folded into the number.
String plateKcalLabel(List<FoodPortion> plate) =>
    formatKcal(plate.fold(0, (sum, portion) => sum + (portion.kcal ?? 0)));

/// `1 項沒有熱量`, or null when every item has a figure.
String? plateMissingLabel(List<FoodPortion> plate) {
  final missing = plate.where((portion) => portion.kcal == null).length;
  return missing == 0 ? null : '$missing 項沒有熱量';
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
  /// Shows a remove button on every row: the way to remove that does not
  /// depend on knowing the swipe.
  bool _isEditing = false;

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

  /// Takes a row off at once and offers it back, rather than asking
  /// first: nothing is logged yet. Removing the last one leaves the page
  /// open — an empty plate and being done with it are different things.
  void _remove(int index) {
    final removed = widget.plate[index];
    setState(() => widget.plate.removeAt(index));
    widget.onChanged();
    ToastScope.read(context).showUndo(
      '已移除「${removed.food.displayName}」',
      onUndo: () {
        widget.plate.insert(index.clamp(0, widget.plate.length), removed);
        widget.onChanged();
        if (mounted) setState(() {});
      },
    );
  }

  // The owner closes every page it opened, this one included, as it logs.
  void _log() => widget.onLog();

  @override
  Widget build(BuildContext context) {
    final plate = widget.plate;
    return DetailPage(
      appBar: PageAppBar(
        title: '這一餐',
        subtitle: [
          '${plate.length} 項',
          '${plateKcalLabel(plate)} kcal',
          ?plateMissingLabel(plate),
        ].join(' · '),
        actions: [
          if (plate.isNotEmpty || _isEditing)
            HeaderAction(
              icon: _isEditing ? Icons.check : Icons.edit_outlined,
              label: _isEditing ? '完成' : '編輯',
              semanticLabel: _isEditing ? '完成編輯' : '編輯這一餐',
              onTap: () => setState(() => _isEditing = !_isEditing),
            ),
        ],
      ),
      footer: plate.isEmpty
          ? SecondaryButton(
              label: '繼續選擇',
              onPressed: () => Navigator.of(context).pop(),
            )
          : PrimaryButton(label: '記錄 ${plate.length} 項', onPressed: _log),
      children: [
        for (final (index, portion) in plate.indexed)
          Gutter(
            child: SwipeAction(
              // Keyed by the food, so a row's slide does not pass to the
              // one that moves up into its place.
              key: ValueKey(portion.food.id),
              label: '移除',
              semanticLabel: '移除「${portion.food.displayName}」',
              onAction: () => _remove(index),
              child: AppCard(
                padding: EdgeInsets.zero,
                child: Row(
                  children: [
                    Expanded(
                      child: NavRow(
                        title: portion.food.displayName,
                        subtitle:
                            '${portion.label} · '
                            '${formatKcalOrDash(portion.kcal)} kcal',
                        onTap: () => _change(index),
                      ),
                    ),
                    if (_isEditing) ...[
                      SquareIconButton(
                        icon: Icons.delete_outline,
                        color: AppColors.destructive,
                        tooltip: '移除「${portion.food.displayName}」',
                        onPressed: () => _remove(index),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                  ],
                ),
              ),
            ),
          ),
        Gutter(
          child: Text(
            plate.isEmpty ? '這一餐沒有項目。' : '點一項可以改份量，往左滑可以移除。',
            style: AppTextStyles.caption,
          ),
        ),
      ],
    );
  }
}

/// The plate so far, fixed at the bottom so the meal it is going to
/// stays in view however far the list scrolls, and the one action that
/// matters: log it.
class PlateBar extends StatelessWidget {
  const PlateBar({
    super.key,
    required this.plate,
    required this.mealType,
    required this.onReview,
    required this.onLog,
  });

  final List<FoodPortion> plate;
  final MealType? mealType;
  final VoidCallback onReview;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // The count is already on the log button; what the plate holds
        // is one tap away rather than squeezed into a label.
        SquareIconButton(
          icon: Icons.receipt_long_outlined,
          size: buttonHeight,
          radius: AppRadius.button,
          tooltip: [
            '這一餐',
            ?mealType?.label,
            '${plate.length} 項',
            '${plateKcalLabel(plate)} kcal',
            ?plateMissingLabel(plate),
          ].join(' · '),
          onPressed: onReview,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: PrimaryButton(label: '記錄 ${plate.length} 項', onPressed: onLog),
        ),
      ],
    );
  }
}
