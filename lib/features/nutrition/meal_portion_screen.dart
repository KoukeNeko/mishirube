import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/engines/food_portion.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'meal_detail_screen.dart';
import 'nutrition_view_model.dart';
import 'portion_screen.dart';
import 'recent_meal_row.dart';
import '../../l10n/l10n.dart';

/// Asks how much of [recent] is eaten this time, as times what it was,
/// and resolves to that; null when the user backed out.
Future<double?> showMealPortionScreen(
  BuildContext context,
  RecentMeal recent,
) => pushPage<double>(context, MealPortionScreen(recent: recent));

/// A meal eaten before, at the portion about to be logged: its figures
/// scaled to the servings typed, or to the amount when the meal was a
/// weight or volume, as they will be written.
class MealPortionScreen extends StatefulWidget {
  const MealPortionScreen({super.key, required this.recent});

  final RecentMeal recent;

  @override
  State<MealPortionScreen> createState() => _MealPortionScreenState();
}

class _MealPortionScreenState extends State<MealPortionScreen> {
  /// What a meal is most often eaten as, against what it was.
  static const _presets = [0.5, 1.0, 1.5, 2.0];

  late final _nutrition = NutritionViewModel(
    AppStoreScope.read(context).backend,
  );

  /// How much the meal was as a weight or volume, when its record says
  /// so: the amount can then be typed in that unit, or one converting to
  /// it.
  late final _measure = measuredMealAmount(widget.recent.meal);
  late ServingUnit _unit = _measure?.$2 ?? ServingUnit.serving;
  final _servings = TextEditingController(text: '1');
  late final _amount = TextEditingController(
    text: formatAmount(_measure?.$1 ?? 0),
  );

  /// The portion, as times the meal was. The fields show it rounded, so
  /// it is kept here exactly: typing in one writes the other from it, and
  /// choosing a unit leaves it where it is.
  double _factor = 1;

  /// Set while the fields are written from [_factor], so that is not read
  /// as typing.
  bool _isWriting = false;

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
    _nutrition.dispose();
    super.dispose();
  }

  void _onServingsTyped() {
    if (!_isWriting) _setFactor(_read(_servings), typedIn: _servings);
  }

  void _onAmountTyped() {
    if (_isWriting) return;
    if (_measure case (final amount, final unit)) {
      _setFactor(
        _unit.convert(_read(_amount), unit) / amount,
        typedIn: _amount,
      );
    }
  }

  /// Makes the portion [factor] times the meal, and writes it into the
  /// fields other than the one being typed in.
  void _setFactor(double factor, {TextEditingController? typedIn}) {
    setState(() {
      _factor = factor;
      _isWriting = true;
      if (typedIn != _servings) _servings.text = formatAmount(factor);
      if (_measure case (final amount, final unit) when typedIn != _amount) {
        _amount.text = formatAmount(unit.convert(amount * factor, _unit));
      }
      _isWriting = false;
    });
  }

  void _pickUnit(ServingUnit unit) {
    _unit = unit;
    _setFactor(_factor);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final serving = ServingUnit.serving.labelIn(l10n);
    final factor = _factor;
    final measure = _measure;
    return DetailPage(
      appBar: PageAppBar(
        title: widget.recent.label,
        subtitle: mealWhenLabel(context, widget.recent.eatenAt),
      ),
      footer: PrimaryButton(
        label: l10n.addPortion(
          // As the log will write it, which the dishes above show too.
          portion: measure == null
              ? '${formatQuantity(factor)} $serving'
              : '${formatQuantity(measure.$1 * factor)} '
                    '${measure.$2.labelIn(l10n)}',
        ),
        onPressed: factor > 0 ? () => Navigator.of(context).pop(factor) : null,
      ),
      children: [
        Gutter(
          child: Row(
            children: [
              Expanded(
                child: PortionField(
                  label: l10n.servingsLabel,
                  controller: _servings,
                  suffix: serving,
                ),
              ),
              if (measure != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: PortionField(
                    label: l10n.actualAmount,
                    controller: _amount,
                    suffix: _unit.labelIn(l10n),
                  ),
                ),
              ],
            ],
          ),
        ),
        Gutter(
          child: ChipWrap(
            options: _presets,
            labelOf: (preset) => '${formatAmount(preset)} $serving',
            isSelected: (preset) => preset == factor,
            onTap: _setFactor,
          ),
        ),
        if (measure != null && measure.$2.comparable.length > 1)
          Gutter(
            child: ChipWrap(
              options: measure.$2.comparable.toList(),
              labelOf: (unit) => unit.labelIn(l10n),
              isSelected: (unit) => unit == _unit,
              onTap: _pickUnit,
            ),
          ),
        ...mealFigures(
          context,
          scaledMeal(widget.recent.meal, factor),
          _nutrition.convention,
        ),
      ],
    );
  }
}
