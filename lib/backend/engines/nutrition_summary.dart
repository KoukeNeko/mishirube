import '../../domain/domain.dart';

/// Fewer records of something eaten than this on a finished day marks
/// its food log incomplete. Drinks do not count towards it.
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
    this.mealsWithoutProtein = 0,
    this.mealsWithoutCarb = 0,
    this.mealsWithoutFat = 0,
    this.mealsWithoutFibre = 0,
    this.recordCount = 0,
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

  /// Records with no figure for each macro. Counted separately from
  /// [mealsWithoutFigures] because a packet can print energy and leave
  /// out fibre: a gram total that quietly added nothing for those
  /// records would read as the day, when it is only a floor.
  final int mealsWithoutProtein;
  final int mealsWithoutCarb;
  final int mealsWithoutFat;
  final int mealsWithoutFibre;

  /// Records counted in the totals, drinks included — what the
  /// `mealsWithout…` counts are out of.
  final int recordCount;

  /// Enough meals for the day's totals to be worth comparing.
  final bool isComplete;

  bool get hasRecords => mealCount > 0;

  /// Every meal in the day carried its own figures, so the totals are
  /// the day rather than the part of it the app could see.
  bool get countsEveryMeal => mealsWithoutFigures == 0;
}

/// Adds up [meals]. A day is complete once it holds [mealsForCompleteDay]
/// records of something eaten; a day still running is never called
/// incomplete.
///
/// Drinks are added to the totals but not counted towards that: three
/// glasses of water is not three meals, and a day that called itself
/// complete on the strength of them would be lying.
DaySummary summariseDay(Iterable<MealEvent> meals, {bool isOver = true}) {
  final records = meals.toList();
  // A missing figure is counted, not skipped and not added as zero: the
  // day has to be able to say how much of itself it could not see.
  int sumOf(int? Function(MealEvent) figure) =>
      records.fold(0, (total, meal) => total + (figure(meal) ?? 0));
  int missing(int? Function(MealEvent) figure) =>
      records.where((meal) => figure(meal) == null).length;

  final mealCount = records
      .where((meal) => meal.kind != ConsumptionKind.beverage)
      .length;
  return DaySummary(
    kcal: sumOf((meal) => meal.kcal),
    proteinGrams: sumOf((meal) => meal.proteinGrams),
    carbGrams: sumOf((meal) => meal.carbGrams),
    fatGrams: sumOf((meal) => meal.fatGrams),
    fibreGrams: sumOf((meal) => meal.fibreGrams),
    mealsWithoutFigures: missing((meal) => meal.kcal),
    mealsWithoutProtein: missing((meal) => meal.proteinGrams),
    mealsWithoutCarb: missing((meal) => meal.carbGrams),
    mealsWithoutFat: missing((meal) => meal.fatGrams),
    mealsWithoutFibre: missing((meal) => meal.fibreGrams),
    recordCount: records.length,
    mealCount: mealCount,
    hasEstimates: records.any((meal) => meal.isEstimated),
    isComplete: !isOver || mealCount >= mealsForCompleteDay,
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

/// What was drunk on a day, as logged.
///
/// This is liquid recorded, not hydration. Nothing here applies a factor
/// to coffee, tea or alcohol: the research behind those percentages is
/// not something anyone publishes the working for, and the evidence that
/// does exist says caffeinated drinks still count as fluid.
class FluidLogged {
  const FluidLogged({required this.millilitres, required this.drinkCount});

  /// The sum of what was logged by volume.
  final int millilitres;

  /// How many meals contributed a volume. Food eaten, and drinks logged
  /// without a volume, are not counted — and are not counted as zero
  /// either, because this figure only ever claims what was recorded.
  final int drinkCount;

  bool get hasRecords => drinkCount > 0;
}

/// Adds up what [meals] recorded by volume.
FluidLogged summariseFluid(Iterable<MealEvent> meals) {
  var millilitres = 0;
  var drinks = 0;
  for (final meal in meals) {
    if (meal.millilitres case final volume?) {
      millilitres += volume;
      drinks++;
    }
  }
  return FluidLogged(millilitres: millilitres, drinkCount: drinks);
}

/// Plain water logged in a day: how much, how many times, and the last.
///
/// Water only. Other drinks count towards [FluidLogged], which says so;
/// folding coffee into a number labelled 「水」 would be the screen
/// claiming a hydration value nobody has measured.
class WaterLogged {
  const WaterLogged({
    required this.millilitres,
    required this.times,
    this.lastTimeLabel,
  });

  final int millilitres;
  final int times;

  /// When the last glass was logged, as the day shows it.
  final String? lastTimeLabel;
}

/// Adds up the plain water in [meals], which are in the order eaten.
WaterLogged summariseWater(Iterable<MealEvent> meals) {
  final water = [
    for (final meal in meals)
      if (meal.isWater && meal.millilitres != null) meal,
  ];
  return WaterLogged(
    millilitres: water.fold(0, (sum, meal) => sum + meal.millilitres!),
    times: water.length,
    lastTimeLabel: water.lastOrNull?.timeLabel,
  );
}
