import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/engines/food_portion.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'food_edit_screen.dart';
import 'nutrition_view_model.dart';

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

/// Which cup of [food]: one row each, with its volume and the figure the
/// chain actually published, in the app's own dialog rather than a system
/// sheet. Null when the user backed out.
Future<FoodItem?> pickCupSize(
  BuildContext context,
  FoodItem food,
  List<FoodItem> sizes,
) => showAppDialog<FoodItem>(
  context,
  AppDialog(
    title: food.name,
    message: food.brand.isEmpty ? null : food.brand,
    isChoiceList: true,
    actions: [
      for (final (index, size) in sizes.indexed)
        DialogAction(
          icon: _cupIcons[index.clamp(0, _cupIcons.length - 1)],
          label: size.sizeName,
          detail: _sizeDetail(size),
          onTap: () => Navigator.of(context).pop(size),
        ),
    ],
  ),
);

/// A cup per size, smallest first; sizes past the last share it.
const _cupIcons = [
  Icons.coffee_outlined,
  Icons.local_cafe_outlined,
  Icons.local_drink_outlined,
];

/// `354 ml · 咖啡因 150 mg`: the volume, then whichever figure the size
/// has — energy when it was published, caffeine when that is all there is.
String _sizeDetail(FoodItem size) {
  final caffeine = size.nutrients[Nutrient.caffeine];
  return [
    size.servingDescription,
    if (size.kcal != null)
      '${formatKcal(size.kcal!.round())} kcal'
    else if (caffeine != null)
      '咖啡因 ${formatAmount(caffeine)} mg',
  ].join(' · ');
}

/// How much of a food is being logged, and everything that comes to.
///
/// A whole page rather than a sheet: a drink can carry a dozen figures
/// once brand data is involved, and a half-height sheet either hides
/// them or makes the page scroll behind the keyboard.
class PortionScreen extends StatefulWidget {
  const PortionScreen({
    super.key,
    required this.food,
    this.servings = 1,
    this.canAdd = true,
  });

  final FoodItem food;

  /// False when the food is only being looked at, from the food library:
  /// there is no plate to add it to.
  final bool canAdd;

  /// Where the portion starts.
  final double servings;

  @override
  State<PortionScreen> createState() => _PortionScreenState();
}

class _PortionScreenState extends State<PortionScreen> {
  late final NutritionViewModel _nutrition;
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
    _nutrition = NutritionViewModel(AppStoreScope.read(context).backend);
    _servings.addListener(_onServingsTyped);
    _amount.addListener(_onAmountTyped);
  }

  @override
  void dispose() {
    _servings.dispose();
    _amount.dispose();
    _nutrition.dispose();
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
    final food = widget.food;
    _nutrition.deleteFood(food.id);
    Navigator.of(context).pop();
    ToastScope.read(context).showUndo(
      '已刪除「${food.displayName}」',
      onUndo: () => _nutrition.undeleteFood(food.id),
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _nutrition,
    builder: (context, _) => _page(context),
  );

  Widget _page(BuildContext context) {
    final food = widget.food;
    final portion = _portion;
    final type = food.valueType;
    final isStarred = _nutrition.isFavoriteFood(food.id);
    return DetailPage(
      appBar: PageAppBar(
        title: food.displayName,
        subtitle: '一份 = ${food.servingDescription}',
        // Food that ships with the app is read-only: the next release
        // replaces it, so an edit here would not survive.
        actions: [
          // Any food can be starred, a shipped cup size included: the star
          // is kept apart from the food, so a catalogue update keeps it.
          HeaderAction(
            icon: isStarred ? Icons.star : Icons.star_border,
            label: isStarred ? '已收藏' : '收藏',
            semanticLabel: isStarred ? '取消收藏' : '收藏這個食物',
            onTap: () =>
                _nutrition.setFoodFavorite(food.id, isFavorite: !isStarred),
          ),
          if (!food.isBuiltIn)
            HeaderAction(
              icon: Icons.edit_outlined,
              label: '編輯',
              semanticLabel: '編輯這個食物',
              onTap: _edit,
            ),
        ],
      ),
      footer: widget.canAdd
          ? PrimaryButton(
              label: '加入 ${portion.label}',
              onPressed: portion.servings > 0
                  ? () => Navigator.of(context).pop(portion)
                  : null,
            )
          : null,
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
                  label: MacroLabel.energy,
                  value: '${formatKcalOrDash(portion.kcal)} kcal',
                ),
                KeyValueRow(
                  label: MacroLabel.protein,
                  value: _grams(portion.proteinGrams),
                ),
                KeyValueRow(
                  label: MacroLabel.carb,
                  value: _grams(portion.carbGrams),
                ),
                KeyValueRow(
                  label: MacroLabel.fat,
                  value: _grams(portion.fatGrams),
                ),
                if (portion.fibreGrams != null)
                  KeyValueRow(
                    label: MacroLabel.fibre,
                    value: _grams(portion.fibreGrams),
                  ),
                // Everything else the food holds. A brand drink often
                // knows its caffeine and nothing else, and a screen that
                // showed only the five would show it as four dashes.
                for (final MapEntry(key: nutrient, value: amount)
                    in portion.nutrients.entries)
                  KeyValueRow(
                    label: nutrient.label,
                    value: nutrient.format(amount),
                  ),
                if (portion.millilitres case final volume?)
                  KeyValueRow(label: '容量', value: '$volume mL'),
              ],
            ),
          ),
        ),
        if (type != NutrientValueType.declared)
          Gutter(
            child: Text(switch (type) {
              NutrientValueType.max => '標示上限值，實際可能較低。',
              NutrientValueType.estimate => '同類食物的概估值。',
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
String _checked(DateTime? at) => at == null ? '' : ' · 查證 ${formatDate(at)}';

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
