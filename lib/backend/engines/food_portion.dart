import '../../domain/domain.dart';
import '../../shared/format.dart';

/// Bumped whenever the arithmetic below changes.
const foodPortionVersion = 1;

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
  factory FoodPortion.ofAmount(FoodItem food, double amount) {
    if (!food.servingUnit.isMeasured || food.servingAmount <= 0) {
      return FoodPortion(food, amount);
    }
    return FoodPortion(food, amount / food.servingAmount);
  }

  final FoodItem food;
  final double servings;

  /// How much this portion is in the food's own unit.
  double get amount => food.servingAmount * servings;

  int get kcal => _scaled(food.kcal);
  int get proteinGrams => _scaled(food.proteinGrams);
  int get carbGrams => _scaled(food.carbGrams);
  int get fatGrams => _scaled(food.fatGrams);
  int get fibreGrams => _scaled(food.fibreGrams);

  /// The rest of what is known, scaled the same way. Nutrients the food
  /// does not hold stay absent — scaling cannot invent one.
  Nutrients get nutrients => {
    for (final MapEntry(key: nutrient, value: amount)
        in food.nutrients.entries)
      nutrient: amount * servings,
  };

  /// What the log calls this portion: `150 g`, or `1.5 份` when the
  /// serving is not a measurement.
  String get label => food.servingUnit.isMeasured
      ? '${formatAmount(amount)} ${food.servingUnit.label}'
      : '${formatAmount(servings)} ${ServingUnit.serving.label}';

  int _scaled(int perServing) => (perServing * servings).round();
}
