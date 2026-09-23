import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../me/ai_settings_screen.dart';
import 'nutrition_view_model.dart';

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
    this.pickPhoto,
  });

  /// The food being corrected; null when adding a new one.
  final FoodItem? editing;

  final String initialName;

  /// The food this new one is a cup size of, when it is one. A size
  /// carries its own figures: a bigger cup is not the smaller one
  /// scaled up, because the shot count changes too.
  final FoodItem? sizeOf;

  /// Where a label photo comes from; the system picker unless a test
  /// hands one in. Returns the photo's path, or null when cancelled.
  final Future<String?> Function(ImageSource source)? pickPhoto;

  @override
  State<FoodEditScreen> createState() => _FoodEditScreenState();
}

class _FoodEditScreenState extends State<FoodEditScreen> {
  late final NutritionViewModel _nutrition;
  late final _name = TextEditingController(
    text: widget.editing?.name ?? widget.sizeOf?.name ?? widget.initialName,
  );
  late final _sizeName = TextEditingController(
    text: widget.editing?.sizeName ?? '',
  );
  late final _brand = TextEditingController(
    text: widget.editing?.brand ?? widget.sizeOf?.brand ?? '',
  );
  late final _servingAmount = TextEditingController(
    text: formatAmount(widget.editing?.servingAmount ?? 1),
  );
  late ServingUnit _servingUnit =
      widget.editing?.servingUnit ?? ServingUnit.gram;

  /// A label prints its figures for one serving, per 100 g or ml, or
  /// both; they are typed from whichever column is there. The food keeps
  /// them per serving.
  late CaffeineBasis _basis =
      widget.editing?.caffeineBasis ?? CaffeineBasis.serving;

  /// Eaten or drunk. Prefilled from the unit because that is right more
  /// often than not, but shown and changeable, because the unit does not
  /// actually decide it: soup is poured and is not a drink.
  late ConsumptionKind _kind =
      widget.editing?.kind ?? widget.sizeOf?.kind ?? _kindForUnit;

  late final _kcal = _figure(widget.editing?.kcal);
  late final _protein = _figure(widget.editing?.proteinGrams);
  late final _carb = _figure(widget.editing?.carbGrams);
  late final _fat = _figure(widget.editing?.fatGrams);
  late final _fibre = _figure(widget.editing?.fibreGrams);

  /// One field per nutrient. A field left empty stays out of the food:
  /// unknown is not zero.
  late final _extra = {
    for (final nutrient in Nutrient.values)
      nutrient: _figure(widget.editing?.nutrients[nutrient]),
  };

  /// A stored per-serving figure, shown in the column it was typed from.
  TextEditingController _figure(num? perServing) {
    final food = widget.editing;
    if (perServing == null || food == null) return TextEditingController();
    final shown = food.caffeineBasis == CaffeineBasis.per100
        ? perServing / food.servingAmount * 100
        : perServing.toDouble();
    return TextEditingController(text: formatAmount(shown));
  }

  @override
  void initState() {
    super.initState();
    _nutrition = NutritionViewModel(AppStoreScope.read(context).backend);
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
    _nutrition.dispose();
    super.dispose();
  }

  /// The sizes of the food being edited. A new food has none until it
  /// is saved, because a size has to belong to something.
  List<FoodItem> get _sizes => widget.editing == null
      ? const []
      : _nutrition.sizesOf(widget.editing!.id);

  ConsumptionKind get _kindForUnit => switch (_servingUnit.dimension) {
    ServingDimension.volume => ConsumptionKind.beverage,
    ServingDimension.mass => ConsumptionKind.food,
    ServingDimension.count => ConsumptionKind.unknown,
  };

  double get _amount => double.tryParse(_servingAmount.text.trim()) ?? 0;

  /// Per 100 only makes sense for grams or millilitres.
  CaffeineBasis get _effectiveBasis =>
      _servingUnit.isMeasured ? _basis : CaffeineBasis.serving;

  /// What [field] comes to in one serving, or null when it is empty.
  double? _perServing(TextEditingController field) {
    final typed = double.tryParse(field.text.trim());
    if (typed == null || typed < 0) return null;
    return _effectiveBasis == CaffeineBasis.per100
        ? typed * _amount / 100
        : typed;
  }

  bool get _isSize => widget.sizeOf != null || widget.editing?.isSize == true;

  bool get _canSave =>
      _name.text.trim().isNotEmpty &&
      _amount > 0 &&
      (!_isSize || _sizeName.text.trim().isNotEmpty);

  bool _isScanning = false;

  /// What the last scan filled in, for the note that says to check it.
  FoodLabelDraft? _scanned;
  AiFailure? _scanFailure;

  static Future<String?> _pickWithSystemPicker(ImageSource source) async =>
      (await ImagePicker().pickImage(
        source: source,
        // Large enough to read small print, small enough not to strain
        // memory on the phone while it is read.
        maxWidth: 2400,
        maxHeight: 2400,
      ))?.path;

  /// A photo of the nutrition label, from the camera or the library,
  /// read into the form. Nothing is saved: the user checks every number
  /// here and saves as usual.
  Future<void> _scan() async {
    final store = AppStoreScope.read(context);
    if (store.aiProvider == null) {
      await pushPage<void>(context, const AiSettingsScreen());
      return;
    }
    final source = await showAppDialog<ImageSource>(
      context,
      AppDialog(
        title: '掃描營養標示',
        isChoiceList: true,
        actions: [
          DialogAction(
            icon: Icons.photo_camera_outlined,
            label: '拍照',
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          DialogAction(
            icon: Icons.photo_library_outlined,
            label: '從相簿選取',
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
          DialogAction(label: '取消', onTap: () => Navigator.of(context).pop()),
        ],
      ),
    );
    if (source == null || !mounted) return;
    final path = await (widget.pickPhoto ?? _pickWithSystemPicker)(source);
    if (path == null || !mounted) return;
    await _readLabel(path);
  }

  Future<void> _readLabel(String path) async {
    final store = AppStoreScope.read(context);
    setState(() {
      _isScanning = true;
      _scanFailure = null;
    });
    try {
      _fillFrom(await store.scanFoodLabel(path));
    } on AiException catch (error) {
      if (!mounted) return;
      if (error.failure == AiFailure.needsConsent) {
        setState(() => _isScanning = false);
        if (await askCloudConsent(context)) await _readLabel(path);
        return;
      }
      setState(() => _scanFailure = error.failure);
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  /// Puts what the label said into the fields. A name already typed is
  /// kept; a figure the label did not give leaves its field as it was.
  void _fillFrom(FoodLabelDraft draft) {
    if (!mounted) return;
    void put(TextEditingController field, num? value) {
      if (value != null) field.text = formatAmount(value.toDouble());
    }

    setState(() {
      if (_name.text.trim().isEmpty && draft.name != null) {
        _name.text = draft.name!;
      }
      if (_brand.text.trim().isEmpty && draft.brand != null) {
        _brand.text = draft.brand!;
      }
      if (draft.servingUnit case final unit?) {
        final wasSuggested = _kind == _kindForUnit;
        _servingUnit = unit;
        if (wasSuggested) _kind = _kindForUnit;
      }
      put(_servingAmount, draft.servingAmount);
      // A draft is read off the per-serving column.
      _basis = CaffeineBasis.serving;
      put(_kcal, draft.kcal);
      put(_protein, draft.proteinGrams);
      put(_carb, draft.carbGrams);
      put(_fat, draft.fatGrams);
      put(_fibre, draft.fibreGrams);
      for (final MapEntry(key: nutrient, value: amount)
          in draft.nutrients.entries) {
        put(_extra[nutrient]!, amount);
      }
      _scanned = draft;
    });
  }

  /// Saves, and says whether the caller should log it straight away.
  ///
  /// Popping the food means "log this now"; popping nothing means it was
  /// only saved. Filling in a whole label and then being sent back to
  /// the list to find it again is a round trip with nothing in it.
  void _save({required bool logNow}) {
    final food = FoodItem(
      id: widget.editing?.id ?? _nutrition.newFoodId(),
      name: _name.text.trim(),
      brand: _brand.text.trim(),
      // No longer asked for; an older food keeps the one it had.
      servingLabel: widget.editing?.servingLabel ?? '',
      servingAmount: _amount,
      servingUnit: _servingUnit,
      caffeineBasis: _effectiveBasis,
      kcal: _perServing(_kcal),
      proteinGrams: _perServing(_protein),
      carbGrams: _perServing(_carb),
      fatGrams: _perServing(_fat),
      fibreGrams: _perServing(_fibre),
      nutrients: _typedNutrients(),
      parentId: widget.sizeOf?.id ?? widget.editing?.parentId,
      sizeName: _sizeName.text.trim(),
      kind: _kind,
      // Not asked: hand-typed figures are what the packet says, and a
      // size keeps the kind of figure its drink has.
      valueType:
          widget.editing?.valueType ??
          widget.sizeOf?.valueType ??
          NutrientValueType.declared,
      sourceUrl: widget.editing?.sourceUrl ?? widget.sizeOf?.sourceUrl ?? '',
      checkedAt: widget.editing?.checkedAt ?? widget.sizeOf?.checkedAt,
    );
    _nutrition.saveFood(food);
    Navigator.of(context).pop(logNow ? food : null);
  }

  /// Only the nutrients with a number in them. An empty field leaves the
  /// nutrient out of the food entirely, because not written down is not
  /// the same as zero.
  Nutrients _typedNutrients() => {
    for (final MapEntry(key: nutrient, value: field) in _extra.entries)
      nutrient: ?_perServing(field),
  };

  /// The cups this brand already uses. A shop's sizes are a fixed set,
  /// so the second drink from it should offer the same ones.
  List<String> _brandSizeNames() {
    final brand = _brand.text.trim();
    if (brand.isEmpty) return const [];
    return _nutrition
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _nutrition,
    builder: (context, _) => _page(context),
  );

  Widget _page(BuildContext context) {
    final isNew = widget.editing == null;
    return DetailPage(
      appBar: PageAppBar(
        title: isNew ? '新增食物' : '編輯食物',
        actions: [
          if (isNew && !_isSize)
            HeaderAction(
              icon: Icons.document_scanner_outlined,
              label: '掃描標示',
              semanticLabel: '掃描營養標示',
              onTap: _isScanning ? null : _scan,
            ),
        ],
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
              label: '儲存',
              onPressed: _canSave ? () => _save(logNow: false) : null,
            ),
      children: [
        if (_isScanning)
          Gutter(
            child: const InfoBanner(
              icon: Icons.document_scanner_outlined,
              message: '正在辨識營養標示…',
            ),
          )
        else if (_scanFailure case final failure?)
          Gutter(
            child: InfoBanner(
              tone: CardTone.warning,
              message: aiFailureMessage(failure),
            ),
          )
        else if (_scanned case final draft?)
          Gutter(
            child: InfoBanner(
              icon: Icons.fact_check_outlined,
              tone: draft.warnings.isEmpty
                  ? CardTone.neutral
                  : CardTone.warning,
              message: [
                '數字來自 ${draft.provider.label}（${draft.model}）的判讀，'
                    '請對照包裝核對。',
                ...draft.warnings,
              ].join('\n'),
            ),
          ),
        Gutter(child: const SectionLabel('名稱')),
        Gutter(
          child: AppTextField(controller: _name, hint: '例如：雞胸肉'),
        ),
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
        Gutter(child: const SectionLabel('品牌（選填）')),
        Gutter(
          child: AppTextField(controller: _brand, hint: '例如：大成'),
        ),
        Gutter(child: const SectionLabel('食物或飲品')),
        Gutter(
          child: ChipWrap(
            options: ConsumptionKind.values,
            labelOf: (kind) => kind.label,
            isSelected: (kind) => kind == _kind,
            onTap: (kind) => setState(() => _kind = kind),
          ),
        ),
        Gutter(child: const SectionLabel('份量')),
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
            onTap: (unit) => setState(() {
              final wasSuggested = _kind == _kindForUnit;
              _servingUnit = unit;
              if (wasSuggested) _kind = _kindForUnit;
            }),
          ),
        ),
        if (!_isSize && widget.editing != null) ...[
          Gutter(child: const SectionLabel('杯型')),
          for (final size in _sizes)
            Gutter(
              child: NavCard(
                title: size.sizeName,
                subtitle:
                    '${size.servingDescription} · '
                    '${formatKcalOrDash(size.kcal?.round())} kcal',
                onTap: () => _editSize(size),
              ),
            ),
          Gutter(
            child: SecondaryButton(label: '新增杯型', onPressed: _addSize),
          ),
        ],
        Gutter(child: const SectionLabel('營養標示')),
        if (_servingUnit.isMeasured)
          Gutter(
            child: ChipWrap(
              options: CaffeineBasis.values,
              labelOf: (basis) => switch (basis) {
                CaffeineBasis.per100 => '每 100 ${_servingUnit.label}',
                CaffeineBasis.serving => '一份總共',
              },
              isSelected: (basis) => basis == _basis,
              onTap: (basis) => setState(() => _basis = basis),
            ),
          ),
        Gutter(
          child: _NumberField(
            label: MacroLabel.energy,
            unit: 'kcal',
            field: _kcal,
          ),
        ),
        Gutter(
          child: _NumberField(
            label: MacroLabel.protein,
            unit: 'g',
            field: _protein,
          ),
        ),
        Gutter(
          child: _NumberField(label: MacroLabel.carb, unit: 'g', field: _carb),
        ),
        Gutter(
          child: _NumberField(label: MacroLabel.fat, unit: 'g', field: _fat),
        ),
        Gutter(
          child: _NumberField(
            label: MacroLabel.fibre,
            unit: 'g',
            field: _fibre,
          ),
        ),
        for (final nutrient in _labelNutrients)
          Gutter(child: _nutrientField(nutrient)),
        for (final nutrient in Nutrient.values)
          if (!_labelNutrients.contains(nutrient))
            Gutter(child: _nutrientField(nutrient)),
      ],
    );
  }
}

/// What Taiwan's packaging law makes every label print, beyond the five
/// the form asks for first. These are the ones a user can actually copy
/// off the back of a packet, so they come before the rest.
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
