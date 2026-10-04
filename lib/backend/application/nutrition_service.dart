import 'dart:convert';

import '../../domain/domain.dart';
// The one place that decides how a typed search term is normalised; a
// food is searched the same way an exercise is.
import '../engines/caffeine.dart';
import '../engines/exercise_search.dart' show normalizeTerm;
import '../engines/food_portion.dart';
import '../engines/food_search.dart';
import '../../shared/format.dart';
import '../engines/meal_type_suggestion.dart';
import '../engines/nutrition_summary.dart';
import '../engines/nutrition_targets.dart';
import '../seed/packaged_foods.dart';
import '../storage/database.dart';
import '../storage/food_repository.dart';
import '../storage/meal_repository.dart';
import 'insights_service.dart';
import 'journal_service.dart';
import '../../l10n/l10n.dart';

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

/// Meals as they were before [NutritionService.mergeMeals], by id.
typedef MealsBefore =
    Map<String, ({String? groupId, MealType? mealType, DateTime? eatenAt})>;

/// Logging food and changing how a meal is structured.
class NutritionService {
  NutritionService(
    this._db,
    this._meals,
    this._foods,
    this._journal,
    this._insights,
    this._l10n,
  );

  /// The language of what is written into a record: a portion's label.
  final AppLocalizations _l10n;

  final AppDatabase _db;
  final MealRepository _meals;
  final FoodRepository _foods;

  /// The packaged foods that ship with the app, which [searchFoods] can
  /// look through. Empty until the app has read them.
  PackagedFoods packagedFoods = PackagedFoods.empty;

  /// Where the body the targets are worked out from is kept.
  final JournalService _journal;
  final InsightsService _insights;

  static const _targetsKey = 'nutrition.targets';
  static const _conventionKey = 'nutrition.convention';

  /// Whose way of reading a label the day's totals follow; Taiwan's until
  /// the user picks another.
  NutritionConvention get convention =>
      NutritionConvention.values.asNameMap()[_db.setting(_conventionKey)] ??
      NutritionConvention.taiwan;

  void setConvention(NutritionConvention convention) =>
      _db.setSetting(_conventionKey, convention.name);

  static const _waterReferenceKey = 'water.reference_ml';

  /// 國健署's adult reference for plain water: at least 1,500 mL a day
  /// (2021). A population figure, not anyone's requirement, and the only
  /// official one given as plain water rather than total water.
  static const taiwanWaterReferenceMl = 1500;

  /// The plain water a day's level fills towards; null draws no level.
  /// Until the user chooses, Taiwan's reference while the day follows
  /// Taiwan's rules, and none elsewhere.
  int? get waterReferenceMl => switch (_db.setting(_waterReferenceKey)) {
    null || '' =>
      convention == NutritionConvention.taiwan ? taiwanWaterReferenceMl : null,
    final stored => int.tryParse(stored),
  };

  /// Sets the reference, or clears it with null so no level is drawn.
  void setWaterReferenceMl(int? millilitres) => _db.setSetting(
    _waterReferenceKey,
    millilitres == null ? 'none' : '$millilitres',
  );

  /// The day's salt limit in [convention]'s measure: mg of sodium, or g
  /// of salt for the user's sex.
  double get saltLimit => convention.saltLimit(_journal.sex);

  /// What the user chose for their daily targets.
  NutritionTargetSettings get targetSettings {
    final raw = _db.setting(_targetsKey);
    if (raw == null || raw.isEmpty) return const NutritionTargetSettings();
    final fields = jsonDecode(raw) as Map<String, dynamic>;
    var protein = (fields['proteinPerKg'] as num?)?.toDouble();
    var fat = fields['fatPercent'] as int?;
    // Written before the split followed the goal, every setting held a
    // number: the old defaults there were never chosen, so they follow
    // the goal now.
    if (fields['version'] == null) {
      if (protein == 1.6) protein = null;
      if (fat == 25) fat = null;
    }
    return NutritionTargetSettings(
      customKcal: (fields['customKcal'] as num?)?.toDouble(),
      activity:
          ActivityLevel.values.asNameMap()[fields['activity']] ??
          ActivityLevel.moderate,
      goal:
          WeightGoal.values.asNameMap()[fields['goal']] ?? WeightGoal.maintain,
      weeklyPercent: (fields['weeklyPercent'] as num?)?.toDouble(),
      proteinPerKg: protein,
      fatPercent: fat,
    );
  }

  void setTargetSettings(NutritionTargetSettings settings) => _db.setSetting(
    _targetsKey,
    jsonEncode({
      'version': 2,
      'customKcal': settings.customKcal,
      'activity': settings.activity.name,
      'goal': settings.goal.name,
      'weeklyPercent': settings.weeklyPercent,
      'proteinPerKg': settings.proteinPerKg,
      'fatPercent': settings.fatPercent,
    }),
  );

  /// The targets for [day], from the body as it was then and, once the
  /// records show it, what the user really burns.
  NutritionTargets targetsOn(DateTime day) {
    final energy = _insights.energyOn(day);
    return nutritionTargets(
      targetSettings,
      weightKg: _journal.weightOn(day)?.weightKg,
      heightCm: _journal.heightCm,
      age: _journal.ageOn(day),
      sex: _journal.sex,
      measuredMaintenanceKcal:
          energy == null || energy.isIntakeLikelyUnderlogged
          ? null
          : energy.expenditure,
    );
  }

  List<MealEvent> mealsOn(DateTime day) => _meals.onDay(day);

  /// The caffeine over the bedtime reference now: the last record that
  /// carried any, and when the estimate falls under the reference
  /// ([caffeineFallsBelowReference]); null while it is under it.
  ({DateTime at, MealEvent meal, DateTime below})? caffeineOverReference() {
    final now = _db.now();
    final meals = _caffeineMeals(now);
    final below = caffeineFallsBelowReference(caffeineIntakes(meals), now: now);
    if (below == null) return null;
    final (at, meal) = meals.lastWhere(
      (eaten) => (eaten.$2.nutrients[Nutrient.caffeine] ?? 0) > 0,
    );
    return (at: at, meal: meal, below: below);
  }

  /// The records old enough to still show on the caffeine curve at [at].
  List<(DateTime, MealEvent)> _caffeineMeals(DateTime at) =>
      between(at.subtract(caffeineCurveBack + const Duration(days: 1)), at);

  static const _caffeineActivityKey = 'caffeine.live_activity';

  /// Whether caffeine over the bedtime reference is shown on the lock
  /// screen (`lib/app/caffeine_activity.dart`); on until turned off.
  bool get isCaffeineActivityOn => _db.setting(_caffeineActivityKey) != 'false';

  void setCaffeineActivity(bool isOn) =>
      _db.setSetting(_caffeineActivityKey, '$isOn');

  static const _caffeineActivityEndedKey = 'caffeine.live_activity_ended';

  /// The last cup whose Live Activity was ended from 今天: it is not shown
  /// again for that cup, only for a later one.
  DateTime? get caffeineActivityEndedFor =>
      switch (int.tryParse(_db.setting(_caffeineActivityEndedKey) ?? '')) {
        final ms? => DateTime.fromMillisecondsSinceEpoch(ms),
        null => null,
      };

  void endCaffeineActivity(DateTime cupAt) => _db.setSetting(
    _caffeineActivityEndedKey,
    '${cupAt.millisecondsSinceEpoch}',
  );

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
  /// A null [window] reaches back to the first meal.
  List<RecentMeal> recent({
    int limit = 3,
    Duration? window = const Duration(days: 30),
  }) {
    final now = _db.now();
    final seen = <String>{};
    final recent = <RecentMeal>[];
    final since = window == null
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : now.subtract(window);
    for (final (eatenAt, meal) in between(since, now).reversed) {
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
    const page = 200;
    final recent = <String, RecentFood>{};
    // Read the log a page at a time, as far back as it takes: a food
    // eaten every day fills pages without adding a new one.
    for (var offset = 0; ; offset += page) {
      final portions = _meals.portionsLogged(limit: page, offset: offset);
      for (final (foodId, servings, mealType, eatenAt) in portions) {
        if (recent.containsKey(foodId)) continue;
        final food = _foods.byId(foodId);
        if (food == null) continue;
        recent[foodId] = RecentFood(
          food: food,
          servings: servings,
          eatenAt: eatenAt,
          mealType: mealType,
        );
        if (recent.length == limit) return recent.values.toList();
      }
      if (portions.length < page) return recent.values.toList();
    }
  }

  /// Logs several portions as eaten now, or [at], all or none: a plate
  /// is one action, so it is written in one transaction and undone as one.
  List<MealEvent> logPortions(
    List<FoodPortion> portions, {
    MealType? mealType,
    DateTime? at,
    (AiProviderKind, String)? Function(FoodPortion portion)? draftedByOf,
  }) => _db.transaction(
    () => [
      for (final portion in portions)
        logPortion(
          portion,
          mealType: mealType,
          at: at,
          draftedBy: draftedByOf?.call(portion),
        ),
    ],
  );

  /// Puts separately logged [meals] together as one meal: one group,
  /// each keeping its own record and figures, so the meal is always their
  /// sum and editing one item changes it. It is called [name], or by its
  /// items while that is blank. Returns the group each was in before, for
  /// [regroupMeals] to take it back.
  Map<String, String?> groupMeals(List<MealEvent> meals, {String name = ''}) {
    assert(meals.length > 1, 'a meal of one is not a group');
    final groupId = _db.newId();
    final previous = {for (final meal in meals) meal.id: meal.groupId};
    _db.transaction(() {
      _meals.setGroup(previous.keys, groupId);
      if (name.trim().isNotEmpty) _meals.nameGroup(groupId, name.trim());
    });
    return previous;
  }

  /// [groupMeals], with what a meal has once for all its items: every
  /// item takes [mealType], and [eatenAt] when given. Returns each item's
  /// group, sitting and time before, for [unmergeMeals].
  MealsBefore mergeMeals(
    List<MealEvent> meals, {
    String name = '',
    required MealType? mealType,
    DateTime? eatenAt,
  }) => _db.transaction(() {
    final before = {
      for (final meal in meals)
        meal.id: (
          groupId: meal.groupId,
          mealType: meal.mealType,
          eatenAt: _meals.eatenAtOf(meal.id),
        ),
    };
    groupMeals(meals, name: name);
    _meals.setMealType(before.keys, mealType);
    if (eatenAt != null) {
      for (final id in before.keys) {
        _meals.retime(id, eatenAt);
      }
    }
    return before;
  });

  /// Takes back [mergeMeals]: each item in its group, sitting and time.
  void unmergeMeals(MealsBefore before) => _db.transaction(() {
    for (final MapEntry(key: id, value: item) in before.entries) {
      _meals.setGroup([id], item.groupId);
      _meals.setMealType([id], item.mealType);
      if (item.eatenAt case final eatenAt?) _meals.retime(id, eatenAt);
    }
  });

  /// Puts meals back in the groups [groups] names, null for none: the
  /// undo of [groupMeals] and [ungroupMeals].
  void regroupMeals(Map<String, String?> groups) => _db.transaction(() {
    for (final MapEntry(key: id, value: groupId) in groups.entries) {
      _meals.setGroup([id], groupId);
    }
  });

  /// Takes a meal apart into its items, each on its own again. Returns
  /// the groups they were in, for [regroupMeals].
  Map<String, String?> ungroupMeals(List<MealEvent> items) {
    final previous = {for (final item in items) item.id: item.groupId};
    _meals.setGroup(previous.keys, null);
    return previous;
  }

  /// The items of the meal [groupId] groups, in the order eaten.
  List<MealEvent> mealGroup(String groupId) => _meals.inGroup(groupId);

  /// What the meal of [items] is called: the name its group was given,
  /// or its items.
  String nameOfMeal(List<MealEvent> items) => mealNameOf(
    items,
    groupName: switch (items.first.groupId) {
      final groupId? => mealGroupName(groupId),
      null => null,
    },
  );

  /// The name the meal [groupId] groups was given; null when it goes by
  /// its items.
  String? mealGroupName(String groupId) => _meals.groupName(groupId);

  /// Calls the meal [groupId] groups [name]; blank goes back to calling
  /// it by its items.
  void nameMealGroup(String groupId, String name) =>
      _meals.nameGroup(groupId, name.trim().isEmpty ? null : name.trim());

  /// Meal [id] as it is now; null once it is deleted.
  MealEvent? mealById(String id) => _meals.byId(id);

  /// When meal [id] was eaten.
  DateTime? eatenAtOf(String id) => _meals.eatenAtOf(id);

  /// Which AI, and which of its models, drafted the meal [id].
  (AiProviderKind, String)? draftedBy(String id) => _meals.draftedBy(id);

  /// Moves a meal to when it was really eaten, another day included; an
  /// item of a group moves the whole meal with it.
  void retimeMeal(MealEvent meal, DateTime eatenAt) => _db.transaction(() {
    for (final id in _withGroup(meal)) {
      _meals.retime(id, eatenAt);
    }
  });

  /// [meal], or every item of the meal it belongs to.
  List<String> _withGroup(MealEvent meal) => switch (meal.groupId) {
    final groupId? => _meals.groupMembers(groupId),
    null => [meal.id],
  };

  /// Removes logged meals; [restoreMeals] takes them back.
  void deleteMeals(Iterable<String> ids) =>
      _db.transaction(() => ids.forEach(_meals.delete));

  void restoreMeals(Iterable<String> ids) =>
      _db.transaction(() => ids.forEach(_meals.restore));

  /// Saves a correction to a meal's name and totals. Confirming the
  /// numbers is what takes the estimate mark off them.
  MealEvent edit(MealEvent previous, MealEvent corrected) {
    _db.transaction(() {
      _meals.updateTotals(corrected, previous: previous);
      // Which sitting it was is the whole meal's, not one item's.
      if (corrected.mealType != previous.mealType &&
          corrected.groupId != null) {
        _meals.setMealType([
          for (final id in _withGroup(corrected))
            if (id != corrected.id) id,
        ], corrected.mealType);
      }
    });
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

  /// Logs [meal] again, as eaten now or [at]: a copy, not a link, so
  /// editing one never changes the other.
  /// The star stays on the meal that was starred, so logging a
  /// favourite again does not quietly star the copy too.
  MealEvent copy(MealEvent meal, {DateTime? at}) {
    final eatenAt = at ?? _db.now();
    return logMeal(
      // On its own: the meal it was part of was eaten then, not now.
      meal.copyWith(
        id: _db.newId(),
        isFavorite: false,
        timeLabel: formatTimeOfDay(eatenAt),
        groupId: () => null,
      ),
      eatenAt: eatenAt,
    );
  }

  /// Stores [meal] eaten at [eatenAt], keeping its id free of collisions
  /// with a meal logged on another day.
  MealEvent logMeal(
    MealEvent meal, {
    required DateTime eatenAt,
    ChangeSource source = ChangeSource.local,
    Object? auditPayload,
  }) {
    final stored = _meals.exists(meal.id)
        ? meal.copyWith(id: _db.newId())
        : meal;
    _meals.insert(
      stored,
      eatenAt: eatenAt,
      source: source,
      auditPayload: auditPayload,
    );
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
  ///
  /// With [includePackaged], the shipped packaged foods the user has not
  /// saved follow, best first and capped at [packagedResultLimit].
  List<FoodItem> searchFoods(String query, {bool includePackaged = false}) {
    final words = _searchWords(query);
    if (words.isEmpty) return foods();
    final personal = {
      ..._foods.favoriteIds(),
      for (final (foodId, _, _, _) in _meals.portionsLogged()) foodId,
    };
    final saved = foods();
    final ranked = <(int, bool, FoodItem)>[];
    for (final food in saved) {
      final name = normalizeTerm(food.name);
      final elsewhere = normalizeTerm(
        '${food.brand}${food.sizeName}${food.searchTerms}',
      );
      if (foodMatchTier(words, name, elsewhere) case final tier?) {
        ranked.add((tier, personal.contains(food.id), food));
      }
    }
    ranked.sort((a, b) {
      if (a.$1 != b.$1) return a.$1.compareTo(b.$1);
      if (a.$2 != b.$2) return a.$2 ? -1 : 1;
      return a.$3.name.compareTo(b.$3.name);
    });
    return [
      for (final (_, _, food) in ranked) food,
      if (includePackaged)
        ...packagedFoods.search(words, except: {for (final f in saved) f.id}),
    ];
  }

  /// Meals logged without a saved food behind them — typed once, drafted
  /// by the AI — whose name or brand [query] finds, newest first and one
  /// per dish the way [recent] works. A meal logged from a saved food is
  /// left out, since [searchFoods] already finds that food.
  List<RecentMeal> searchMeals(String query, {int limit = 5}) {
    final words = _searchWords(query);
    if (words.isEmpty) return const [];
    final seen = <String>{};
    final found = <RecentMeal>[];
    final meals = between(DateTime.fromMillisecondsSinceEpoch(0), _db.now());
    for (final (eatenAt, meal) in meals.reversed) {
      if (meal.isWater) continue;
      if (meal.foodId case final id? when _foods.byId(id) != null) continue;
      final entry = RecentMeal(meal: meal, eatenAt: eatenAt);
      final name = normalizeTerm(entry.label);
      final elsewhere = normalizeTerm('${meal.name}${meal.brand}');
      if (foodMatchTier(words, name, elsewhere) == null) continue;
      if (!seen.add(entry.label)) continue;
      found.add(entry);
      if (found.length == limit) break;
    }
    return found;
  }

  /// The words of a typed search, each normalised; empty when nothing
  /// but spaces was typed.
  List<String> _searchWords(String query) => [
    for (final word in query.split(RegExp(r'\s+')))
      if (normalizeTerm(word) case final term when term.isNotEmpty) term,
  ];

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

  void setFoodFavorite(String foodId, {required bool isFavorite}) {
    if (isFavorite) _keepPackagedFood(foodId);
    _foods.setFavorite(foodId, isFavorite: isFavorite);
  }

  /// Whether [foodId] is a shipped packaged food the user has not saved,
  /// so there is nothing of theirs to delete yet.
  bool isUnsavedPackagedFood(String foodId) =>
      packagedFoods.contains(foodId) && _foods.byId(foodId) == null;

  /// Saves the packaged food [foodId] as a food of the user's own, unless
  /// it already is one: a meal or a star names a saved food, and the
  /// shipped list is not stored.
  void _keepPackagedFood(String foodId) {
    if (_foods.byId(foodId) != null) return;
    if (packagedFoods.byId(foodId) case final food?) _foods.save(food);
  }

  /// Logs the items of a draft the user confirmed, as eaten now and all
  /// or none. Each is marked as an estimate from an AI draft, and the
  /// audit trail keeps which provider and model it came from.
  ///
  /// [asOneMeal] logs the items as one meal: each its own record with
  /// its own figures, all in one group, called [name] when given, else
  /// what the draft named it; a blank name leaves it called by its items.
  /// Otherwise each item is a meal of its own.
  List<MealEvent> logDraft(
    MealDraft draft,
    List<DraftItem> items, {
    MealType? mealType,
    bool asOneMeal = false,
    String? name,
    DateTime? at,
  }) {
    final eatenAt = at ?? _db.now();
    final groupId = asOneMeal && items.length > 1 ? _db.newId() : null;
    final groupName = (name ?? draft.name)?.trim() ?? '';
    return _db.transaction(() {
      if (groupId != null && groupName.isNotEmpty) {
        _meals.nameGroup(groupId, groupName);
      }
      return [
        for (final item in items)
          () {
            final meal = MealEvent(
              id: _db.newId(),
              name: item.name,
              brand: item.brand,
              amount: item.amount,
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
              groupId: groupId,
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
      ];
    });
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
      waterRecord(millilitres, at: eatenAt, id: id ?? _db.newId()),
      eatenAt: eatenAt,
      source: source,
    );
  }

  /// The record a glass of [millilitres] drunk [at] is kept as, before it
  /// is logged: for water a health platform read, written elsewhere.
  MealEvent waterRecord(
    int millilitres, {
    required DateTime at,
    required String id,
  }) => MealEvent(
    id: id,
    name: _l10n.waterSection,
    timeLabel: formatTimeOfDay(at),
    qualityTag: waterQualityTag,
    dishes: const [],
    kind: ConsumptionKind.beverage,
    millilitres: millilitres,
    kcal: 0,
    proteinGrams: 0,
    carbGrams: 0,
    fatGrams: 0,
  );

  /// The record a food another app logged in a health platform is kept
  /// as, before it is logged. It is marked with that app's name, and
  /// named after the food, or after what is known of it: caffeine logged
  /// on its own is a drink of caffeine.
  MealEvent healthFoodRecord(HealthFood food, {required String id}) {
    final isCaffeineAlone =
        food.kcal == null &&
        food.nutrients.keys.every(
          (nutrient) => nutrient == Nutrient.caffeine,
        ) &&
        food.nutrients.isNotEmpty;
    return MealEvent(
      id: id,
      name:
          food.name ??
          (isCaffeineAlone
              ? Nutrient.caffeine.labelIn(_l10n)
              : food.mealType?.labelIn(_l10n) ?? _l10n.moduleNutrition),
      timeLabel: formatTimeOfDay(food.at),
      qualityTag: food.sourceName,
      dishes: const [],
      kind: isCaffeineAlone
          ? ConsumptionKind.beverage
          : ConsumptionKind.unknown,
      mealType: food.mealType,
      kcal: food.kcal,
      proteinGrams: food.proteinGrams,
      carbGrams: food.carbGrams,
      fatGrams: food.fatGrams,
      fibreGrams: food.fibreGrams,
      nutrients: food.nutrients,
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
  /// [draftedBy] is the model that read the figures, when one did: the
  /// record then says so, and says which one, rather than reading as the
  /// user's own numbers.
  MealEvent logPortion(
    FoodPortion portion, {
    MealType? mealType,
    DateTime? at,
    (AiProviderKind, String)? draftedBy,
  }) => _logPortion(
    portion,
    mealType: mealType,
    keepsFood: true,
    at: at,
    draftedBy: draftedBy,
  );

  /// Logs [portion] of a food typed for this one meal and not kept, as
  /// 快速記錄 does: the same record as [logPortion], with nothing tying it
  /// to a food the list would offer again.
  MealEvent logOnce(
    FoodPortion portion, {
    MealType? mealType,
    DateTime? at,
    (AiProviderKind, String)? draftedBy,
  }) => _logPortion(
    portion,
    mealType: mealType,
    keepsFood: false,
    at: at,
    draftedBy: draftedBy,
  );

  MealEvent _logPortion(
    FoodPortion portion, {
    required MealType? mealType,
    required bool keepsFood,
    DateTime? at,
    (AiProviderKind, String)? draftedBy,
  }) {
    final eatenAt = at ?? _db.now();
    final food = portion.food;
    if (keepsFood) _keepPackagedFood(food.id);
    final tag = switch (draftedBy) {
      _? => aiDraftQualityTag,
      null => keepsFood ? customFoodQualityTag : quickLogQualityTag,
    };
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
        valueType: draftedBy == null
            ? food.valueType
            : NutrientValueType.estimate,
        isEstimated: draftedBy != null,
        foodId: keepsFood ? food.id : null,
        servings: keepsFood ? portion.servings : null,
        labelCountry: food.country,
        brand: food.brand,
        qualityTag: tag,
        dishes: [
          DishEntry(
            name: food.displayName,
            quantityLabel: portion.labelIn(_l10n),
            subtitle: tag,
          ),
        ],
      ),
      eatenAt: eatenAt,
      source: draftedBy == null ? ChangeSource.local : ChangeSource.aiDraft,
      auditPayload: switch (draftedBy) {
        (final provider, final model) => {
          'provider': provider.name,
          'model': model,
        },
        null => null,
      },
    );
  }

  bool _isToday(DateTime day) {
    final now = _db.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }
}
