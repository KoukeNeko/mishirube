import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';

/// Creating or correcting one of the user's own foods.
///
/// Every number here is typed by hand, so the screen never dresses them
/// up as a lookup: what goes in is what comes back out.
class FoodEditScreen extends StatefulWidget {
  const FoodEditScreen({
    super.key,
    this.editing,
    this.initialName = '',
    this.sizeOf,
  });

  /// The food being corrected; null when adding a new one.
  final FoodItem? editing;

  final String initialName;

  /// The food this new one is a cup size of, when it is one. A size
  /// carries its own figures: a bigger cup is not the smaller one
  /// scaled up, because the shot count changes too.
  final FoodItem? sizeOf;

  @override
  State<FoodEditScreen> createState() => _FoodEditScreenState();
}

class _FoodEditScreenState extends State<FoodEditScreen> {
  late final _name = TextEditingController(
    text: widget.editing?.name ?? widget.sizeOf?.name ?? widget.initialName,
  );
  late final _sizeName = TextEditingController(
    text: widget.editing?.sizeName ?? '',
  );
  late final _brand = TextEditingController(
    text: widget.editing?.brand ?? widget.sizeOf?.brand ?? '',
  );
  late final _serving = TextEditingController(
    text: widget.editing?.servingLabel ?? '',
  );
  late final _servingAmount = TextEditingController(
    text: formatAmount(widget.editing?.servingAmount ?? 1),
  );
  late ServingUnit _servingUnit =
      widget.editing?.servingUnit ?? ServingUnit.gram;
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
    for (final controller in [_name, _sizeName, _servingAmount]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _sizeName,
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

  /// The sizes of the food being edited. A new food has none until it
  /// is saved, because a size has to belong to something.
  List<FoodItem> get _sizes => widget.editing == null
      ? const []
      : AppStoreScope.of(context).sizesOf(widget.editing!.id);

  double get _amount => double.tryParse(_servingAmount.text.trim()) ?? 0;

  bool get _isSize => widget.sizeOf != null || widget.editing?.isSize == true;

  bool get _canSave =>
      _name.text.trim().isNotEmpty &&
      _amount > 0 &&
      (!_isSize || _sizeName.text.trim().isNotEmpty);

  /// Saves, and says whether the caller should log it straight away.
  ///
  /// Popping the food means "log this now"; popping nothing means it was
  /// only saved. Filling in a whole label and then being sent back to
  /// the list to find it again is a round trip with nothing in it.
  void _save({required bool logNow}) {
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
      parentId: widget.sizeOf?.id ?? widget.editing?.parentId,
      sizeName: _sizeName.text.trim(),
    );
    store.saveFood(food);
    Navigator.of(context).pop(logNow ? food : null);
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

  /// The cups this brand already uses. A shop's sizes are a fixed set,
  /// so the second drink from it should offer the same ones.
  List<String> _brandSizeNames() {
    final brand = _brand.text.trim();
    if (brand.isEmpty) return const [];
    return AppStoreScope.of(context)
        .sizeNamesFor(brand)
        .where((name) => name != _sizeName.text.trim())
        .toList();
  }

  Future<void> _addSize() async {
    final editing = widget.editing;
    if (editing == null) return;
    await pushPage<FoodItem>(context, FoodEditScreen(sizeOf: editing));
    if (mounted) setState(() {});
  }

  Future<void> _editSize(FoodItem size) async {
    await pushPage<FoodItem>(context, FoodEditScreen(editing: size));
    if (mounted) setState(() {});
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
      footer: isNew && !_isSize
          ? ButtonPair(
              secondary: SecondaryButton(
                label: '只建立',
                onPressed: _canSave ? () => _save(logNow: false) : null,
              ),
              primaryFlex: 2,
              primary: PrimaryButton(
                label: '建立並記錄',
                onPressed: _canSave ? () => _save(logNow: true) : null,
              ),
            )
          : PrimaryButton(
              label: isNew ? '儲存' : '儲存變更',
              onPressed: _canSave ? () => _save(logNow: false) : null,
            ),
      children: [
        Gutter(child: const SectionLabel('名稱')),
        Gutter(child: AppTextField(controller: _name, hint: '例如：雞胸肉')),
        if (_isSize) ...[
          Gutter(child: const SectionLabel('杯型')),
          Gutter(
            child: AppTextField(controller: _sizeName, hint: '例如：Tall'),
          ),
          if (_brandSizeNames() case final known when known.isNotEmpty)
            Gutter(
              child: ChipWrap(
                options: known,
                labelOf: (name) => name,
                isSelected: (name) => name == _sizeName.text.trim(),
                onTap: (name) => setState(() => _sizeName.text = name),
              ),
            ),
        ],
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
            _servingUnit.isMeasured
                ? '記錄時可以改份數，或直接填 ${_servingUnit.label}。'
                : '「份」不是度量，不會換算成公克或毫升。',
            style: AppTextStyles.caption,
          ),
        ),
        Gutter(child: const SectionLabel('這一份叫什麼（可留空）')),
        Gutter(child: AppTextField(controller: _serving, hint: '例如：一片')),
        if (!_isSize && widget.editing != null) ...[
          Gutter(child: const SectionLabel('杯型')),
          for (final size in _sizes)
            Gutter(
              child: AppCard(
                padding: EdgeInsets.zero,
                child: NavRow(
                  title: size.sizeName,
                  subtitle:
                      '${size.servingDescription} · '
                      '${formatKcalOrDash(size.kcal)} kcal',
                  onTap: () => _editSize(size),
                ),
              ),
            ),
          Gutter(
            child: SecondaryButton(label: '新增杯型', onPressed: _addSize),
          ),
          Gutter(
            child: const Text(
              '每個杯型有自己的數字。大杯不是小杯放大——星巴克美式短杯 98 mg、'
              '中杯 195 mg，容量只差 1.5 倍。',
              style: AppTextStyles.caption,
            ),
          ),
        ],
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
