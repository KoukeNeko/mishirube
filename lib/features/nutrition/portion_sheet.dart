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

  /// The field the user is typing in owns the number; the other one
  /// follows. Without this they would fight each other on every keypress.
  bool _isEditingAmount = false;

  bool get _isMeasured => widget.food.servingUnit.isMeasured;

  FoodPortion get _portion => _isEditingAmount
      ? FoodPortion.ofAmount(widget.food, _read(_amount))
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
    if (_isMeasured) {
      _amount.text = formatAmount(
        widget.food.servingAmount * _read(_servings),
      );
    }
    setState(() {});
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
                    suffix: food.servingUnit.label,
                    onFocus: () => setState(() => _isEditingAmount = true),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                KeyValueRow(
                  label: '熱量',
                  value: '${formatKcal(portion.kcal)} kcal',
                ),
                KeyValueRow(label: '蛋白質', value: '${portion.proteinGrams} g'),
                KeyValueRow(label: '碳水', value: '${portion.carbGrams} g'),
                KeyValueRow(label: '脂肪', value: '${portion.fatGrams} g'),
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
