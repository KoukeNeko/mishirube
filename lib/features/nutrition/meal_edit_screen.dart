import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import 'meal_type_picker.dart';

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
  late final _name = TextEditingController(text: widget.meal.name);
  late final _kcal = _field(widget.meal.kcal);
  late final _protein = _field(widget.meal.proteinGrams);
  late final _carbs = _field(widget.meal.carbGrams);
  late final _fat = _field(widget.meal.fatGrams);
  late final _fibre = _field(widget.meal.fibreGrams);
  late MealType? _mealType = widget.meal.mealType;

  /// A figure nobody wrote down leaves the field empty. Printing `null`
  /// into it was the screen saying the quiet part out loud.
  static TextEditingController _field(int? value) =>
      TextEditingController(text: value == null ? '' : '$value');
  String? _error;

  @override
  void dispose() {
    for (final controller in [_name, _kcal, _protein, _carbs, _fat, _fibre]) {
      controller.dispose();
    }
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
    final store = AppStoreScope.read(context);
    final meal = widget.meal;
    store.updateMeal(
      meal,
      // Built by hand rather than with copyWith, which cannot put a
      // figure back to "nobody wrote this down".
      MealEvent(
        id: meal.id,
        name: name,
        timeLabel: meal.timeLabel,
        dishes: meal.dishes,
        nutrients: meal.nutrients,
        millilitres: meal.millilitres,
        kind: meal.kind,
        mealType: _mealType,
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
        qualityTag: '已確認',
      ),
    );
    Navigator.of(context).pop();
    showToast(context, '已更新「$name」', kind: ToastKind.success);
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
        Gutter(child: const SectionLabel('這是哪一餐（可不選）')),
        Gutter(
          // No suggestion here: the user already had their chance to
          // label it, and an offer on a past meal would be the app
          // second-guessing them.
          child: MealTypePicker(
            selected: _mealType,
            onChanged: (type) => setState(() => _mealType = type),
          ),
        ),
        Gutter(child: const SectionLabel('熱量')),
        Gutter(
          child: _NumberField(controller: _kcal, unit: 'kcal'),
        ),
        Gutter(child: const SectionLabel('營養素')),
        Gutter(
          child: GroupedCard(
            children: [
              _MacroRow(label: '蛋白質', controller: _protein),
              _MacroRow(label: '碳水化合物', controller: _carbs),
              _MacroRow(label: '脂肪', controller: _fat),
              _MacroRow(label: '纖維', controller: _fibre),
            ],
          ),
        ),
        if (widget.meal.isEstimated)
          Gutter(
            child: const Text(
              '這一餐的數字目前是估計值。儲存後會標示為你確認過的數字。',
              style: AppTextStyles.caption,
            ),
          ),
        if (widget.meal.dishes.isNotEmpty)
          Gutter(
            child: Text(
              '這裡不動料理本身（${widget.meal.dishes.length} 道）；'
              '要改組成請回到那一餐拆開。',
              style: AppTextStyles.caption,
            ),
          ),
        if (_error case final error?)
          Gutter(
            child: InfoBanner(tone: CardTone.warning, message: error),
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
  const _MacroRow({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

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
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTextStyles.itemTitle,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Text('g', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
