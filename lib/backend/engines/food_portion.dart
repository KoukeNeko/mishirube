import '../../domain/domain.dart';
import '../../shared/format.dart';

/// Bumped whenever the arithmetic below changes.
const foodPortionVersion = 2;

/// How much of a food was eaten, and what that comes to.
///
/// The food holds its numbers per serving; this scales them to the
/// portion actually eaten. Rounding happens once, on each total, so the
/// figures stay the arithmetic the user could do themselves.
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
  int? get kcal => _scaled(food.kcal);
  int? get proteinGrams => _scaled(food.proteinGrams);
  int? get carbGrams => _scaled(food.carbGrams);
  int? get fatGrams => _scaled(food.fatGrams);
  int? get fibreGrams => _scaled(food.fibreGrams);

  /// The rest of what is known, scaled the same way. Nutrients the food
  /// does not hold stay absent — scaling cannot invent one.
  Nutrients get nutrients => {
    for (final MapEntry(key: nutrient, value: amount) in food.nutrients.entries)
      nutrient: amount * servings,
  };

  /// What the log calls this portion: `150 g`, or `1.5 份` when the
  /// serving is not a measurement.
  String get label => food.servingUnit.isMeasured
      ? '${formatAmount(amount)} ${food.servingUnit.label}'
      : '${formatAmount(servings)} ${ServingUnit.serving.label}';

  int? _scaled(double? perServing) =>
      perServing == null ? null : (perServing * servings).round();
}
