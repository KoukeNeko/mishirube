import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'meal_type_picker.dart';
import 'nutrition_view_model.dart';

/// Correcting what a meal was. The numbers usually arrived as an
/// estimate; confirming them here is what makes them the user's own, so
/// the `~` comes off and the day's totals stop hedging.
class MealEditScreen extends StatefulWidget {
  const MealEditScreen({super.key, required this.meal});

  final MealEvent meal;

  @override
  State<MealEditScreen> createState() => _MealEditScreenState();
}

class _MealEditScreenState extends State<MealEditScreen> {
  late final NutritionViewModel _nutrition;
  late final _name = TextEditingController(text: widget.meal.name);
  late final _kcal = _field(widget.meal.kcal);
  late final _protein = _field(widget.meal.proteinGrams);
  late final _carbs = _field(widget.meal.carbGrams);
  late final _fat = _field(widget.meal.fatGrams);
  late final _fibre = _field(widget.meal.fibreGrams);

  /// What was drunk, for a drink that has a volume.
  late final _millilitres = _field(widget.meal.millilitres);
  late MealType? _mealType = widget.meal.mealType;

  /// When it was eaten; changed here, the meal moves, to another day
  /// too.
  late DateTime? _eatenAt = _nutrition.eatenAtOf(widget.meal.id);

  Future<void> _pickTime() async {
    final picked = await pickDateTime(
      context,
      initial: _eatenAt ?? _nutrition.now(),
      latest: _nutrition.now(),
    );
    if (picked == null || !mounted) return;
    setState(() => _eatenAt = picked);
  }

  /// Every other nutrient on the meal, the four a Taiwanese label always
  /// prints among them, and any added here.
  late final Map<Nutrient, TextEditingController> _extra = {
    for (final nutrient in Nutrient.values)
      if (_labelNutrients.contains(nutrient) ||
          widget.meal.nutrients.containsKey(nutrient))
        nutrient: TextEditingController(
          text: switch (widget.meal.nutrients[nutrient]) {
            final amount? => formatAmount(amount),
            null => '',
          },
        ),
  };

  /// A figure nobody wrote down leaves the field empty. Printing `null`
  /// into it was the screen saying the quiet part out loud.
  static TextEditingController _field(int? value) =>
      TextEditingController(text: value == null ? '' : '$value');
  String? _error;

  @override
  void initState() {
    super.initState();
    _nutrition = NutritionViewModel(AppStoreScope.read(context).backend);
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _kcal,
      _protein,
      _carbs,
      _fat,
      _fibre,
      _millilitres,
      ..._extra.values,
    ]) {
      controller.dispose();
    }
    _nutrition.dispose();
    super.dispose();
  }

  int? _number(TextEditingController controller) =>
      int.tryParse(controller.text.trim());

  void _save() {
    final name = _name.text.trim();
    final kcal = _number(_kcal);
    final protein = _number(_protein);
    final carbs = _number(_carbs);
    final fat = _number(_fat);
    final fibre = _number(_fibre);
    if (name.isEmpty) {
      setState(() => _error = '名稱不能空白。');
      return;
    }
    // Empty is allowed: it means nobody wrote the figure down, which is
    // not the same as zero. A negative one is nonsense either way.
    if ([
      kcal,
      protein,
      carbs,
      fat,
      fibre,
    ].any((value) => value != null && value < 0)) {
      setState(() => _error = '營養素不能是負數。');
      return;
    }
    final meal = widget.meal;
    if (_eatenAt case final eatenAt?
        when eatenAt != _nutrition.eatenAtOf(meal.id)) {
      _nutrition.retimeMeal(meal.id, eatenAt);
    }
    _nutrition.updateMeal(
      meal,
      // Built by hand rather than with copyWith, which cannot put a
      // figure back to "nobody wrote this down".
      MealEvent(
        id: meal.id,
        name: name,
        timeLabel: meal.timeLabel,
        dishes: meal.dishes,
        nutrients: {
          for (final MapEntry(key: nutrient, value: field) in _extra.entries)
            if (double.tryParse(field.text.trim()) case final amount?
                when amount >= 0)
              nutrient: amount,
        },
        millilitres: meal.millilitres == null
            ? null
            : _number(_millilitres) ?? meal.millilitres,
        kind: meal.kind,
        mealType: _mealType,
        foodId: meal.foodId,
        servings: meal.servings,
        valueType: meal.valueType,
        isFavorite: meal.isFavorite,
        kcal: kcal,
        proteinGrams: protein,
        carbGrams: carbs,
        fatGrams: fat,
        fibreGrams: fibre,
        // The user has just said what these are, so they are no longer
        // somebody's guess.
        isEstimated: false,
        // Water keeps its own mark, or a corrected glass would stop
        // counting as water.
        qualityTag: meal.isWater ? meal.qualityTag : '已確認',
      ),
    );
    Navigator.of(context).pop();
    showToast(context, '已更新「$name」', kind: ToastKind.success);
  }

  /// Adds a row for a nutrient the meal does not hold yet.
  Future<void> _addNutrient() async {
    final nutrient = await showAppDialog<Nutrient>(
      context,
      AppDialog(
        title: '新增營養素',
        isChoiceList: true,
        actions: [
          for (final nutrient in Nutrient.values)
            if (!_extra.containsKey(nutrient))
              DialogAction(
                label: nutrient.label,
                onTap: () => Navigator.of(context).pop(nutrient),
              ),
        ],
      ),
    );
    if (nutrient == null || !mounted) return;
    setState(() => _extra[nutrient] = TextEditingController());
  }

  /// A tombstone, taken back from the toast, as a workout's delete is.
  void _delete() {
    final meal = widget.meal;
    final toast = ToastScope.read(context);
    _nutrition.deleteMeals([meal]);
    Navigator.of(context).pop();
    toast.showUndo(
      '已刪除「${meal.name}」',
      onUndo: () => _nutrition.restoreMeals([meal]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DetailPage(
      appBar: PageAppBar(title: '編輯這一餐', subtitle: widget.meal.timeLabel),
      footer: PrimaryButton(label: '儲存', onPressed: _save),
      children: [
        Gutter(child: const SectionLabel('名稱')),
        Gutter(
          child: AppTextField(controller: _name, hint: '例如：午餐'),
        ),
        if (_eatenAt case final eatenAt?)
          Gutter(
            child: GroupedCard(
              children: [
                NavRow(
                  title: '時間',
                  trailing: Text(
                    '${formatDate(eatenAt)} ${formatTimeOfDay(eatenAt)}',
                    style: AppTextStyles.caption,
                  ),
                  onTap: _pickTime,
                ),
              ],
            ),
          ),
        Gutter(child: const SectionLabel('餐次（選填）')),
        Gutter(
          // No suggestion here: the user already had their chance to
          // label it, and an offer on a past meal would be the app
          // second-guessing them.
          child: MealTypePicker(
            selected: _mealType,
            onChanged: (type) => setState(() => _mealType = type),
          ),
        ),
        if (widget.meal.millilitres != null) ...[
          Gutter(child: const SectionLabel('容量')),
          Gutter(
            child: _NumberField(controller: _millilitres, unit: 'mL'),
          ),
        ],
        Gutter(child: const SectionLabel(MacroLabel.energy)),
        Gutter(
          child: _NumberField(controller: _kcal, unit: 'kcal'),
        ),
        Gutter(child: const SectionLabel('營養素')),
        Gutter(
          child: GroupedCard(
            children: [
              _MacroRow(label: MacroLabel.protein, controller: _protein),
              _MacroRow(label: MacroLabel.carb, controller: _carbs),
              _MacroRow(label: MacroLabel.fat, controller: _fat),
              _MacroRow(label: MacroLabel.fibre, controller: _fibre),
              for (final MapEntry(key: nutrient, value: field)
                  in _extra.entries)
                _MacroRow(
                  label: nutrient.label,
                  unit: nutrient.unit.label,
                  isDecimal: true,
                  controller: field,
                ),
            ],
          ),
        ),
        if (_extra.length < Nutrient.values.length)
          Gutter(
            child: LinkText(
              label: '新增營養素',
              color: AppColors.nutrition,
              onTap: _addNutrient,
            ),
          ),
        if (_error case final error?)
          Gutter(
            child: InfoBanner(tone: CardTone.warning, message: error),
          ),
        Gutter(
          child: GroupedCard(
            children: [
              NavRow(title: '刪除這一餐', isDestructive: true, onTap: _delete),
            ],
          ),
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.unit});

  final TextEditingController controller;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onTapOutside: dismissKeyboardOnTapOutside,
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTextStyles.bigNumber,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          Text(unit, style: AppTextStyles.itemTitle),
        ],
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({
    required this.label,
    required this.controller,
    this.unit = 'g',
    this.isDecimal = false,
  });

  final String label;
  final TextEditingController controller;
  final String unit;

  /// Labels print sugar and sodium to a decimal; the macros stay whole.
  final bool isDecimal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.body)),
          SizedBox(
            width: 72,
            child: TextField(
              onTapOutside: dismissKeyboardOnTapOutside,
              controller: controller,
              textAlign: TextAlign.end,
              keyboardType: isDecimal
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.number,
              inputFormatters: [
                isDecimal
                    ? FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                    : FilteringTextInputFormatter.digitsOnly,
              ],
              style: AppTextStyles.itemTitle,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(unit, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

/// What a Taiwanese label always prints beyond the five, so a meal shows
/// a place for them even before it has them.
const _labelNutrients = [
  Nutrient.saturatedFat,
  Nutrient.transFat,
  Nutrient.sugar,
  Nutrient.sodium,
];
