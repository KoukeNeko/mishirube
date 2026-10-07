import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../l10n/l10n.dart';

/// Bumped whenever the arithmetic below changes.
const foodPortionVersion = 3;

/// How much of a food was eaten, and what that comes to.
///
/// The food holds its numbers per serving; this scales them to the
/// portion actually eaten. Rounding happens once, on each total, to the
/// tenth a label prints, so the figures stay the arithmetic the user could
/// do themselves and a label's 2.1 g is not logged as 2 g.
class FoodPortion {
  const FoodPortion(this.food, this.servings);

  /// The portion as a raw amount — 150 g of a food whose serving is
  /// 100 g is 1.5 servings. An unmeasured serving has no amount to scale
  /// from, so it stays whole servings.
  ///
  /// [unit] may be any unit measuring the same kind of quantity as the
  /// food's own: 0.5 lb of something sold in grams is fine, 500 ml of
  /// something sold in grams is not, because that needs a density.
  factory FoodPortion.ofAmount(
    FoodItem food,
    double amount, {
    ServingUnit? unit,
  }) {
    final serving = food.servingUnit;
    if (!serving.isMeasured || food.servingAmount <= 0) {
      return FoodPortion(food, amount);
    }
    final inServingUnit = unit == null || unit == serving
        ? amount
        : unit.convert(amount, serving);
    return FoodPortion(food, inServingUnit / food.servingAmount);
  }

  final FoodItem food;
  final double servings;

  /// How much this portion is in the food's own unit.
  double get amount => food.servingAmount * servings;

  /// The volume drunk, for something the food says is a drink and
  /// measures by volume. It is the drink itself, not the water in it.
  ///
  /// Being poured is not enough: soup is measured in millilitres and no
  /// food authority calls it a drink, so the food has to say so.
  ///
  /// A cup's capacity is not what was drunk either — an iced 480 mL cup
  /// is partly ice — so a food whose volume is its cup gives none.
  int? get millilitres =>
      food.kind == ConsumptionKind.beverage &&
          !food.isCupCapacity &&
          food.servingUnit.dimension == ServingDimension.volume
      ? food.servingUnit.convert(amount, ServingUnit.millilitre).round()
      : null;

  /// Null stays null: scaling a figure nobody wrote down cannot produce
  /// one.
  double? get kcal => _scaled(food.kcal);
  double? get proteinGrams => _scaled(food.proteinGrams);
  double? get carbGrams => _scaled(food.carbGrams);
  double? get fatGrams => _scaled(food.fatGrams);
  double? get fibreGrams => _scaled(food.fibreGrams);

  /// The rest of what is known, scaled the same way. Nutrients the food
  /// does not hold stay absent — scaling cannot invent one.
  Nutrients get nutrients => {
    for (final MapEntry(key: nutrient, value: amount) in food.nutrients.entries)
      nutrient: amount * servings,
  };

  /// What the log calls this portion: `150 g`, or `1.5 份` when the
  /// serving is not a measurement.
  String labelIn(AppLocalizations l10n) => food.servingUnit.isMeasured
      ? '${formatAmount(amount)} ${food.servingUnit.labelIn(l10n)}'
      : '${formatAmount(servings)} ${ServingUnit.serving.labelIn(l10n)}';

  double? _scaled(double? perServing) =>
      perServing == null ? null : (perServing * servings * 10).round() / 10;
}

/// [meal] as if [factor] times as much had been eaten: every figure it
/// holds scaled the way a portion scales a food's, none it lacks made
/// up, and the quantities it names with them (`1 碗` at half is
/// `0.5 碗`). Logging a meal again at a different portion starts here.
MealEvent scaledMeal(MealEvent meal, double factor) {
  if (factor == 1) return meal;
  double? tenth(double? figure) =>
      figure == null ? null : (figure * factor * 10).round() / 10;
  return meal.copyWith(
    kcal: tenth(meal.kcal),
    proteinGrams: tenth(meal.proteinGrams),
    carbGrams: tenth(meal.carbGrams),
    fatGrams: tenth(meal.fatGrams),
    fibreGrams: tenth(meal.fibreGrams),
    nutrients: {
      for (final MapEntry(key: nutrient, value: amount)
          in meal.nutrients.entries)
        nutrient: amount * factor,
    },
    millilitres: meal.millilitres == null
        ? null
        : (meal.millilitres! * factor).round(),
    servings: meal.servings == null ? null : meal.servings! * factor,
    amount: meal.amount.isEmpty ? null : scaledQuantity(meal.amount, factor),
    dishes: [
      for (final dish in meal.dishes)
        DishEntry(
          name: dish.name,
          quantityLabel: scaledQuantity(dish.quantityLabel, factor),
          subtitle: dish.subtitle,
          components: [
            for (final component in dish.components)
              FoodComponent(
                name: component.name,
                amountLabel: scaledQuantity(component.amountLabel, factor),
                source: component.source,
              ),
          ],
        ),
    ],
  );
}

/// A quantity as written (`~85 – 110 g`, `1/2 碗`) for [factor] times as
/// much: each number in it scaled, a fraction as the number it is. A
/// quantity with no number to scale (`一碗`) says what it is multiplied
/// by instead, so it is never left reading as the original.
String scaledQuantity(String quantity, double factor) {
  if (factor == 1 || quantity.isEmpty) return quantity;
  var hasNumber = false;
  final scaled = quantity.replaceAllMapped(
    RegExp(r'(\d+(?:\.\d+)?)\s*/\s*(\d+(?:\.\d+)?)|(\d+(?:\.\d+)?)'),
    (match) {
      hasNumber = true;
      final value = match.group(3) != null
          ? double.parse(match.group(3)!)
          : double.parse(match.group(1)!) / double.parse(match.group(2)!);
      return formatQuantity(value * factor);
    },
  );
  return hasNumber ? scaled : '$quantity × ${formatQuantity(factor)}';
}

/// How much [meal] was as a weight or volume: the first one its amount
/// in words names, else its only dish's quantity (`150 g`), else the
/// volume of a drink logged with no dish, as water is. Null when it was
/// counted instead (`1 碗`) or is several dishes, since the app does not
/// know how many grams a bowl is.
(double, ServingUnit)? measuredMealAmount(MealEvent meal) {
  final quantity = meal.amount.isNotEmpty
      ? meal.amount
      : meal.dishes.length == 1
      ? meal.dishes.single.quantityLabel
      : '';
  if (measuredAmount(quantity) case (final amount, final unit)) {
    return amount > 0 ? (amount, unit) : null;
  }
  final volume = meal.millilitres;
  return meal.dishes.isEmpty && volume != null && volume > 0
      ? (volume.toDouble(), ServingUnit.millilitre)
      : null;
}

// l10n-ignore: units a model may write in, not words shown.
final _measuredAmountPattern = RegExp(r'(\d+(?:\.\d+)?)\s*(g|公克|克|ml|mL|毫升)');

/// The first weight or volume in a quantity written in words (「約 180 g
/// （150–220 g）」 is 180 g), or null when it names none.
(double, ServingUnit)? measuredAmount(String quantity) {
  final match = _measuredAmountPattern.firstMatch(quantity);
  if (match == null) return null;
  final value = double.parse(match.group(1)!);
  final unit = switch (match.group(2)) {
    // l10n-ignore: as above.
    'ml' || 'mL' || '毫升' => ServingUnit.millilitre,
    _ => ServingUnit.gram,
  };
  return (value, unit);
}

/// A number as [scaledQuantity] writes one: `1.5`, `0.25`, `75`, up to two
/// decimals and none when whole.
String formatQuantity(double value) => ((value * 100).round() / 100)
    .toStringAsFixed(2)
    .replaceFirst(RegExp(r'\.?0+$'), '');
