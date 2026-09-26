import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/engines/food_portion.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../me/ai_settings_screen.dart';
import 'camera_screen.dart';
import 'describe_meal_screen.dart';
import 'meal_type_picker.dart';
import 'nutrition_view_model.dart';

/// Creating or correcting one of the user's own foods, logging one as a
/// quick record, or correcting a logged meal: one form for all of them.
///
/// Every number here is typed by hand, so the screen never dresses them
/// up as a lookup: what goes in is what comes back out.
class FoodEditScreen extends StatefulWidget {
  const FoodEditScreen({
    super.key,
    this.editing,
    this.initialName = '',
    this.sizeOf,
    this.takePhoto,
    this.logsOnce = false,
    this.meal,
  });

  /// The food being corrected; null when adding a new one.
  final FoodItem? editing;

  final String initialName;

  /// The food this new one is a cup size of, when it is one. A size
  /// carries its own figures: a bigger cup is not the smaller one
  /// scaled up, because the shot count changes too.
  final FoodItem? sizeOf;

  /// Takes the photo for a scan titled [title] — 食物 or 營養標示 — and
  /// returns its path, or null when cancelled: the app's camera, with the
  /// library beside the shutter, unless a test hands one in.
  final Future<String?> Function(String title)? takePhoto;

  /// 快速記錄: the same form, logged as one serving eaten now and, unless
  /// 存入食物庫 is switched on, not kept as a food. For the things nobody
  /// plans to eat again — a colleague's birthday cake, a stall on holiday
  /// — which would only fill the list with entries never picked twice.
  /// Pops the food that was logged.
  final bool logsOnce;

  /// A logged meal being corrected: its time and sitting join the form,
  /// and a food's own parts (brand, serving, sizes, the label's basis)
  /// leave it, since a record keeps what was eaten, not a food. Saving
  /// confirms the figures, so an estimate stops being one. Pops `true`
  /// when the meal was deleted.
  final MealEvent? meal;

  @override
  State<FoodEditScreen> createState() => _FoodEditScreenState();
}

class _FoodEditScreenState extends State<FoodEditScreen> {
  late final NutritionViewModel _nutrition;
  late final _name = TextEditingController(
    text:
        widget.meal?.name ??
        widget.editing?.name ??
        widget.sizeOf?.name ??
        widget.initialName,
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
  /// The meal a quick record is logged under, or a logged meal was;
  /// none unless picked.
  late MealType? _mealType = widget.meal?.mealType;

  /// When a logged meal was eaten; changed here, the meal moves, to
  /// another day too.
  late DateTime? _eatenAt = switch (widget.meal) {
    final meal? => _nutrition.eatenAtOf(meal.id),
    null => null,
  };

  /// What a logged drink came to, when it has a volume.
  late final _millilitres = TextEditingController(
    text: widget.meal?.millilitres?.toString() ?? '',
  );

  String? _error;

  /// A drink's alcohol by volume, in %: not kept, only a way to fill in
  /// the grams of alcohol a label rarely prints.
  final _abv = TextEditingController();

  /// Whether a quick record also keeps the food in the library.
  bool _keepsFood = false;

  late ConsumptionKind _kind =
      widget.meal?.kind ??
      widget.editing?.kind ??
      widget.sizeOf?.kind ??
      _kindForUnit;

  late final _kcal = _figure(widget.meal?.kcal ?? widget.editing?.kcal);
  late final _protein = _figure(
    widget.meal?.proteinGrams ?? widget.editing?.proteinGrams,
  );
  late final _carb = _figure(
    widget.meal?.carbGrams ?? widget.editing?.carbGrams,
  );
  late final _fat = _figure(widget.meal?.fatGrams ?? widget.editing?.fatGrams);
  late final _fibre = _figure(
    widget.meal?.fibreGrams ?? widget.editing?.fibreGrams,
  );

  /// One field per nutrient. A field left empty stays out of the food:
  /// unknown is not zero.
  late final _extra = {
    for (final nutrient in Nutrient.values)
      nutrient: _figure(
        widget.meal?.nutrients[nutrient] ?? widget.editing?.nutrients[nutrient],
      ),
  };

  /// A stored figure, shown in the column it was typed from: a food's
  /// per 100 when its label was, a meal's as it is.
  TextEditingController _figure(num? stored) {
    if (stored == null) return TextEditingController();
    final food = widget.editing;
    final shown = food != null && food.caffeineBasis == CaffeineBasis.per100
        ? stored / food.servingAmount * 100
        : stored.toDouble();
    return TextEditingController(text: formatAmount(shown));
  }

  @override
  void initState() {
    super.initState();
    _nutrition = NutritionViewModel(AppStoreScope.read(context).backend);
    for (final controller in [_name, _sizeName, _servingAmount]) {
      controller.addListener(() => setState(() {}));
    }
    for (final controller in [_abv, _servingAmount, _millilitres]) {
      controller.addListener(_fillAlcohol);
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
      _millilitres,
      _abv,
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

  /// What is being read, while it is: a label or a food photo.
  _Scan? _scanning;

  /// What the last scan filled in, for the note that says to check it:
  /// a label's figures, or a photo's estimate.
  FoodLabelDraft? _scanned;
  MealDraft? _estimated;
  AiFailure? _scanFailure;

  /// Set when a photo's estimate filled the form: its figures are the
  /// model's guess, not what a packet declares.
  NutrientValueType? _valueType;

  /// The app's camera page for [scan], whose library button picks at the
  /// size that scan needs: a label's small print needs more than a plate
  /// does.
  Future<String?> Function(String title) _takeWithCamera(_Scan scan) =>
      (title) => takePhoto(
        context,
        title,
        maxSide: scan == _Scan.food ? foodPhotoMaxSide : 2400,
      );

  /// A food photo or a nutrition label, from the camera or the library,
  /// read into the form. Nothing is saved: the user checks every number
  /// here and saves as usual.
  Future<void> _scan() async {
    final store = AppStoreScope.read(context);
    if (store.aiProvider == null) {
      await pushPage<void>(context, const AiSettingsScreen());
      return;
    }
    final scan = await showAppDialog<_Scan>(
      context,
      AppDialog(
        title: '掃描',
        isChoiceList: true,
        actions: [
          DialogAction(
            icon: Icons.restaurant_outlined,
            label: '食物',
            detail: '估算營養',
            onTap: () => Navigator.of(context).pop(_Scan.food),
          ),
          DialogAction(
            icon: Icons.document_scanner_outlined,
            label: '營養標示',
            detail: '讀取標示數字',
            onTap: () => Navigator.of(context).pop(_Scan.label),
          ),
          DialogAction(label: '取消', onTap: () => Navigator.of(context).pop()),
        ],
      ),
    );
    if (scan == null || !mounted) return;
    final title = switch (scan) {
      _Scan.food => '食物',
      _Scan.label => '營養標示',
    };
    final path = await (widget.takePhoto ?? _takeWithCamera(scan))(title);
    if (path == null || !mounted) return;
    switch (scan) {
      case _Scan.label:
        await _readLabel(path);
      case _Scan.food:
        // What only the eater knows: how much rice, how sweet the tea.
        final note = await showTextDialog(
          context,
          title: '補充說明',
          hint: '選填，例如：飯半碗、微糖少冰',
          confirmLabel: '估算',
          maxLines: 2,
        );
        if (note == null || !mounted) return;
        await _estimatePhoto(path, note);
    }
  }

  Future<void> _estimatePhoto(String path, String note) async {
    final store = AppStoreScope.read(context);
    setState(() {
      _scanning = _Scan.food;
      _scanFailure = null;
    });
    try {
      final draft = await store.draftMealPhoto(path, note: note);
      if (!mounted) return;
      setState(() => _scanning = null);
      await _useEstimate(draft);
    } on AiException catch (error) {
      if (!mounted) return;
      if (error.failure == AiFailure.needsPhotoConsent) {
        setState(() => _scanning = null);
        if (await askPhotoConsent(context)) await _estimatePhoto(path, note);
        return;
      }
      setState(() => _scanFailure = error.failure);
    } finally {
      if (mounted) setState(() => _scanning = null);
    }
  }

  /// One item fills the form. Several are a plate: kept together as one
  /// food, or logged item by item as a meal, which is the user's call —
  /// a lunch box is rarely a food anyone picks again.
  Future<void> _useEstimate(MealDraft draft) async {
    if (draft.items.length == 1) {
      _fillFromPhoto(draft);
      return;
    }
    final names = draft.items.map((item) => item.name).join('、');
    final choice = await showAppDialog<bool>(
      context,
      AppDialog(
        title: '照片裡有 ${draft.items.length} 項',
        message: names,
        actions: [
          DialogAction(
            label: '合併成一個食物',
            onTap: () => Navigator.of(context).pop(true),
          ),
          DialogAction(
            label: '逐項記錄',
            tone: DialogTone.primary,
            onTap: () => Navigator.of(context).pop(false),
          ),
          DialogAction(label: '取消', onTap: () => Navigator.of(context).pop()),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    if (choice) {
      _fillFromPhoto(draft);
      return;
    }
    final toast = ToastScope.read(context);
    final logged = await pushPage<List<MealEvent>>(
      context,
      DescribeMealScreen(draft: draft, mealType: _mealType),
    );
    if (logged == null || logged.isEmpty || !mounted) return;
    Navigator.of(context).pop();
    toast.showUndo(
      '已記錄 ${logged.length} 項',
      onUndo: () => _nutrition.deleteMeals(logged),
    );
  }

  /// Puts a photo's estimate into the form as one serving: every item
  /// added up, so a figure any item lacks is left empty rather than
  /// undercounted. The name typed so far is kept.
  void _fillFromPhoto(MealDraft draft) {
    final items = draft.items;
    double? total(int? Function(DraftItem) figure) {
      final figures = items.map(figure);
      if (figures.any((value) => value == null)) return null;
      return figures.fold<double>(0, (sum, value) => sum + value!);
    }

    void put(TextEditingController field, double? value) =>
        field.text = value == null ? '' : formatAmount(value);
    final amounts = items.map((item) => _measuredAmount(item.amount)).toList();
    final unit = amounts.firstOrNull?.$2;
    final isMeasured =
        amounts.every((amount) => amount != null && amount.$2 == unit) &&
        unit != null;
    setState(() {
      if (_name.text.trim().isEmpty) {
        _name.text = items.map((item) => item.name).join('、');
      }
      _servingUnit = isMeasured ? unit : ServingUnit.serving;
      _servingAmount.text = formatAmount(
        isMeasured ? amounts.fold(0.0, (sum, amount) => sum + amount!.$1) : 1,
      );
      _kind = items.every((item) => item.isDrink)
          ? ConsumptionKind.beverage
          : ConsumptionKind.food;
      _basis = CaffeineBasis.serving;
      put(_kcal, total((item) => item.kcal));
      put(_protein, total((item) => item.proteinGrams));
      put(_carb, total((item) => item.carbGrams));
      put(_fat, total((item) => item.fatGrams));
      _valueType = NutrientValueType.estimate;
      _estimated = draft;
      _scanned = null;
    });
  }

  /// The first weight or volume in a model's amount (「約 180 g（150–220 g）」
  /// is 180 g), or null when it gave none.
  static (double, ServingUnit)? _measuredAmount(String amount) {
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*(g|公克|克|ml|mL|毫升)')
        .firstMatch(amount);
    if (match == null) return null;
    final value = double.parse(match.group(1)!);
    final unit = switch (match.group(2)) {
      'ml' || 'mL' || '毫升' => ServingUnit.millilitre,
      _ => ServingUnit.gram,
    };
    return (value, unit);
  }

  Future<void> _readLabel(String path) async {
    final store = AppStoreScope.read(context);
    setState(() {
      _scanning = _Scan.label;
      _scanFailure = null;
    });
    try {
      _fillFrom(await store.scanFoodLabel(path));
    } on AiException catch (error) {
      if (!mounted) return;
      if (error.failure == AiFailure.needsConsent) {
        setState(() => _scanning = null);
        if (await askCloudConsent(context)) await _readLabel(path);
        return;
      }
      setState(() => _scanFailure = error.failure);
    } finally {
      if (mounted) setState(() => _scanning = null);
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
      _estimated = null;
      _valueType = null;
    });
  }

  /// Saves, and says whether the caller should log it straight away.
  ///
  /// Popping the food means "log this now"; popping nothing means it was
  /// only saved. Filling in a whole label and then being sent back to
  /// the list to find it again is a round trip with nothing in it.
  void _save({required bool logNow}) {
    final food = _food();
    _nutrition.saveFood(food);
    Navigator.of(context).pop(logNow ? food : null);
  }

  /// Logs the form as one serving eaten now, keeping the food only when
  /// asked to.
  void _logOnce() {
    final food = _food();
    if (_keepsFood) {
      _nutrition.saveFood(food);
      _nutrition.logPortions([FoodPortion(food, 1)], mealType: _mealType);
    } else {
      _nutrition.logOnce(food, mealType: _mealType);
    }
    Navigator.of(context).pop(food);
  }

  Future<void> _pickTime() async {
    final picked = await pickDateTime(
      context,
      initial: _eatenAt ?? _nutrition.now(),
      latest: _nutrition.now(),
    );
    if (picked == null || !mounted) return;
    setState(() => _eatenAt = picked);
  }

  /// Saves the form over the logged meal. An empty figure is one nobody
  /// wrote down, not zero; a negative one is nonsense either way.
  void _saveMeal(MealEvent meal) {
    final figures = [_kcal, _protein, _carb, _fat, _fibre, ..._extra.values];
    if (figures.any((field) => (double.tryParse(field.text.trim()) ?? 0) < 0)) {
      setState(() => _error = '營養素不能是負數。');
      return;
    }
    int? whole(TextEditingController field) => _perServing(field)?.round();
    if (_eatenAt case final eatenAt?
        when eatenAt != _nutrition.eatenAtOf(meal.id)) {
      _nutrition.retimeMeal(meal, eatenAt);
    }
    final name = _name.text.trim();
    _nutrition.updateMeal(
      meal,
      // Built by hand rather than with copyWith, which cannot put a
      // figure back to "nobody wrote this down".
      MealEvent(
        id: meal.id,
        name: name,
        timeLabel: meal.timeLabel,
        dishes: meal.dishes,
        nutrients: _typedNutrients(),
        millilitres: meal.millilitres == null
            ? null
            : int.tryParse(_millilitres.text.trim()) ?? meal.millilitres,
        kind: _kind,
        mealType: _mealType,
        foodId: meal.foodId,
        servings: meal.servings,
        groupId: meal.groupId,
        valueType: meal.valueType,
        isFavorite: meal.isFavorite,
        kcal: whole(_kcal),
        proteinGrams: whole(_protein),
        carbGrams: whole(_carb),
        fatGrams: whole(_fat),
        fibreGrams: whole(_fibre),
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

  /// A tombstone, taken back from the toast, as a workout's delete is.
  void _deleteMeal(MealEvent meal) {
    final toast = ToastScope.read(context);
    _nutrition.deleteMeals([meal]);
    Navigator.of(context).pop(true);
    toast.showUndo(
      '已刪除「${meal.name}」',
      onUndo: () => _nutrition.restoreMeals([meal]),
    );
  }

  /// Ethanol's density, g per mL: what turns a drink's volume and its
  /// alcohol by volume into grams of alcohol.
  static const _ethanolDensity = 0.789;

  /// The mL the figures being typed are for: a logged drink's volume, or
  /// a food's serving in a unit of volume, or 100 mL when its label is
  /// typed per 100; null when the form holds no volume.
  double? get _typedVolume {
    if (widget.meal != null) return double.tryParse(_millilitres.text.trim());
    if (_servingUnit.dimension != ServingDimension.volume) return null;
    return _effectiveBasis == CaffeineBasis.per100
        ? 100
        : _amount * _servingUnit.inBaseUnit;
  }

  /// Fills in the grams of alcohol from the alcohol by volume, when both
  /// it and the volume are there to work it out from.
  void _fillAlcohol() {
    final abv = double.tryParse(_abv.text.trim());
    final volume = _typedVolume;
    if (abv == null || volume == null || abv < 0 || abv > 100) return;
    final grams = volume * abv / 100 * _ethanolDensity;
    // To a tenth of a gram, as a label would print it.
    _extra[Nutrient.alcohol]!.text = formatAmount((grams * 10).round() / 10);
  }

  /// The food as the form has it.
  FoodItem _food() {
    return FoodItem(
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
          _valueType ??
          widget.editing?.valueType ??
          widget.sizeOf?.valueType ??
          NutrientValueType.declared,
      sourceUrl: widget.editing?.sourceUrl ?? widget.sizeOf?.sourceUrl ?? '',
      checkedAt: widget.editing?.checkedAt ?? widget.sizeOf?.checkedAt,
    );
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

  Widget _nutrientField(Nutrient nutrient) => NumberFieldRow(
    label: nutrient.label,
    unit: nutrient.unit.label,
    controller: _extra[nutrient]!,
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _nutrition,
    builder: (context, _) => _page(context),
  );

  Widget _page(BuildContext context) {
    final meal = widget.meal;
    final isNew = widget.editing == null && meal == null;
    return DetailPage(
      appBar: PageAppBar(
        title: meal != null
            ? '編輯這一餐'
            : widget.logsOnce
            ? '快速記錄'
            : (isNew ? '新增食物' : '編輯食物'),
        actions: [
          if (isNew && !_isSize)
            HeaderAction(
              icon: Icons.photo_camera_outlined,
              label: '掃描',
              semanticLabel: '掃描食物或營養標示',
              onTap: _scanning != null ? null : _scan,
            ),
        ],
      ),
      footer: meal != null
          ? PrimaryButton(
              label: '儲存',
              onPressed: _canSave ? () => _saveMeal(meal) : null,
            )
          : widget.logsOnce
          ? PrimaryButton(label: '記錄', onPressed: _canSave ? _logOnce : null)
          : isNew && !_isSize
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
        if (_scanning case final scan?)
          Gutter(
            child: InfoBanner(
              icon: Icons.document_scanner_outlined,
              message: switch (scan) {
                _Scan.label => '正在辨識營養標示…',
                _Scan.food => '正在估算…',
              },
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
          )
        else if (_estimated case final draft?)
          Gutter(
            child: InfoBanner(
              icon: Icons.fact_check_outlined,
              tone: draft.warnings.isEmpty
                  ? CardTone.neutral
                  : CardTone.warning,
              message: [
                '數字是 ${draft.provider.label}（${draft.model}）從照片的估算，'
                    '請核對。',
                ...draft.warnings,
              ].join('\n'),
            ),
          ),
        Gutter(child: const SectionLabel('名稱')),
        Gutter(
          child: AppTextField(controller: _name, hint: '例如：雞胸肉'),
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
        if (widget.logsOnce || meal != null) ...[
          Gutter(child: const SectionLabel('餐次（選填）')),
          Gutter(
            child: MealTypePicker(
              selected: _mealType,
              // Not on a logged meal: the user already had their chance
              // to label it, and an offer then is second-guessing them.
              suggested: meal == null ? _nutrition.suggestedMealType() : null,
              onChanged: (type) => setState(() => _mealType = type),
            ),
          ),
        ],
        if (widget.logsOnce) ...[
          Gutter(
            child: GroupedCard(
              children: [
                SwitchRow(
                  title: '存入食物庫',
                  value: _keepsFood,
                  onChanged: (keeps) => setState(() => _keepsFood = keeps),
                ),
              ],
            ),
          ),
        ],
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
        if (meal == null) ...[
          Gutter(child: const SectionLabel('品牌（選填）')),
          Gutter(
            child: AppTextField(controller: _brand, hint: '例如：大成'),
          ),
        ],
        Gutter(child: const SectionLabel('食物或飲品')),
        Gutter(
          child: ChipWrap(
            options: ConsumptionKind.values,
            labelOf: (kind) => kind.label,
            isSelected: (kind) => kind == _kind,
            onTap: (kind) => setState(() => _kind = kind),
          ),
        ),
        if (meal case final meal? when meal.millilitres != null)
          Gutter(
            child: NumberFieldRow(
              label: '容量',
              unit: 'mL',
              controller: _millilitres,
            ),
          ),
        if (meal == null) ...[
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
        ],
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
        Gutter(child: SectionLabel(meal == null ? '營養標示' : '營養素')),
        if (meal == null && _servingUnit.isMeasured)
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
          child: NumberFieldRow(
            label: MacroLabel.energy,
            unit: 'kcal',
            controller: _kcal,
          ),
        ),
        Gutter(
          child: NumberFieldRow(
            label: MacroLabel.protein,
            unit: 'g',
            controller: _protein,
          ),
        ),
        Gutter(
          child: NumberFieldRow(
            label: MacroLabel.carb,
            unit: 'g',
            controller: _carb,
          ),
        ),
        Gutter(
          child: NumberFieldRow(
            label: MacroLabel.fat,
            unit: 'g',
            controller: _fat,
          ),
        ),
        Gutter(
          child: NumberFieldRow(
            label: MacroLabel.fibre,
            unit: 'g',
            controller: _fibre,
          ),
        ),
        for (final nutrient in _labelNutrients)
          Gutter(child: _nutrientField(nutrient)),
        for (final nutrient in Nutrient.values)
          if (!_labelNutrients.contains(nutrient)) ...[
            if (nutrient == Nutrient.alcohol && _typedVolume != null)
              Gutter(
                child: NumberFieldRow(
                  label: '酒精度',
                  unit: '%',
                  controller: _abv,
                ),
              ),
            Gutter(child: _nutrientField(nutrient)),
          ],
        if (_error case final error?)
          Gutter(
            child: InfoBanner(tone: CardTone.warning, message: error),
          ),
        if (meal != null)
          Gutter(
            child: GroupedCard(
              children: [
                NavRow(
                  title: '刪除這一餐',
                  isDestructive: true,
                  onTap: () => _deleteMeal(meal),
                ),
              ],
            ),
          ),
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

/// What a scan reads.
enum _Scan { label, food }
