import '../../domain/domain.dart';
import '../engines/nutrition_summary.dart';
import '../storage/database.dart';
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

/// Logging food and changing how a meal is structured.
class NutritionService {
  NutritionService(this._db, this._meals);

  final AppDatabase _db;
  final MealRepository _meals;

  List<MealEvent> mealsOn(DateTime day) => _meals.onDay(day);

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

  List<(DateTime, MealEvent)> between(DateTime start, DateTime end) =>
      _meals.between(start, end);

  /// Logs [meal] again, as eaten now: a copy, not a link, so editing one
  /// never changes the other.
  MealEvent copy(MealEvent meal) =>
      logMeal(meal.copyWith(id: _db.newId()), eatenAt: _db.now());

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

  bool _isToday(DateTime day) {
    final now = _db.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }
}
