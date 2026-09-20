import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'named_portion_sheet.dart';

/// Creating or correcting one of the user's own foods.
///
/// Every number here is typed by hand, so the screen never dresses them
/// up as a lookup: what goes in is what comes back out.
class FoodEditScreen extends StatefulWidget {
  const FoodEditScreen({super.key, this.editing, this.initialName = ''});

  /// The food being corrected; null when adding a new one.
  final FoodItem? editing;

  final String initialName;

  @override
  State<FoodEditScreen> createState() => _FoodEditScreenState();
}

class _FoodEditScreenState extends State<FoodEditScreen> {
  late final _name = TextEditingController(
    text: widget.editing?.name ?? widget.initialName,
  );
  late final _brand = TextEditingController(text: widget.editing?.brand ?? '');
  late final _serving = TextEditingController(
    text: widget.editing?.servingLabel ?? '',
  );
  late final _servingAmount = TextEditingController(
    text: formatAmount(widget.editing?.servingAmount ?? 1),
  );
  late ServingUnit _servingUnit =
      widget.editing?.servingUnit ?? ServingUnit.gram;

  /// Named shortcuts for this food: `一匙`, `一碗`. Each one is worth
  /// whatever the user says it is worth.
  late final _portions = [...?widget.editing?.portions];
  late final _kcal = _number(widget.editing?.kcal);
  late final _protein = _number(widget.editing?.proteinGrams);
  late final _carb = _number(widget.editing?.carbGrams);
  late final _fat = _number(widget.editing?.fatGrams);
  late final _fibre = _number(widget.editing?.fibreGrams);

  /// One field per nutrient, created only for the ones on screen. A field
  /// left empty stays out of the food: unknown is not zero.
  late final _extra = {
    for (final nutrient in Nutrient.values)
      nutrient: TextEditingController(
        text: switch (widget.editing?.nutrients[nutrient]) {
          final amount? => formatAmount(amount),
          null => '',
        },
      ),
  };

  /// Nutrients beyond the label's own stay folded away until asked for.
  late bool _showsEveryNutrient =
      widget.editing?.nutrients.keys.any(_isBeyondLabel) ?? false;

  static bool _isBeyondLabel(Nutrient nutrient) => !_labelNutrients.contains(
    nutrient,
  );

  static TextEditingController _number(int? value) =>
      TextEditingController(text: value == null ? '' : '$value');

  @override
  void initState() {
    super.initState();
    for (final controller in [_name, _servingAmount]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _brand,
      _serving,
      _servingAmount,
      _kcal,
      _protein,
      _carb,
      _fat,
      _fibre,
      ..._extra.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double get _amount => double.tryParse(_servingAmount.text.trim()) ?? 0;

  bool get _canSave => _name.text.trim().isNotEmpty && _amount > 0;

  void _save() {
    final store = AppStoreScope.read(context);
    final food = FoodItem(
      id: widget.editing?.id ?? store.newFoodId(),
      name: _name.text.trim(),
      brand: _brand.text.trim(),
      servingLabel: _serving.text.trim(),
      servingAmount: _amount,
      servingUnit: _servingUnit,
      kcal: _valueOf(_kcal),
      proteinGrams: _valueOf(_protein),
      carbGrams: _valueOf(_carb),
      fatGrams: _valueOf(_fat),
      fibreGrams: _valueOf(_fibre),
      nutrients: _typedNutrients(),
      portions: _portions,
    );
    store.saveFood(food);
    Navigator.of(context).pop(food);
  }

  /// Only the nutrients with a number in them. An empty field leaves the
  /// nutrient out of the food entirely, because not written down is not
  /// the same as zero.
  Nutrients _typedNutrients() {
    final nutrients = <Nutrient, double>{};
    for (final MapEntry(key: nutrient, value: field) in _extra.entries) {
      final amount = double.tryParse(field.text.trim());
      if (amount != null) nutrients[nutrient] = amount;
    }
    return nutrients;
  }

  /// An empty field stays empty. The app does not put a number where the
  /// user did not.
  static int? _valueOf(TextEditingController controller) =>
      int.tryParse(controller.text.trim());

  Future<void> _addPortion() async {
    final portion = await showNamedPortionSheet(context, unit: _servingUnit);
    if (portion == null || !mounted) return;
    setState(() => _portions.add(portion));
  }

  Widget _nutrientField(Nutrient nutrient) => _NumberField(
    label: nutrient.label,
    unit: nutrient.unit.label,
    field: _extra[nutrient]!,
  );

  @override
  Widget build(BuildContext context) {
    final isNew = widget.editing == null;
    return DetailPage(
      appBar: PageAppBar(
        title: isNew ? '新增食物' : '編輯食物',
        subtitle: '只存在這台裝置',
        leading: AppBarLeading.none,
        onClose: () => Navigator.of(context).pop(),
      ),
      footer: PrimaryButton(
        label: isNew ? '儲存' : '儲存變更',
        onPressed: _canSave ? _save : null,
      ),
      children: [
        Gutter(child: const SectionLabel('名稱')),
        Gutter(child: AppTextField(controller: _name, hint: '例如：雞胸肉')),
        Gutter(child: const SectionLabel('品牌（沒有就留空）')),
        Gutter(child: AppTextField(controller: _brand, hint: '例如：大成')),
        Gutter(child: const SectionLabel('一份是多少')),
        Gutter(
          child: Row(
            children: [
              SizedBox(
                width: 120,
                child: AppTextField(
                  controller: _servingAmount,
                  hint: '100',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
        ),
        Gutter(
          child: ChipWrap(
            options: ServingUnit.values,
            labelOf: (unit) => unit.label,
            isSelected: (unit) => unit == _servingUnit,
            onTap: (unit) => setState(() => _servingUnit = unit),
          ),
        ),
        Gutter(
          child: Text(
            switch (_servingUnit.dimension) {
              ServingDimension.count =>
                '選「份」代表這一份不是度量，App 不會替你換算成公克或毫升。',
              ServingDimension.mass =>
                '下次份量不同時可以改份數，或用 ${_unitLabels(ServingDimension.mass)} '
                '任一種填實際重量。重量與容量之間不會互換——那需要密度。',
              ServingDimension.volume =>
                '下次份量不同時可以改份數，或用 ${_unitLabels(ServingDimension.volume)} '
                '填實際容量。容量與重量之間不會互換——那需要密度。',
            },
            style: AppTextStyles.caption,
          ),
        ),
        Gutter(child: const SectionLabel('這一份叫什麼（可留空）')),
        Gutter(child: AppTextField(controller: _serving, hint: '例如：一片')),
        Gutter(child: const SectionLabel('常用份量（可留空）')),
        for (final (index, portion) in _portions.indexed)
          Gutter(
            child: AppCard(
              padding: EdgeInsets.zero,
              child: Row(
                children: [
                  Expanded(
                    child: NavRow(
                      title: portion.name,
                      subtitle: portion.description,
                    ),
                  ),
                  SquareIconButton(
                    icon: Icons.delete_outline,
                    onPressed: () => setState(() => _portions.removeAt(index)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ),
            ),
          ),
        Gutter(
          child: SecondaryButton(label: '新增常用份量', onPressed: _addPortion),
        ),
        Gutter(
          child: const Text(
            '例如「一匙 = 15 g」。一匙是多少由這份食物決定——一匙油和一匙美乃滋'
            '不一樣重，所以 App 不會替你決定。記錄時它只是幫你把數字填好。',
            style: AppTextStyles.caption,
          ),
        ),
        Gutter(child: const SectionLabel('每份營養')),
        Gutter(child: _NumberField(label: '熱量', unit: 'kcal', field: _kcal)),
        Gutter(child: _NumberField(label: '蛋白質', unit: 'g', field: _protein)),
        Gutter(child: _NumberField(label: '碳水', unit: 'g', field: _carb)),
        Gutter(child: _NumberField(label: '脂肪', unit: 'g', field: _fat)),
        Gutter(child: _NumberField(label: '膳食纖維', unit: 'g', field: _fibre)),
        for (final nutrient in _labelNutrients)
          Gutter(child: _nutrientField(nutrient)),
        if (_showsEveryNutrient)
          for (final nutrient in Nutrient.values)
            if (_isBeyondLabel(nutrient)) Gutter(child: _nutrientField(nutrient))
        else
          Gutter(
            child: SecondaryButton(
              label: '顯示其他營養素',
              onPressed: () => setState(() => _showsEveryNutrient = true),
            ),
          ),
        Gutter(
          child: const Text(
            '留空的欄位不會被當成 0，而是沒有資料——包裝上印 0 g 也只代表低於'
            '標示門檻，不是真的沒有。',
            style: AppTextStyles.caption,
          ),
        ),
      ],
    );
  }
}

/// The units of one kind of quantity, for a sentence: `g、kg、oz`.
String _unitLabels(ServingDimension dimension) => ServingUnit.values
    .where((unit) => unit.dimension == dimension)
    .map((unit) => unit.label)
    .join('、');

/// What Taiwan's packaging law makes every label print, beyond the five
/// the form asks for first. These are the ones a user can actually copy
/// off the back of a packet, so they are the ones shown without asking.
const _labelNutrients = [
  Nutrient.saturatedFat,
  Nutrient.transFat,
  Nutrient.sugar,
  Nutrient.sodium,
];

/// One nutrient's row: what it is, the number, and its unit. Every row
/// is the same shape, because on a label they are all just nutrients.
class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.unit,
    required this.field,
  });

  final String label;
  final String unit;
  final TextEditingController field;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppTextStyles.body)),
        SizedBox(
          width: 120,
          child: AppTextField(
            controller: field,
            // Not `0`: an empty field is a figure nobody wrote down.
            hint: '—',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(width: 36, child: Text(unit, style: AppTextStyles.caption)),
      ],
    );
  }
}
