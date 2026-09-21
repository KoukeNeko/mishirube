import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/engines/food_portion.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'food_edit_screen.dart';

/// Asks how much of [food] goes on the plate, and resolves to that
/// portion; null when the user backed out, or edited or deleted the food
/// instead.
///
/// It opens at [servings] — the portion last eaten, when there is one —
/// so the usual amount is one more tap.
Future<FoodPortion?> showPortionScreen(
  BuildContext context,
  FoodItem food, {
  double servings = 1,
}) => pushPage<FoodPortion>(
  context,
  PortionScreen(food: food, servings: servings),
);

/// How much of a food is being logged, and everything that comes to.
///
/// A whole page rather than a sheet: a drink can carry a dozen figures
/// once brand data is involved, and a half-height sheet either hides
/// them or makes the page scroll behind the keyboard.
class PortionScreen extends StatefulWidget {
  const PortionScreen({super.key, required this.food, this.servings = 1});

  final FoodItem food;

  /// Where the portion starts.
  final double servings;

  @override
  State<PortionScreen> createState() => _PortionScreenState();
}

class _PortionScreenState extends State<PortionScreen> {
  late final _servings = TextEditingController(
    text: formatAmount(widget.servings),
  );
  late final _amount = TextEditingController(
    text: formatAmount(widget.food.servingAmount * widget.servings),
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

  /// Edits the food itself, then leaves: the portion on this page was
  /// worked out from the numbers that were just changed.
  Future<void> _edit() async {
    await pushPage<FoodItem>(context, FoodEditScreen(editing: widget.food));
    if (mounted) Navigator.of(context).pop();
  }

  /// Takes the food out of the list. What was already eaten is kept: its
  /// numbers were copied when it was logged.
  void _delete() {
    final store = AppStoreScope.read(context);
    final food = widget.food;
    store.deleteFood(food.id);
    Navigator.of(context).pop();
    ToastScope.read(context).showUndo(
      '已刪除「${food.displayName}」',
      onUndo: () => store.undeleteFood(food.id),
    );
  }

  void _onAmountTyped() {
    if (!_isEditingAmount) return;
    _servings.text = formatAmount(
      FoodPortion.ofAmount(widget.food, _read(_amount), unit: _unit).servings,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final portion = _portion;
    final type = food.valueType;
    return DetailPage(
      appBar: PageAppBar(
        title: food.displayName,
        subtitle: '一份 = ${food.servingDescription}',
        // Food that ships with the app is read-only: the next release
        // replaces it, so an edit here would not survive.
        actions: [
          if (!food.isBuiltIn)
            HeaderAction(
              icon: Icons.edit_outlined,
              label: '編輯',
              semanticLabel: '編輯這個食物',
              onTap: _edit,
            ),
        ],
      ),
      footer: PrimaryButton(
        label: '加入 ${portion.label}',
        onPressed: portion.servings > 0
            ? () => Navigator.of(context).pop(portion)
            : null,
      ),
      children: [
        Gutter(
          child: Row(
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
        ),
        if (_isMeasured && food.servingUnit.comparable.length > 1)
          Gutter(
            child: ChipWrap(
              options: food.servingUnit.comparable.toList(),
              labelOf: (unit) => unit.label,
              isSelected: (unit) => unit == _unit,
              onTap: _pickUnit,
            ),
          ),
        Gutter(child: const SectionLabel('這一份是')),
        Gutter(
          child: AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                KeyValueRow(
                  label: '熱量',
                  value: type.write('${formatKcalOrDash(portion.kcal)} kcal'),
                ),
                KeyValueRow(
                  label: '蛋白質',
                  value: type.write(_grams(portion.proteinGrams)),
                ),
                KeyValueRow(
                  label: '碳水',
                  value: type.write(_grams(portion.carbGrams)),
                ),
                KeyValueRow(
                  label: '脂肪',
                  value: type.write(_grams(portion.fatGrams)),
                ),
                if (portion.fibreGrams != null)
                  KeyValueRow(
                    label: '膳食纖維',
                    value: type.write(_grams(portion.fibreGrams)),
                  ),
                // Everything else the food holds. A brand drink often
                // knows its caffeine and nothing else, and a screen that
                // showed only the five would show it as four dashes.
                for (final MapEntry(key: nutrient, value: amount)
                    in portion.nutrients.entries)
                  KeyValueRow(
                    label: nutrient.label,
                    value: type.write(nutrient.format(amount)),
                  ),
                if (portion.millilitres case final volume?)
                  KeyValueRow(label: '液體', value: '$volume mL'),
              ],
            ),
          ),
        ),
        if (type != NutrientValueType.declared)
          Gutter(
            child: Text(switch (type) {
              NutrientValueType.max => '這些是上限，不是這一份的實際量——台灣連鎖飲料依法標示的就是最高值。',
              NutrientValueType.estimate => '這些是同類東西的大概值，不是這一份的量。',
              NutrientValueType.declared => '',
            }, style: AppTextStyles.caption),
          ),
        if (food.sourceUrl.isNotEmpty)
          Gutter(
            child: Text(
              '資料來源：${food.sourceUrl}${_checked(food.checkedAt)}',
              style: AppTextStyles.caption,
            ),
          ),
        if (!food.isBuiltIn)
          Gutter(
            child: LinkText(
              label: '刪除這個食物',
              color: AppColors.textSecondary,
              onTap: _delete,
            ),
          ),
      ],
    );
  }
}

/// ` · 查核 2026/9/21`, or nothing when the figure has no date. A figure
/// nobody can date is a figure nobody can check.
String _checked(DateTime? at) => at == null ? '' : ' · 查核 ${formatDate(at)}';

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
