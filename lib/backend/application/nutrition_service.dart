import 'dart:convert';

import '../../domain/domain.dart';
// The one place that decides how a typed search term is normalised; a
// food is searched the same way an exercise is.
import '../engines/exercise_search.dart' show normalizeTerm;
import '../engines/food_portion.dart';
import '../../shared/format.dart';
import '../engines/meal_type_suggestion.dart';
import '../engines/nutrition_summary.dart';
import '../engines/nutrition_targets.dart';
import '../storage/database.dart';
import '../storage/food_repository.dart';
import '../storage/meal_repository.dart';
import 'journal_service.dart';

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
  NutritionService(this._db, this._meals, this._foods, this._journal);

  final AppDatabase _db;
  final MealRepository _meals;
  final FoodRepository _foods;

  /// Where the body the targets are worked out from is kept.
  final JournalService _journal;

  static const _targetsKey = 'nutrition.targets';

  /// What the user chose for their daily targets.
  NutritionTargetSettings get targetSettings {
    final raw = _db.setting(_targetsKey);
    if (raw == null || raw.isEmpty) return const NutritionTargetSettings();
    final fields = jsonDecode(raw) as Map<String, dynamic>;
    return NutritionTargetSettings(
      customKcal: fields['customKcal'] as int?,
      activity:
          ActivityLevel.values.asNameMap()[fields['activity']] ??
          ActivityLevel.moderate,
      goal:
          WeightGoal.values.asNameMap()[fields['goal']] ?? WeightGoal.maintain,
      proteinPerKg:
          (fields['proteinPerKg'] as num?)?.toDouble() ??
          NutritionTargetSettings.defaultProteinPerKg,
      fatPercent:
          fields['fatPercent'] as int? ??
          NutritionTargetSettings.defaultFatPercent,
    );
  }

  void setTargetSettings(NutritionTargetSettings settings) => _db.setSetting(
    _targetsKey,
    jsonEncode({
      'customKcal': settings.customKcal,
      'activity': settings.activity.name,
      'goal': settings.goal.name,
      'proteinPerKg': settings.proteinPerKg,
      'fatPercent': settings.fatPercent,
    }),
  );

  /// The targets for [day], from the body as it was then.
  NutritionTargets targetsOn(DateTime day) => nutritionTargets(
    targetSettings,
    weightKg: _journal.weightOn(day)?.weightKg,
    heightCm: _journal.heightCm,
    age: _journal.ageOn(day),
    sex: _journal.sex,
  );

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

  /// Puts separately logged [meals] back together as one, eaten when the
  /// first of them was: each becomes a dish of it, and its figures are
  /// their sum — a figure any of them lacks is left empty rather than
  /// undercounted. The parts are tombstoned, not rewritten, so
  /// [unmergeMeals] brings them back as they were.
  MealEvent mergeMeals(List<MealEvent> meals) {
    assert(meals.length > 1, 'merging needs two meals or more');
    return _db.transaction(() {
      final timed = [
        for (final meal in meals) (_meals.eatenAtOf(meal.id)!, meal),
      ]..sort((a, b) => a.$1.compareTo(b.$1));
      final (eatenAt, first) = timed.first;
      int? total(int? Function(MealEvent) figure) {
        final figures = meals.map(figure);
        if (figures.any((value) => value == null)) return null;
        return figures.fold<int>(0, (sum, value) => sum + value!);
      }

      final volumes = [for (final meal in meals) ?meal.millilitres];
      final tags = {for (final meal in meals) meal.qualityTag};
      final merged = MealEvent(
        id: _db.newId(),
        name: meals.map((meal) => meal.name).join('、'),
        timeLabel: first.timeLabel,
        qualityTag: tags.length == 1 ? tags.single : mergedQualityTag,
        dishes: [
          for (final meal in meals)
            ...meal.dishes.isEmpty
                ? [
                    DishEntry(
                      name: meal.name,
                      quantityLabel: '',
                      subtitle: meal.qualityTag,
                    ),
                  ]
                : meal.dishes,
        ],
        kcal: total((meal) => meal.kcal),
        proteinGrams: total((meal) => meal.proteinGrams),
        carbGrams: total((meal) => meal.carbGrams),
        fatGrams: total((meal) => meal.fatGrams),
        fibreGrams: total((meal) => meal.fibreGrams),
        nutrients: {
          for (final nutrient in Nutrient.values)
            if (meals.every((meal) => meal.nutrients.containsKey(nutrient)))
              nutrient: meals.fold(
                0.0,
                (sum, meal) => sum + meal.nutrients[nutrient]!,
              ),
        },
        // Volume is what was drunk: a sandwich adds none to a coffee.
        millilitres: volumes.isEmpty
            ? null
            : volumes.fold<int>(0, (sum, volume) => sum + volume),
        kind: meals.every((meal) => meal.kind == ConsumptionKind.beverage)
            ? ConsumptionKind.beverage
            : ConsumptionKind.food,
        mealType: first.mealType,
        isEstimated: meals.any((meal) => meal.isEstimated),
        valueType:
            meals.any((meal) => meal.valueType == NutrientValueType.estimate)
            ? NutrientValueType.estimate
            : first.valueType,
      );
      for (final meal in meals) {
        _meals.delete(meal.id);
      }
      _meals.insert(
        merged,
        eatenAt: eatenAt,
        auditPayload: {
          'mergedFrom': [for (final meal in meals) meal.id],
        },
      );
      return merged;
    });
  }

  /// When meal [id] was eaten.
  DateTime? eatenAtOf(String id) => _meals.eatenAtOf(id);

  /// Moves a meal to when it was really eaten, another day included.
  void retimeMeal(String id, DateTime eatenAt) => _meals.retime(id, eatenAt);

  /// Takes a merge back: the merged meal goes, its parts return.
  void unmergeMeals(MealEvent merged, List<MealEvent> parts) =>
      _db.transaction(() {
        _meals.delete(merged.id);
        for (final part in parts) {
          _meals.restore(part.id);
        }
      });

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
  MealEvent logMeal(
    MealEvent meal, {
    required DateTime eatenAt,
    ChangeSource source = ChangeSource.local,
  }) {
    final stored = _meals.exists(meal.id)
        ? meal.copyWith(id: _db.newId())
        : meal;
    _meals.insert(stored, eatenAt: eatenAt, source: source);
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
  /// Saved foods matching [query], best first; an empty query is all of
  /// them.
  ///
  /// Every word has to appear somewhere — the name, the brand, the cup
  /// size or the brand's other spellings — so 「星巴克 拿鐵」 and
  /// 「starbucks 拿鐵」 find the same drink. Among the matches, a name
  /// that starts with what was typed beats one that merely contains it,
  /// which beats a match on the brand alone; within each of those, what
  /// the user starred or ate recently comes first.
  List<FoodItem> searchFoods(String query) {
    final words = [
      for (final word in query.split(RegExp(r'\s+')))
        if (normalizeTerm(word) case final term when term.isNotEmpty) term,
    ];
    if (words.isEmpty) return foods();
    final personal = {
      ..._foods.favoriteIds(),
      for (final (foodId, _, _, _) in _meals.portionsLogged()) foodId,
    };
    final ranked = <(int, bool, FoodItem)>[];
    for (final food in foods()) {
      final name = normalizeTerm(food.name);
      final elsewhere = normalizeTerm(
        '${food.brand}${food.sizeName}${food.searchTerms}',
      );
      if (!words.every((w) => name.contains(w) || elsewhere.contains(w))) {
        continue;
      }
      final inName = words.where(name.contains).toList();
      final tier = inName.isEmpty ? 2 : (inName.any(name.startsWith) ? 0 : 1);
      ranked.add((tier, personal.contains(food.id), food));
    }
    ranked.sort((a, b) {
      if (a.$1 != b.$1) return a.$1.compareTo(b.$1);
      if (a.$2 != b.$2) return a.$2 ? -1 : 1;
      return a.$3.name.compareTo(b.$3.name);
    });
    return [for (final (_, _, food) in ranked) food];
  }

  /// Brands whose shipped menu [query] names on its own — 「星巴克」 or
  /// 「starbucks」 — so the screen can offer the menu before the drinks.
  List<String> brandsNamedBy(String query) {
    final wanted = normalizeTerm(query);
    if (wanted.isEmpty) return const [];
    return {
      for (final food in foods())
        if (food.isBuiltIn &&
            [food.brand, ...food.searchTerms.split(' ')]
                .map(normalizeTerm)
                .any((name) => name.isNotEmpty && name.startsWith(wanted)))
          food.brand,
    }.toList();
  }

  /// A brand's shipped menu, without cup sizes.
  List<FoodItem> menuOf(String brand) => _foods.menuOf(brand);

  /// Starred foods and cup sizes, most recently starred first. One since
  /// deleted is left out.
  List<FoodItem> favoriteFoods() => [
    for (final id in _foods.favoriteIds()) ?_foods.byId(id),
  ];

  void setFoodFavorite(String foodId, {required bool isFavorite}) =>
      _foods.setFavorite(foodId, isFavorite: isFavorite);

  /// Logs the items of a draft the user confirmed, as eaten now and all
  /// or none. Each is marked as an estimate from an AI draft, and the
  /// audit trail keeps which provider and model it came from.
  ///
  /// [asOneMeal] logs the items as the dishes of one meal, its figures
  /// their sum — a figure any item lacks is left empty rather than
  /// undercounted; otherwise each item is a meal of its own.
  List<MealEvent> logDraft(
    MealDraft draft,
    List<DraftItem> items, {
    MealType? mealType,
    bool asOneMeal = false,
  }) {
    final eatenAt = _db.now();
    if (asOneMeal && items.length > 1) {
      int? total(int? Function(DraftItem) figure) {
        final figures = items.map(figure);
        if (figures.any((value) => value == null)) return null;
        return figures.fold<int>(0, (sum, value) => sum + value!);
      }

      final meal = MealEvent(
        id: _db.newId(),
        name: items.map((item) => item.name).join('、'),
        timeLabel: formatTimeOfDay(eatenAt),
        qualityTag: aiDraftQualityTag,
        dishes: [
          for (final item in items)
            DishEntry(
              name: item.name,
              quantityLabel: item.amount,
              subtitle: aiDraftQualityTag,
            ),
        ],
        kind: items.every((item) => item.isDrink)
            ? ConsumptionKind.beverage
            : ConsumptionKind.food,
        kcal: total((item) => item.kcal),
        proteinGrams: total((item) => item.proteinGrams),
        carbGrams: total((item) => item.carbGrams),
        fatGrams: total((item) => item.fatGrams),
        fibreGrams: total((item) => item.fibreGrams),
        nutrients: {
          for (final nutrient in Nutrient.values)
            if (items.every((item) => item.nutrients.containsKey(nutrient)))
              nutrient: items.fold(
                0.0,
                (sum, item) => sum + item.nutrients[nutrient]!,
              ),
        },
        mealType: mealType,
        isEstimated: true,
        valueType: NutrientValueType.estimate,
      );
      _db.transaction(
        () => _meals.insert(
          meal,
          eatenAt: eatenAt,
          source: ChangeSource.aiDraft,
          auditPayload: {'provider': draft.provider.name, 'model': draft.model},
        ),
      );
      return [meal];
    }
    return _db.transaction(
      () => [
        for (final item in items)
          () {
            final meal = MealEvent(
              id: _db.newId(),
              name: item.amount.isEmpty
                  ? item.name
                  : '${item.name}（${item.amount}）',
              timeLabel: formatTimeOfDay(eatenAt),
              qualityTag: aiDraftQualityTag,
              dishes: const [],
              kind: item.isDrink
                  ? ConsumptionKind.beverage
                  : ConsumptionKind.food,
              kcal: item.kcal,
              proteinGrams: item.proteinGrams,
              carbGrams: item.carbGrams,
              fatGrams: item.fatGrams,
              fibreGrams: item.fibreGrams,
              nutrients: item.nutrients,
              mealType: mealType,
              isEstimated: true,
              valueType: NutrientValueType.estimate,
            );
            _meals.insert(
              meal,
              eatenAt: eatenAt,
              source: ChangeSource.aiDraft,
              auditPayload: {
                'provider': draft.provider.name,
                'model': draft.model,
              },
            );
            return meal;
          }(),
      ],
    );
  }

  /// Logs a glass of water of [millilitres].
  ///
  /// A shortcut, not a second kind of record: it writes the same meal
  /// every drink writes, so the day's fluid is one total rather than two
  /// that disagree.
  ///
  /// [at], [id] and [source] are for water read from a health platform.
  MealEvent logWater(
    int millilitres, {
    DateTime? at,
    String? id,
    ChangeSource source = ChangeSource.local,
  }) {
    final eatenAt = at ?? _db.now();
    return logMeal(
      MealEvent(
        id: id ?? _db.newId(),
        name: '水',
        timeLabel: formatTimeOfDay(eatenAt),
        qualityTag: waterQualityTag,
        dishes: const [],
        kind: ConsumptionKind.beverage,
        millilitres: millilitres,
        kcal: 0,
        proteinGrams: 0,
        carbGrams: 0,
        fatGrams: 0,
      ),
      eatenAt: eatenAt,
      source: source,
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
  MealEvent logPortion(FoodPortion portion, {MealType? mealType}) =>
      _logPortion(portion, mealType: mealType, keepsFood: true);

  /// Logs [portion] of a food typed for this one meal and not kept, as
  /// 快速記錄 does: the same record as [logPortion], with nothing tying it
  /// to a food the list would offer again.
  MealEvent logOnce(FoodPortion portion, {MealType? mealType}) =>
      _logPortion(portion, mealType: mealType, keepsFood: false);

  MealEvent _logPortion(
    FoodPortion portion, {
    required MealType? mealType,
    required bool keepsFood,
  }) {
    final eatenAt = _db.now();
    final food = portion.food;
    final tag = keepsFood ? '自訂食物' : '快速記錄';
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
        foodId: keepsFood ? food.id : null,
        servings: keepsFood ? portion.servings : null,
        qualityTag: tag,
        dishes: [
          DishEntry(
            name: food.displayName,
            quantityLabel: portion.label,
            subtitle: tag,
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
