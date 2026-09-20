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
    required this.mealCount,
    required this.hasEstimates,
    required this.isComplete,
  });

  static const empty = DaySummary(
    kcal: 0,
    proteinGrams: 0,
    carbGrams: 0,
    fatGrams: 0,
    mealCount: 0,
    hasEstimates: false,
    isComplete: false,
  );

  final int kcal;
  final int proteinGrams;
  final int carbGrams;
  final int fatGrams;
  final int mealCount;

  /// Some portion in the day was estimated, so totals read as `~`.
  final bool hasEstimates;

  /// Enough meals for the day's totals to be worth comparing.
  final bool isComplete;

  bool get hasRecords => mealCount > 0;
}

/// Adds up [meals]. A day is complete once it holds [mealsForCompleteDay]
/// meals; a day still running is never called incomplete.
DaySummary summariseDay(Iterable<MealEvent> meals, {bool isOver = true}) {
  var summary = DaySummary.empty;
  for (final meal in meals) {
    summary = DaySummary(
      kcal: summary.kcal + meal.kcal,
      proteinGrams: summary.proteinGrams + meal.proteinGrams,
      carbGrams: summary.carbGrams + meal.carbGrams,
      fatGrams: summary.fatGrams + meal.fatGrams,
      mealCount: summary.mealCount + 1,
      hasEstimates: summary.hasEstimates || meal.isEstimated,
      isComplete: false,
    );
  }
  return DaySummary(
    kcal: summary.kcal,
    proteinGrams: summary.proteinGrams,
    carbGrams: summary.carbGrams,
    fatGrams: summary.fatGrams,
    mealCount: summary.mealCount,
    hasEstimates: summary.hasEstimates,
    isComplete: !isOver || summary.mealCount >= mealsForCompleteDay,
  );
}

/// A finished day with some, but too few, meals. Days without any meal are
/// not flagged: the user may simply not track food.
bool isFoodLogIncomplete(DaySummary summary) =>
    summary.hasRecords && !summary.isComplete;
