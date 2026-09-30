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

  NutritionConvention get convention => backend.nutrition.convention;

  void setConvention(NutritionConvention convention) =>
      backend.nutrition.setConvention(convention);

  /// The day's salt limit in [convention]'s measure.
  double get saltLimit => backend.nutrition.saltLimit;

  /// What the energy target is worked out from.
  Sex? get sex => backend.journal.sex;

  void setSex(Sex? sex) => backend.journal.setSex(sex);

  int? get birthYear => backend.journal.birthYear;

  void setBirthYear(int? year) => backend.journal.setBirthYear(year);

  double? get heightCm => backend.journal.heightCm;

  BodyWeight? weightOn(DateTime day) => backend.journal.weightOn(day);

  /// Which of [days] have anything eaten or drunk logged, water aside.
  Set<DateTime> daysWithMeals(Iterable<DateTime> days) => {
    for (final day in days)
      if (backend.nutrition.mealsOn(day).any((meal) => !meal.isWater)) day,
  };

  /// Food totals for [day] and how complete its log is.
  DaySummary summaryOf(DateTime day) => backend.nutrition.summaryOf(day);

  /// Meals worth offering again, newest first.
  List<RecentMeal> get recentMeals => backend.nutrition.recent();

  /// Up to [limit] foods eaten, newest first, from any time.
  List<RecentFood> recentFoodsUpTo(int limit) =>
      backend.nutrition.recentFoods(limit: limit);

  /// Up to [limit] meals eaten, newest first, from any time.
  List<RecentMeal> recentMealsUpTo(int limit) =>
      backend.nutrition.recent(limit: limit, window: null);

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
  MealEvent copyMeal(MealEvent meal, {DateTime? at}) =>
      backend.nutrition.copy(meal, at: at);

  /// Saves a correction to a meal.
  void updateMeal(MealEvent previous, MealEvent corrected) =>
      backend.nutrition.edit(previous, corrected);

  /// Logs the draft items the user kept.
  List<MealEvent> logDraft(
    MealDraft draft,
    List<DraftItem> items, {
    MealType? mealType,
    bool asOneMeal = false,
    String? name,
    DateTime? at,
  }) => backend.nutrition.logDraft(
    draft,
    items,
    mealType: mealType,
    asOneMeal: asOneMeal,
    name: name,
    at: at,
  );

  /// Logs a plate: every portion, as one action.
  List<MealEvent> logPortions(
    List<FoodPortion> portions, {
    MealType? mealType,
    DateTime? at,
    (AiProviderKind, String)? Function(FoodPortion portion)? draftedByOf,
  }) => backend.nutrition.logPortions(
    portions,
    mealType: mealType,
    at: at,
    draftedByOf: draftedByOf,
  );

  /// Logs one serving of [food] without keeping the food: 快速記錄.
  MealEvent logOnce(
    FoodItem food, {
    MealType? mealType,
    DateTime? at,
    (AiProviderKind, String)? draftedBy,
  }) => backend.nutrition.logOnce(
    FoodPortion(food, 1),
    mealType: mealType,
    at: at,
    draftedBy: draftedBy,
  );

  /// Takes logged meals back out; [restoreMeals] puts them back.
  void deleteMeals(List<MealEvent> meals) =>
      backend.nutrition.deleteMeals(meals.map((meal) => meal.id));

  void restoreMeals(List<MealEvent> meals) =>
      backend.nutrition.restoreMeals(meals.map((meal) => meal.id));

  /// The items of the meal [groupId] groups, in the order eaten.
  List<MealEvent> mealGroup(String groupId) =>
      backend.nutrition.mealGroup(groupId);

  /// What the meal of [items] is called: its given name, or its items.
  String nameOfMeal(List<MealEvent> items) =>
      backend.nutrition.nameOfMeal(items);

  /// The name the meal [groupId] groups was given, if any.
  String? mealGroupName(String groupId) =>
      backend.nutrition.mealGroupName(groupId);

  /// Calls the meal [groupId] groups [name]; blank goes back to its items.
  void nameMealGroup(String groupId, String name) =>
      backend.nutrition.nameMealGroup(groupId, name);

  /// Meal [id] as it is now; null once it is deleted.
  MealEvent? mealById(String id) => backend.nutrition.mealById(id);

  DateTime? eatenAtOf(String id) => backend.nutrition.eatenAtOf(id);

  (AiProviderKind, String)? draftedBy(String id) =>
      backend.nutrition.draftedBy(id);

  /// Moves [meal] to [eatenAt]; an item of a group moves its whole meal.
  void retimeMeal(MealEvent meal, DateTime eatenAt) =>
      backend.nutrition.retimeMeal(meal, eatenAt);

  /// Puts separately logged [meals] together as one meal called [name];
  /// returns what [regroupMeals] needs to take it back.
  Map<String, String?> groupMeals(List<MealEvent> meals, {String name = ''}) =>
      backend.nutrition.groupMeals(meals, name: name);

  /// Puts [meals] together as one meal called [name], at [mealType] and,
  /// when given, [eatenAt]; returns what [unmergeMeals] puts back.
  MealsBefore mergeMeals(
    List<MealEvent> meals, {
    String name = '',
    required MealType? mealType,
    DateTime? eatenAt,
  }) => backend.nutrition.mergeMeals(
    meals,
    name: name,
    mealType: mealType,
    eatenAt: eatenAt,
  );

  void unmergeMeals(MealsBefore before) =>
      backend.nutrition.unmergeMeals(before);

  /// Takes a meal apart into its [items]; returns what [regroupMeals]
  /// needs to put it back.
  Map<String, String?> ungroupMeals(List<MealEvent> items) =>
      backend.nutrition.ungroupMeals(items);

  void regroupMeals(Map<String, String?> groups) =>
      backend.nutrition.regroupMeals(groups);

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

  /// Saved foods matching [query]; an empty query is all of them. With
  /// [includePackaged], the shipped packaged foods follow.
  List<FoodItem> searchFoods(String query, {bool includePackaged = false}) =>
      backend.nutrition.searchFoods(query, includePackaged: includePackaged);

  /// Brands whose menu [query] names on its own.
  List<String> brandsNamedBy(String query) =>
      backend.nutrition.brandsNamedBy(query);

  List<FoodItem> menuOf(String brand) => backend.nutrition.menuOf(brand);

  /// Saved foods eaten recently, each once, with its last portion.
  List<RecentFood> get recentFoods => backend.nutrition.recentFoods();

  List<FoodItem> get favoriteFoods => backend.nutrition.favoriteFoods();

  bool isFavoriteFood(String foodId) =>
      favoriteFoods.any((food) => food.id == foodId);

  bool isUnsavedPackagedFood(String foodId) =>
      backend.nutrition.isUnsavedPackagedFood(foodId);

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

  /// What [day]'s drinks came to, counting only those logged by volume.
  FluidLogged fluidOn(DateTime day) => summariseFluid(mealsOn(day));

  FluidLogged get todayFluid => fluidOn(now());

  /// [day]'s plain water, apart from every other drink.
  WaterLogged waterOn(DateTime day) => summariseWater(mealsOn(day));

  WaterLogged get todayWater => waterOn(now());

  /// The glasses of plain water drunk on [day], in the order drunk.
  List<MealEvent> glassesOn(DateTime day) => [
    for (final meal in mealsOn(day))
      if (meal.isWater) meal,
  ];

  /// Which of [days] had water logged, for the week strip.
  Set<DateTime> daysWithWater(Iterable<DateTime> days) => {
    for (final day in days)
      if (glassesOn(day).isNotEmpty) day,
  };

  /// 國健署's plain-water reference, offered while the day follows
  /// Taiwan's rules.
  static const taiwanWaterReferenceMl = NutritionService.taiwanWaterReferenceMl;

  /// The plain water a day's level fills towards; null draws none.
  int? get waterReferenceMl => backend.nutrition.waterReferenceMl;

  void setWaterReferenceMl(int? millilitres) =>
      backend.nutrition.setWaterReferenceMl(millilitres);

  /// Plain water logged in the hour up to now, for the warning about
  /// drinking a lot quickly.
  int get waterInLastHour {
    final at = now();
    return [
      for (final (_, meal) in backend.nutrition.between(
        at.subtract(const Duration(hours: 1)),
        // A glass logged this very moment is in the hour too.
        at.add(const Duration(milliseconds: 1)),
      ))
        if (meal.isWater) meal.millilitres ?? 0,
    ].fold(0, (sum, ml) => sum + ml);
  }

  /// Logs a glass of water. It writes the same record every drink
  /// writes, so the day's fluid stays one total.
  MealEvent logWater([int? millilitres]) =>
      backend.nutrition.logWater(millilitres ?? glassMillilitres);
}
