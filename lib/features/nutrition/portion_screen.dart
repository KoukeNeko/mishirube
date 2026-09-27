import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/engines/food_portion.dart';
import '../../backend/engines/nutrition_summary.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'food_edit_screen.dart';
import 'nutrition_view_model.dart';
import '../../l10n/l10n.dart';

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
    message: food.brand.isEmpty ? null : food.brandLabelIn(context.l10n),
    isChoiceList: true,
    actions: [
      for (final (index, size) in sizes.indexed)
        DialogAction(
          icon: _cupIcons[index.clamp(0, _cupIcons.length - 1)],
          label: size.sizeName,
          detail: _sizeDetail(context.l10n, size),
          onTap: () => Navigator.of(context).pop(size),
        ),
    ],
  ),
);

/// [portion] as a Japanese label lays it out: 熱量, たんぱく質, 脂質,
/// 炭水化物 with 糖質 and 食物繊維 under it, 食塩相当量, then the rest;
/// then, apart from the label, what [convention] reads its salt as.
List<Widget> _japaneseLabel(
  AppLocalizations l10n,
  FoodPortion portion,
  NutritionConvention convention,
) {
  final nutrients = portion.nutrients;
  const underCarb = [Nutrient.netCarb];
  const afterCarb = [Nutrient.saltEquivalent];
  final food = portion.food;
  // The label prints tenths of a gram; the log's whole grams would turn
  // a coffee's 0.4 g of protein into 0.
  String grams(double? perServing) => perServing == null
      ? '—'
      : '${_asPrinted(perServing * portion.servings)} g';
  KeyValueRow row(Nutrient nutrient) => KeyValueRow(
    label: japaneseLabelOf(nutrient) ?? nutrient.labelIn(l10n),
    value: '${_asPrinted(nutrients[nutrient]!)} ${nutrient.unit.label}',
  );
  return [
    KeyValueRow(
      label: JapaneseMacroLabel.energy,
      value: '${formatKcalOrDash(portion.kcal)} kcal',
    ),
    KeyValueRow(
      label: JapaneseMacroLabel.protein,
      value: grams(food.proteinGrams),
    ),
    KeyValueRow(label: JapaneseMacroLabel.fat, value: grams(food.fatGrams)),
    KeyValueRow(label: JapaneseMacroLabel.carb, value: grams(food.carbGrams)),
    for (final nutrient in underCarb)
      if (nutrients.containsKey(nutrient)) row(nutrient),
    if (food.fibreGrams != null)
      KeyValueRow(
        label: JapaneseMacroLabel.fibre,
        value: grams(food.fibreGrams),
      ),
    for (final nutrient in afterCarb)
      if (nutrients.containsKey(nutrient)) row(nutrient),
    for (final nutrient in nutrients.keys)
      if (!underCarb.contains(nutrient) && !afterCarb.contains(nutrient))
        row(nutrient),
    for (final MapEntry(key: nutrient, value: amount) in workedOut(
      nutrients,
      convention,
      labelCountry: food.country,
    ).entries)
      KeyValueRow(
        label: convention.nameOf(l10n, nutrient),
        value: l10n.workedOutValue(value: nutrient.format(amount)),
      ),
  ];
}

/// [portion] in the words of the label its food was printed with —
/// Taiwan's when it names no country the app reads — with, apart from
/// the label, what [reader]'s convention works out of it. A label whose
/// carbohydrate leaves out the fibre shows it that way.
List<Widget> _label(
  AppLocalizations l10n,
  FoodPortion portion,
  NutritionConvention reader,
) {
  final food = portion.food;
  final label =
      NutritionConvention.ofLabel(food.country) ?? NutritionConvention.taiwan;
  final made = workedOut(
    portion.nutrients,
    reader,
    carbGrams: portion.carbGrams,
    fibreGrams: portion.fibreGrams,
    labelCountry: food.country,
  );
  return [
    KeyValueRow(
      label: label.energyName(l10n),
      value: '${formatKcalOrDash(portion.kcal)} kcal',
    ),
    KeyValueRow(
      label: label.proteinName(l10n),
      value: _grams(portion.proteinGrams),
    ),
    KeyValueRow(
      label: label.carbName(l10n),
      value: label.countsAvailableCarb
          ? _grams(
              (portion.nutrients[Nutrient.netCarb] ??
                      carbLessFibre(portion.carbGrams, portion.fibreGrams))
                  ?.round(),
            )
          : _grams(portion.carbGrams),
    ),
    KeyValueRow(label: label.fatName(l10n), value: _grams(portion.fatGrams)),
    if (portion.fibreGrams != null)
      KeyValueRow(
        label: label.fibreName(l10n),
        value: _grams(portion.fibreGrams),
      ),
    // Everything else the food holds. A brand drink often knows its
    // caffeine and nothing else, and a screen that showed only the five
    // would show it as four dashes.
    for (final (nutrient, value) in nutrientLines(
      l10n,
      portion.nutrients,
      convention: reader,
      carbGrams: portion.carbGrams,
      fibreGrams: portion.fibreGrams,
      labelCountry: food.country,
    ))
      if (!(label.countsAvailableCarb && nutrient == Nutrient.netCarb))
        KeyValueRow(
          label: made.containsKey(nutrient)
              ? reader.nameOf(l10n, nutrient)
              : label.nameOf(l10n, nutrient),
          value: value,
        ),
  ];
}

/// As a Japanese label prints it, to at most three decimals: `0.054`, `0.4`.
String _asPrinted(double amount) =>
    amount.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');

/// A cup per size, smallest first; sizes past the last share it.
const _cupIcons = [
  Icons.coffee_outlined,
  Icons.local_cafe_outlined,
  Icons.local_drink_outlined,
];

/// `354 ml · 咖啡因 150 mg`: the volume, then whichever figure the size
/// has — energy when it was published, caffeine when that is all there is.
String _sizeDetail(AppLocalizations l10n, FoodItem size) {
  final caffeine = size.nutrients[Nutrient.caffeine];
  return [
    size.servingDescription(l10n),
    if (size.kcal != null)
      '${formatKcal(size.kcal!.round())} kcal'
    else if (caffeine != null)
      l10n.caffeineValue(mg: formatAmount(caffeine)),
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
      context.l10n.deletedNamed(name: food.displayName),
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
    final about = [
      if (food.brand.isNotEmpty) food.brandLabelIn(context.l10n),
      if (food.note.isNotEmpty) food.note,
      // A serving that is only a serving would read `一份 = 一份`.
      if (_isMeasured)
        context.l10n.oneServingIs(
          serving: food.servingDescription(context.l10n),
        ),
    ];
    return DetailPage(
      appBar: PageAppBar(
        // The maker goes under the name, so a long one does not push the
        // name itself out of the title.
        title: food.nameWithSize,
        subtitle: about.isEmpty ? null : about.join(' · '),
        // Food that ships with the app is read-only: the next release
        // replaces it, so an edit here would not survive.
        actions: [
          // Any food can be starred, a shipped cup size included: the star
          // is kept apart from the food, so a catalogue update keeps it.
          HeaderAction(
            icon: isStarred ? Icons.star : Icons.star_border,
            label: isStarred ? context.l10n.starred : context.l10n.starAction,
            semanticLabel: isStarred
                ? context.l10n.removeFavorite
                : context.l10n.starThisFood,
            onTap: () =>
                _nutrition.setFoodFavorite(food.id, isFavorite: !isStarred),
          ),
          if (!food.isBuiltIn)
            HeaderAction(
              icon: Icons.edit_outlined,
              label: context.l10n.commonEdit,
              semanticLabel: context.l10n.editThisFood,
              onTap: _edit,
            ),
        ],
      ),
      footer: widget.canAdd
          ? PrimaryButton(
              label: context.l10n.addPortion(
                portion: portion.labelIn(context.l10n),
              ),
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
                  label: context.l10n.servingsLabel,
                  controller: _servings,
                  suffix: ServingUnit.serving.labelIn(context.l10n),
                  onFocus: () => setState(() => _isEditingAmount = false),
                ),
              ),
              if (_isMeasured) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _PortionField(
                    label: context.l10n.actualAmount,
                    controller: _amount,
                    suffix: _unit.labelIn(context.l10n),
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
              labelOf: (unit) => unit.labelIn(context.l10n),
              isSelected: (unit) => unit == _unit,
              onTap: _pickUnit,
            ),
          ),
        Gutter(child: SectionLabel(context.l10n.nutritionLabel)),
        Gutter(
          child: AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (food.country == 'JP')
                  ..._japaneseLabel(
                    context.l10n,
                    portion,
                    _nutrition.convention,
                  )
                else
                  ..._label(context.l10n, portion, _nutrition.convention),
                if (portion.millilitres case final volume?)
                  KeyValueRow(
                    label: context.l10n.volumeLabel,
                    value: '$volume mL',
                  ),
                // As the maker declares them; a food nobody declared them
                // for says nothing rather than 無.
                if (food.barcode case final barcode?)
                  KeyValueRow(label: context.l10n.barcode, value: barcode),
                if (food.allergens case final allergens?)
                  KeyValueRow(
                    label: context.l10n.allergens,
                    value: allergens.isEmpty
                        ? context.l10n.none
                        : joinList(context.l10n, [
                            for (final allergen in Allergen.values)
                              if (allergens.contains(allergen))
                                allergen.labelIn(context.l10n),
                          ]),
                  ),
              ],
            ),
          ),
        ),
        if (type != NutrientValueType.declared)
          Gutter(
            child: Text(switch (type) {
              NutrientValueType.max => context.l10n.valueTypeMaxNote,
              NutrientValueType.estimate => context.l10n.valueTypeEstimate,
              NutrientValueType.declared => '',
            }, style: AppTextStyles.caption),
          ),
        if (food.sourceUrl.isNotEmpty)
          Gutter(
            child: Text(
              context.l10n.dataSource(source: food.sourceUrl) +
                  _checked(context, food.checkedAt),
              style: AppTextStyles.caption,
            ),
          ),
        if (!food.isBuiltIn)
          Gutter(
            child: LinkText(
              label: context.l10n.deleteThisFood,
              color: AppColors.textSecondary,
              onTap: _delete,
            ),
          ),
      ],
    );
  }
}

/// `更新 2026/9/21` on a line of its own, or nothing when the figure has
/// no date. A figure nobody can date is a figure nobody can check.
String _checked(BuildContext context, DateTime? at) => at == null
    ? ''
    : '\n${context.l10n.updatedOn(date: context.dates.date(at))}';

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
