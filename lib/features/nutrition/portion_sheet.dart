import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../backend/engines/food_portion.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';

/// Asks how much of [food] is being logged, and resolves to that portion.
///
/// It opens at one serving, so logging the usual amount is one more tap.
Future<FoodPortion?> showPortionSheet(BuildContext context, FoodItem food) {
  return showModalBottomSheet<FoodPortion>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (_) => _PortionSheet(food: food),
  );
}

class _PortionSheet extends StatefulWidget {
  const _PortionSheet({required this.food});

  final FoodItem food;

  @override
  State<_PortionSheet> createState() => _PortionSheetState();
}

class _PortionSheetState extends State<_PortionSheet> {
  late final _servings = TextEditingController(text: '1');
  late final _amount = TextEditingController(
    text: formatAmount(widget.food.servingAmount),
  );

  /// The unit the amount field is written in. It starts as the food's
  /// own, and can be any unit measuring the same kind of quantity.
  late ServingUnit _unit = widget.food.servingUnit;

  /// The field the user is typing in owns the number; the other one
  /// follows. Without this they would fight each other on every keypress.
  bool _isEditingAmount = false;

  bool get _isMeasured => widget.food.servingUnit.isMeasured;

  FoodPortion get _portion => _isEditingAmount
      ? FoodPortion.ofAmount(widget.food, _read(_amount), unit: _unit)
      : FoodPortion(widget.food, _read(_servings));

  static double _read(TextEditingController field) =>
      double.tryParse(field.text.trim()) ?? 0;

  @override
  void initState() {
    super.initState();
    _servings.addListener(_onServingsTyped);
    _amount.addListener(_onAmountTyped);
  }

  @override
  void dispose() {
    _servings.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _onServingsTyped() {
    if (_isEditingAmount) return;
    if (_isMeasured) _showAmountFor(_read(_servings));
    setState(() {});
  }

  /// Writes [servings] into the amount field, in whichever unit the user
  /// picked.
  void _showAmountFor(double servings) {
    final inServingUnit = widget.food.servingAmount * servings;
    _amount.text = formatAmount(
      widget.food.servingUnit.convert(inServingUnit, _unit),
    );
  }

  /// Fills in [count] of a named portion. It is a shortcut for typing
  /// the amount: everything after this is the same arithmetic.
  void _pickNamed(NamedPortion portion) {
    setState(() {
      _unit = portion.unit;
      _isEditingAmount = true;
      _amount.text = formatAmount(portion.amount);
    });
  }

  void _pickUnit(ServingUnit unit) {
    setState(() {
      final servings = _portion.servings;
      _unit = unit;
      // The portion has not changed, only how it is written.
      _isEditingAmount = false;
      _showAmountFor(servings);
      _isEditingAmount = true;
    });
  }

  void _onAmountTyped() {
    if (!_isEditingAmount) return;
    _servings.text = formatAmount(FoodPortion.ofAmount(
      widget.food,
      _read(_amount),
    ).servings);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final portion = _portion;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.screenGutter,
        AppSpacing.screenGutter,
        AppSpacing.screenGutter + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(food.displayName, style: AppTextStyles.pageTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '一份 = ${food.servingDescription}',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _PortionField(
                  label: '份數',
                  controller: _servings,
                  suffix: ServingUnit.serving.label,
                  onFocus: () => setState(() => _isEditingAmount = false),
                ),
              ),
              if (_isMeasured) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _PortionField(
                    label: '實際份量',
                    controller: _amount,
                    suffix: _unit.label,
                    onFocus: () => setState(() => _isEditingAmount = true),
                  ),
                ),
              ],
            ],
          ),
          if (food.portions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ChipWrap(
              options: food.portions,
              labelOf: (portion) => portion.name,
              isSelected: (_) => false,
              onTap: _pickNamed,
            ),
          ],
          if (_isMeasured &&
              food.servingUnit.comparable.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            ChipWrap(
              options: food.servingUnit.comparable.toList(),
              labelOf: (unit) => unit.label,
              isSelected: (unit) => unit == _unit,
              onTap: _pickUnit,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                KeyValueRow(
                  label: '熱量',
                  value: '${formatKcalOrDash(portion.kcal)} kcal',
                ),
                KeyValueRow(label: '蛋白質', value: _grams(portion.proteinGrams)),
                KeyValueRow(label: '碳水', value: _grams(portion.carbGrams)),
                KeyValueRow(label: '脂肪', value: _grams(portion.fatGrams)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: '記錄 ${portion.label}',
            onPressed: portion.servings > 0
                ? () => Navigator.of(context).pop(portion)
                : null,
          ),
        ],
      ),
    );
  }
}

/// `31 g`, or a dash when the food has no figure for it.
String _grams(int? amount) => amount == null ? '—' : '$amount g';

class _PortionField extends StatelessWidget {
  const _PortionField({
    required this.label,
    required this.controller,
    required this.suffix,
    required this.onFocus,
  });

  final String label;
  final TextEditingController controller;
  final String suffix;
  final VoidCallback onFocus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.xs),
        Focus(
          onFocusChange: (hasFocus) {
            if (hasFocus) onFocus();
          },
          child: Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: controller,
                  hint: '0',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(suffix, style: AppTextStyles.body),
            ],
          ),
        ),
      ],
    );
  }
}
