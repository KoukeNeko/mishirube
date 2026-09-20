import '../../domain/domain.dart';

/// Fewer meals than this on a finished day marks its food log incomplete.
const mealsForCompleteDay = 3;

/// A day's food totals with how complete and how exact the record is.
///
/// Totals come from what the user logged; nothing is invented for missing
/// meals, so an incomplete day says so instead of reading as a low intake.
class DaySummary {
  const DaySummary({
    required this.kcal,
    required this.proteinGrams,
    required this.carbGrams,
    required this.fatGrams,
    required this.fibreGrams,
    required this.mealCount,
    required this.hasEstimates,
    required this.isComplete,
    this.mealsWithoutFigures = 0,
  });

  static const empty = DaySummary(
    kcal: 0,
    proteinGrams: 0,
    carbGrams: 0,
    fatGrams: 0,
    fibreGrams: 0,
    mealCount: 0,
    hasEstimates: false,
    isComplete: false,
  );

  final int kcal;
  final int proteinGrams;
  final int carbGrams;
  final int fatGrams;
  final int fibreGrams;
  final int mealCount;

  /// Some portion in the day was estimated, so totals read as `~`.
  final bool hasEstimates;

  /// Meals with no calorie figure at all. Their food was logged without
  /// one, so the totals above are a floor, not the day.
  final int mealsWithoutFigures;

  /// Enough meals for the day's totals to be worth comparing.
  final bool isComplete;

  bool get hasRecords => mealCount > 0;

  /// Every meal in the day carried its own figures, so the totals are
  /// the day rather than the part of it the app could see.
  bool get countsEveryMeal => mealsWithoutFigures == 0;
}

/// Adds up [meals]. A day is complete once it holds [mealsForCompleteDay]
/// meals; a day still running is never called incomplete.
DaySummary summariseDay(Iterable<MealEvent> meals, {bool isOver = true}) {
  var summary = DaySummary.empty;
  for (final meal in meals) {
    summary = DaySummary(
      kcal: summary.kcal + (meal.kcal ?? 0),
      proteinGrams: summary.proteinGrams + (meal.proteinGrams ?? 0),
      carbGrams: summary.carbGrams + (meal.carbGrams ?? 0),
      fatGrams: summary.fatGrams + (meal.fatGrams ?? 0),
      fibreGrams: summary.fibreGrams + (meal.fibreGrams ?? 0),
      mealCount: summary.mealCount + 1,
      hasEstimates: summary.hasEstimates || meal.isEstimated,
      isComplete: false,
      // A meal with no figures is counted, not skipped: the day has to
      // be able to say how much of itself it could not see.
      mealsWithoutFigures:
          summary.mealsWithoutFigures + (meal.kcal == null ? 1 : 0),
    );
  }
  return DaySummary(
    kcal: summary.kcal,
    proteinGrams: summary.proteinGrams,
    carbGrams: summary.carbGrams,
    fatGrams: summary.fatGrams,
    fibreGrams: summary.fibreGrams,
    mealsWithoutFigures: summary.mealsWithoutFigures,
    mealCount: summary.mealCount,
    hasEstimates: summary.hasEstimates,
    isComplete: !isOver || summary.mealCount >= mealsForCompleteDay,
  );
}

/// A finished day with some, but too few, meals. Days without any meal are
/// not flagged: the user may simply not track food.
bool isFoodLogIncomplete(DaySummary summary) =>
    summary.hasRecords && !summary.isComplete;

/// A day's total for one nutrient, and how much of the day it could not
/// see.
///
/// Meals that hold no figure for the nutrient are counted, not ignored
/// and not treated as zero: "at least 3.4 µg, from 2 of 4 meals" is the
/// truth, and "3.4 µg" alone is not.
class NutrientTotal {
  const NutrientTotal({
    required this.nutrient,
    required this.amount,
    required this.knownMeals,
    required this.unknownMeals,
  });

  final Nutrient nutrient;

  /// The sum of what is known. Never the sum of what is assumed.
  final double amount;

  final int knownMeals;
  final int unknownMeals;

  /// Every meal in the day held a figure, so the total is the total.
  bool get isComplete => unknownMeals == 0;

  /// `3.4 µg`, marked as a floor while any meal is unaccounted for.
  String get label =>
      isComplete ? nutrient.format(amount) : '至少 ${nutrient.format(amount)}';
}

/// Totals [meals] for every nutrient any of them knows about, in the
/// order [Nutrient] declares. Nutrients nobody recorded are left out
/// rather than listed as zero.
List<NutrientTotal> summariseNutrients(Iterable<MealEvent> meals) {
  final all = meals.toList();
  return [
    for (final nutrient in Nutrient.values)
      if (all.any((meal) => meal.nutrients.containsKey(nutrient)))
        NutrientTotal(
          nutrient: nutrient,
          amount: all.fold(
            0,
            (sum, meal) => sum + (meal.nutrients[nutrient] ?? 0),
          ),
          knownMeals: all
              .where((meal) => meal.nutrients.containsKey(nutrient))
              .length,
          unknownMeals: all
              .where((meal) => !meal.nutrients.containsKey(nutrient))
              .length,
        ),
  ];
}
