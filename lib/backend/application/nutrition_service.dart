import '../../domain/domain.dart';
// The one place that decides how a typed search term is normalised; a
// food is searched the same way an exercise is.
import '../engines/exercise_search.dart' show normalizeTerm;
import '../engines/food_portion.dart';
import '../../shared/format.dart';
import '../engines/meal_type_suggestion.dart';
import '../engines/nutrition_summary.dart';
import '../storage/database.dart';
import '../storage/food_repository.dart';
import '../storage/meal_repository.dart';

/// An exploded dish, kept so the change can be undone.
class DishSplitSnapshot {
  const DishSplitSnapshot({
    required this.mealIndex,
    required this.meal,
    required this.day,
  });

  final int mealIndex;

  /// The meal as it was before the dish was exploded.
  final MealEvent meal;

  /// The day it was eaten, so the undo finds it again.
  final DateTime day;
}

/// A meal eaten before, offered for logging again.
class RecentMeal {
  const RecentMeal({required this.meal, required this.eatenAt});

  final MealEvent meal;
  final DateTime eatenAt;

  /// What the row calls it: the first dish, or the meal's own name when
  /// it has no dishes.
  String get label => meal.dishes.isEmpty ? meal.name : meal.dishes.first.name;
}

/// A saved food as it was last eaten: one row per food, however many
/// times and at however many portions it was logged.
class RecentFood {
  const RecentFood({
    required this.food,
    required this.servings,
    required this.eatenAt,
    this.mealType,
  });

  final FoodItem food;

  /// The servings logged the last time, which is where the next one
  /// starts.
  final double servings;
  final DateTime eatenAt;
  final MealType? mealType;

  FoodPortion get portion => FoodPortion(food, servings);
}

/// Logging food and changing how a meal is structured.
class NutritionService {
  NutritionService(this._db, this._meals, this._foods);

  final AppDatabase _db;
  final MealRepository _meals;
  final FoodRepository _foods;

  List<MealEvent> mealsOn(DateTime day) => _meals.onDay(day);

  /// What the user usually calls a meal eaten at [at], learned from the
  /// last eight weeks of their own labels; null until there is a habit.
  MealType? suggestedMealType(DateTime at) => suggestMealType(
    _meals.labelledSince(_db.now().subtract(const Duration(days: 56))),
    at,
  );

  DaySummary summaryOf(DateTime day) =>
      summariseDay(_meals.onDay(day), isOver: !_isToday(day));

  /// Meals eaten recently, newest first and one per dish, so the same
  /// lunch three days running is offered once.
  List<RecentMeal> recent({
    int limit = 3,
    Duration window = const Duration(days: 30),
  }) {
    final now = _db.now();
    final seen = <String>{};
    final recent = <RecentMeal>[];
    for (final (eatenAt, meal) in between(now.subtract(window), now).reversed) {
      final label = RecentMeal(meal: meal, eatenAt: eatenAt).label;
      if (!seen.add(label)) continue;
      recent.add(RecentMeal(meal: meal, eatenAt: eatenAt));
      if (recent.length == limit) break;
    }
    return recent;
  }

  /// Saved foods eaten recently, newest first, each once with the portion
  /// it was last logged at. A food since deleted is left out; one whose
  /// numbers have changed is offered with its current numbers, since
  /// logging it again is a new meal.
  List<RecentFood> recentFoods({int limit = 12}) {
    final recent = <String, RecentFood>{};
    for (final (foodId, servings, mealType, eatenAt)
        in _meals.portionsLogged()) {
      if (recent.containsKey(foodId)) continue;
      final food = _foods.byId(foodId);
      if (food == null) continue;
      recent[foodId] = RecentFood(
        food: food,
        servings: servings,
        eatenAt: eatenAt,
        mealType: mealType,
      );
      if (recent.length == limit) break;
    }
    return recent.values.toList();
  }

  /// Logs several portions as eaten now, all or none: a plate is one
  /// action, so it is written in one transaction and undone as one.
  List<MealEvent> logPortions(
    List<FoodPortion> portions, {
    MealType? mealType,
  }) => _db.transaction(
    () => [
      for (final portion in portions) logPortion(portion, mealType: mealType),
    ],
  );

  /// Removes logged meals; [restoreMeals] takes them back.
  void deleteMeals(Iterable<String> ids) =>
      _db.transaction(() => ids.forEach(_meals.delete));

  void restoreMeals(Iterable<String> ids) =>
      _db.transaction(() => ids.forEach(_meals.restore));

  /// Saves a correction to a meal's name and totals. Confirming the
  /// numbers is what takes the estimate mark off them.
  MealEvent edit(MealEvent previous, MealEvent corrected) {
    _meals.updateTotals(corrected, previous: previous);
    return corrected;
  }

  /// Starred meals, newest first and one per dish, the way [recent]
  /// works: the same starred lunch is offered once.
  List<RecentMeal> favorites({int limit = 5}) {
    final seen = <String>{};
    final favorites = <RecentMeal>[];
    for (final (eatenAt, meal) in _meals.favorites()) {
      final entry = RecentMeal(meal: meal, eatenAt: eatenAt);
      if (!seen.add(entry.label)) continue;
      favorites.add(entry);
      if (favorites.length == limit) break;
    }
    return favorites;
  }

  /// Stars or unstars a meal.
  void setFavorite(MealEvent meal, {required bool isFavorite}) =>
      _meals.setFavorite(meal.id, isFavorite: isFavorite);

  List<(DateTime, MealEvent)> between(DateTime start, DateTime end) =>
      _meals.between(start, end);

  /// Logs [meal] again, as eaten now: a copy, not a link, so editing one
  /// never changes the other.
  /// The star stays on the meal that was starred, so logging a
  /// favourite again does not quietly star the copy too.
  MealEvent copy(MealEvent meal) => logMeal(
    meal.copyWith(id: _db.newId(), isFavorite: false),
    eatenAt: _db.now(),
  );

  /// Stores [meal] eaten at [eatenAt], keeping its id free of collisions
  /// with a meal logged on another day.
  MealEvent logMeal(MealEvent meal, {required DateTime eatenAt}) {
    final stored = _meals.exists(meal.id)
        ? meal.copyWith(id: _db.newId())
        : meal;
    _meals.insert(stored, eatenAt: eatenAt);
    return stored;
  }

  /// Turns a dish's components into standalone entries. Unlike expanding a
  /// dish on screen this changes the record, so it is audited and can be
  /// undone.
  (MealEvent, DishSplitSnapshot)? explodeDish(
    List<MealEvent> meals, {
    required String mealId,
    required int dishIndex,
    DateTime? day,
  }) {
    final mealIndex = meals.indexWhere((meal) => meal.id == mealId);
    if (mealIndex < 0) return null;
    final meal = meals[mealIndex];
    final dish = meal.dishes[dishIndex];
    if (!dish.isComposite) return null;

    final dishes = [...meal.dishes]
      ..removeAt(dishIndex)
      ..insertAll(dishIndex, [
        for (final component in dish.components)
          DishEntry(
            name: component.name,
            quantityLabel: component.amountLabel,
            subtitle: component.source,
          ),
      ]);
    final exploded = meal.copyWith(dishes: dishes);
    _meals.replaceDishes(exploded, action: 'explode_dish', previous: meal);
    return (
      exploded,
      DishSplitSnapshot(
        mealIndex: mealIndex,
        meal: meal,
        day: day ?? _db.now(),
      ),
    );
  }

  void undoExplode(DishSplitSnapshot snapshot, {required MealEvent current}) {
    _meals.replaceDishes(
      snapshot.meal,
      action: 'undo_explode_dish',
      previous: current,
    );
  }

  /// Every food the user saved, by name.
  List<FoodItem> foods() => _foods.all();

  /// Saved foods whose name or maker contains [query]. An empty query is
  /// the whole list: there is nothing clever to rank by here, because
  /// every one of these was typed in by the person searching.
  List<FoodItem> searchFoods(String query) {
    final wanted = normalizeTerm(query);
    if (wanted.isEmpty) return foods();
    return [
      for (final food in foods())
        if (normalizeTerm(food.name).contains(wanted) ||
            normalizeTerm(food.brand).contains(wanted))
          food,
    ];
  }

  /// Logs a glass of water of [millilitres].
  ///
  /// A shortcut, not a second kind of record: it writes the same meal
  /// every drink writes, so the day's fluid is one total rather than two
  /// that disagree.
  MealEvent logWater(int millilitres) {
    final eatenAt = _db.now();
    return logMeal(
      MealEvent(
        id: _db.newId(),
        name: '水',
        timeLabel: formatTimeOfDay(eatenAt),
        qualityTag: '水',
        dishes: const [],
        kind: ConsumptionKind.beverage,
        millilitres: millilitres,
        kcal: 0,
        proteinGrams: 0,
        carbGrams: 0,
        fatGrams: 0,
      ),
      eatenAt: eatenAt,
    );
  }

  /// The sizes of a food, smallest first.
  List<FoodItem> sizesOf(String foodId) => _foods.sizesOf(foodId);

  /// The size names this brand already uses.
  List<String> sizeNamesFor(String brand) => _foods.sizeNamesFor(brand);

  /// Stores a food, new or edited. Editing one never touches the meals
  /// already logged from it: those copied the numbers when they were
  /// logged.
  FoodItem saveFood(FoodItem food) {
    _foods.save(food);
    return food;
  }

  /// Removes a saved food from the list. It is a tombstone, so
  /// [undeleteFood] can put it back.
  void deleteFood(String id) => _foods.delete(id);

  void undeleteFood(String id) => _foods.undelete(id);

  /// A fresh id for a food the user is about to save.
  String newFoodId() => _db.newId();

  /// Logs [portion] of a saved food as a meal eaten now.
  ///
  /// The numbers are copied, not linked: correcting the food later is not
  /// a claim about what was eaten last Tuesday. They are also not marked
  /// as estimated — the user typed them and chose the portion.
  MealEvent logPortion(FoodPortion portion, {MealType? mealType}) {
    final eatenAt = _db.now();
    final food = portion.food;
    return logMeal(
      MealEvent(
        id: _db.newId(),
        name: food.displayName,
        timeLabel: formatTimeOfDay(eatenAt),
        kcal: portion.kcal,
        proteinGrams: portion.proteinGrams,
        carbGrams: portion.carbGrams,
        fatGrams: portion.fatGrams,
        fibreGrams: portion.fibreGrams,
        nutrients: portion.nutrients,
        millilitres: portion.millilitres,
        kind: food.kind,
        mealType: mealType,
        valueType: food.valueType,
        foodId: food.id,
        servings: portion.servings,
        qualityTag: '自訂食物',
        dishes: [
          DishEntry(
            name: food.displayName,
            quantityLabel: portion.label,
            subtitle: '自訂食物',
          ),
        ],
      ),
      eatenAt: eatenAt,
    );
  }

  bool _isToday(DateTime day) {
    final now = _db.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }
}
