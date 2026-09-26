import '../../app/view_model.dart';
import '../../backend/application/nutrition_service.dart';
import '../../backend/engines/caffeine.dart';
import '../../backend/engines/food_portion.dart';
import '../../backend/engines/nutrition_summary.dart';
import '../../domain/domain.dart';

/// Meals, the food library and water: logging, correcting and taking
/// back what was eaten and drunk, and the foods it was logged from.
class NutritionViewModel extends ViewModel {
  NutritionViewModel(super.backend);

  static const _glassKey = 'glass_millilitres';

  /// What one glass is, until the user says otherwise.
  static const defaultGlassMillilitres = 250;

  /// Meals eaten on [day].
  List<MealEvent> mealsOn(DateTime day) => backend.nutrition.mealsOn(day);

  /// The day's targets, from the body as it was then.
  NutritionTargets targetsOn(DateTime day) => backend.nutrition.targetsOn(day);

  NutritionTargetSettings get targetSettings =>
      backend.nutrition.targetSettings;

  void setTargetSettings(NutritionTargetSettings settings) =>
      backend.nutrition.setTargetSettings(settings);

  /// What the energy target is worked out from.
  Sex? get sex => backend.journal.sex;

  void setSex(Sex? sex) => backend.journal.setSex(sex);

  int? get birthYear => backend.journal.birthYear;

  void setBirthYear(int? year) => backend.journal.setBirthYear(year);

  double? get heightCm => backend.journal.heightCm;

  BodyWeight? weightOn(DateTime day) => backend.journal.weightOn(day);

  /// Which of [days] have anything eaten or drunk logged.
  Set<DateTime> daysWithMeals(Iterable<DateTime> days) => {
    for (final day in days)
      if (backend.nutrition.mealsOn(day).isNotEmpty) day,
  };

  /// Food totals for [day] and how complete its log is.
  DaySummary summaryOf(DateTime day) => backend.nutrition.summaryOf(day);

  /// Meals worth offering again, newest first.
  List<RecentMeal> get recentMeals => backend.nutrition.recent();

  /// Starred meals, for logging again without going looking.
  List<RecentMeal> get favoriteMeals => backend.nutrition.favorites();

  void setMealFavorite(MealEvent meal, {required bool isFavorite}) =>
      backend.nutrition.setFavorite(meal, isFavorite: isFavorite);

  /// What the user usually calls a meal eaten at [at]; null until their
  /// own labels show a habit. Offered, never applied on its own.
  MealType? suggestedMealType([DateTime? at]) =>
      backend.nutrition.suggestedMealType(at ?? now());

  /// Logs [meal] as eaten now.
  MealEvent logMeal(MealEvent meal) =>
      backend.nutrition.logMeal(meal, eatenAt: now());

  /// Logs a meal eaten before all over again.
  MealEvent copyMeal(MealEvent meal) => backend.nutrition.copy(meal);

  /// Saves a correction to a meal.
  void updateMeal(MealEvent previous, MealEvent corrected) =>
      backend.nutrition.edit(previous, corrected);

  /// Logs the draft items the user kept.
  List<MealEvent> logDraft(
    MealDraft draft,
    List<DraftItem> items, {
    MealType? mealType,
    bool asOneMeal = false,
  }) => backend.nutrition.logDraft(
    draft,
    items,
    mealType: mealType,
    asOneMeal: asOneMeal,
  );

  /// Logs a plate: every portion, as one action.
  List<MealEvent> logPortions(
    List<FoodPortion> portions, {
    MealType? mealType,
  }) => backend.nutrition.logPortions(portions, mealType: mealType);

  /// Logs one serving of [food] without keeping the food: 快速記錄.
  MealEvent logOnce(FoodItem food, {MealType? mealType}) =>
      backend.nutrition.logOnce(FoodPortion(food, 1), mealType: mealType);

  /// Takes logged meals back out; [restoreMeals] puts them back.
  void deleteMeals(List<MealEvent> meals) =>
      backend.nutrition.deleteMeals(meals.map((meal) => meal.id));

  void restoreMeals(List<MealEvent> meals) =>
      backend.nutrition.restoreMeals(meals.map((meal) => meal.id));

  DateTime? eatenAtOf(String id) => backend.nutrition.eatenAtOf(id);

  void retimeMeal(String id, DateTime eatenAt) =>
      backend.nutrition.retimeMeal(id, eatenAt);

  /// Puts separately logged [meals] back together as one.
  MealEvent mergeMeals(List<MealEvent> meals) =>
      backend.nutrition.mergeMeals(meals);

  void unmergeMeals(MealEvent merged, List<MealEvent> parts) =>
      backend.nutrition.unmergeMeals(merged, parts);

  /// Splits one dish of a meal on [day] into a record of its own.
  DishSplitSnapshot? splitDish({
    required String mealId,
    required int dishIndex,
    required DateTime day,
  }) => backend.nutrition
      .explodeDish(mealsOn(day), mealId: mealId, dishIndex: dishIndex, day: day)
      ?.$2;

  void undoSplit(DishSplitSnapshot snapshot) => backend.nutrition.undoExplode(
    snapshot,
    current: mealsOn(snapshot.day)[snapshot.mealIndex],
  );

  /// How much caffeine is likely still in the body right now, in
  /// milligrams, from what was logged over the last day.
  ///
  /// An estimate from a population half-life, not a reading. The screen
  /// showing it has to say so.
  double get estimatedCaffeineMg {
    final at = now();
    return estimatedCaffeineRemaining(
      caffeineIntakes(
        backend.nutrition.between(at.subtract(const Duration(days: 1)), at),
      ),
      now: at,
    );
  }

  /// Saved foods matching [query]; an empty query is all of them.
  List<FoodItem> searchFoods(String query) =>
      backend.nutrition.searchFoods(query);

  /// Brands whose menu [query] names on its own.
  List<String> brandsNamedBy(String query) =>
      backend.nutrition.brandsNamedBy(query);

  List<FoodItem> menuOf(String brand) => backend.nutrition.menuOf(brand);

  /// Saved foods eaten recently, each once, with its last portion.
  List<RecentFood> get recentFoods => backend.nutrition.recentFoods();

  List<FoodItem> get favoriteFoods => backend.nutrition.favoriteFoods();

  bool isFavoriteFood(String foodId) =>
      favoriteFoods.any((food) => food.id == foodId);

  void setFoodFavorite(String foodId, {required bool isFavorite}) =>
      backend.nutrition.setFoodFavorite(foodId, isFavorite: isFavorite);

  /// The sizes of a food, smallest first. A food with none is logged as
  /// itself.
  List<FoodItem> sizesOf(String foodId) => backend.nutrition.sizesOf(foodId);

  /// The size names this brand already uses, so a second drink from the
  /// same shop offers the same cups.
  List<String> sizeNamesFor(String brand) =>
      backend.nutrition.sizeNamesFor(brand);

  /// A fresh id for a food about to be saved.
  String newFoodId() => backend.nutrition.newFoodId();

  /// Stores a food, new or edited.
  void saveFood(FoodItem food) => backend.nutrition.saveFood(food);

  /// Removes a saved food. The meals already logged from it keep their
  /// numbers, so this is not a change to any record.
  void deleteFood(String id) => backend.nutrition.deleteFood(id);

  void undeleteFood(String id) => backend.nutrition.undeleteFood(id);

  /// How much one tap of the water shortcut logs. The user's own glass
  /// or bottle, because nobody drinks in units the app picked.
  int get glassMillilitres =>
      int.tryParse(backend.db.setting(_glassKey) ?? '') ??
      defaultGlassMillilitres;

  void setGlassMillilitres(int millilitres) =>
      backend.db.setSetting(_glassKey, '$millilitres');

  /// What today's drinks came to, counting only those logged by volume.
  FluidLogged get todayFluid => summariseFluid(mealsOn(now()));

  /// Today's plain water, apart from every other drink.
  WaterLogged get todayWater => summariseWater(mealsOn(now()));

  /// Logs a glass of water. It writes the same record every drink
  /// writes, so the day's fluid stays one total.
  MealEvent logWater([int? millilitres]) =>
      backend.nutrition.logWater(millilitres ?? glassMillilitres);
}
