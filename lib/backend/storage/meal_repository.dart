import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../engines/nutrition_summary.dart';
import 'database.dart';
import 'food_repository.dart' show readNutrients;
import 'timeline_source.dart';

/// Meals keep their real structure: meal → dish → component. Exploding a
/// dish into standalone entries is an audited change that can be undone.
class MealRepository {
  MealRepository(this._db);

  final AppDatabase _db;

  /// Meals eaten on the calendar day of [day], in time order.
  ///
  /// By the day the meal was eaten on, not by an instant range in
  /// whatever zone the phone is in now: breakfast in Taipei stays on
  /// that day after the flight to Los Angeles.
  List<MealEvent> onDay(DateTime day) => [
    for (final row in _db.select(
      'SELECT * FROM meals WHERE deleted_at IS NULL '
      'AND ${AppDatabase.localDaySql('eaten_at')} = ? ORDER BY eaten_at',
      [localDayOf(day)],
    ))
      _fromRow(row),
  ];

  /// Meals eaten in `[start, end)` with their time, oldest first.
  /// Stars or unstars a meal, so it can be logged again without going
  /// looking for the day it was eaten.
  void setFavorite(String id, {required bool isFavorite}) {
    _db.transaction(() {
      _db.execute(
        'UPDATE meals SET is_favorite = ?, updated_at = ?, '
        'revision = revision + 1 WHERE id = ?',
        [isFavorite ? 1 : 0, _db.now().millisecondsSinceEpoch, id],
      );
      _db.audit(
        entityType: 'meal',
        entityId: id,
        action: isFavorite ? 'favorite' : 'unfavorite',
      );
    });
  }

  /// Labelled meals since [since], with the time each was eaten as
  /// lived, for learning what the user calls a meal at a given hour.
  List<(DateTime, MealType)> labelledSince(DateTime since) => [
    for (final row in _db.select(
      'SELECT eaten_at, utc_offset_minutes, meal_type FROM meals '
      'WHERE deleted_at IS NULL AND meal_type IS NOT NULL AND eaten_at >= ?',
      [since.millisecondsSinceEpoch],
    ))
      (
        asLived(
          DateTime.fromMillisecondsSinceEpoch(row['eaten_at']! as int),
          row['utc_offset_minutes'] as int?,
        ),
        MealType.values.byName(row['meal_type']! as String),
      ),
  ];

  /// Starred meals, newest first.
  List<(DateTime, MealEvent)> favorites() => [
    for (final row in _db.select(
      'SELECT * FROM meals WHERE is_favorite = 1 AND deleted_at IS NULL '
      'ORDER BY eaten_at DESC',
    ))
      (DateTime.fromMillisecondsSinceEpoch(row['eaten_at']), _fromRow(row)),
  ];

  List<(DateTime, MealEvent)> between(DateTime start, DateTime end) => [
    for (final row in _db.select(
      'SELECT * FROM meals WHERE deleted_at IS NULL '
      'AND eaten_at >= ? AND eaten_at < ? ORDER BY eaten_at',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    ))
      (DateTime.fromMillisecondsSinceEpoch(row['eaten_at']), _fromRow(row)),
  ];

  /// Meals whose local day falls in `[fromDay, toDay]`, each with that
  /// day and the time it was eaten as lived.
  List<(int, DateTime, MealEvent)> inDays(int fromDay, int toDay) => [
    for (final row in _db.select(
      'SELECT *, ${AppDatabase.localDaySql('eaten_at')} AS day FROM meals '
      'WHERE deleted_at IS NULL AND day BETWEEN ? AND ? ORDER BY eaten_at',
      [fromDay, toDay],
    ))
      (
        row['day']! as int,
        asLived(
          DateTime.fromMillisecondsSinceEpoch(row['eaten_at']! as int),
          row['utc_offset_minutes'] as int?,
        ),
        _fromRow(row),
      ),
  ];

  /// Meal [id] as it is now; null when there is none or it was deleted.
  MealEvent? byId(String id) {
    final rows = _db.select(
      'SELECT * FROM meals WHERE id = ? AND deleted_at IS NULL',
      [id],
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  /// When meal [id] was eaten; null when there is no such meal.
  DateTime? eatenAtOf(String id) {
    final rows = _db.select('SELECT eaten_at FROM meals WHERE id = ?', [id]);
    return rows.isEmpty
        ? null
        : DateTime.fromMillisecondsSinceEpoch(rows.first['eaten_at']! as int);
  }

  /// Moves meal [id] to when it was really eaten: its time, its day and
  /// the offset it is read in all follow. The old time is audited.
  void retime(String id, DateTime eatenAt) {
    _db.transaction(() {
      final previous = eatenAtOf(id);
      _db.execute(
        'UPDATE meals SET eaten_at = ?, local_day = ?, '
        'utc_offset_minutes = ?, updated_at = ?, revision = revision + 1 '
        'WHERE id = ?',
        [
          eatenAt.millisecondsSinceEpoch,
          localDayOf(eatenAt),
          eatenAt.timeZoneOffset.inMinutes,
          _db.now().millisecondsSinceEpoch,
          id,
        ],
      );
      _db.audit(
        entityType: 'meal',
        entityId: id,
        action: 'retime',
        payload: {'previous': previous?.toUtc().toIso8601String()},
      );
    });
  }

  /// Removes a logged meal; [restore] takes it back. A tombstone, like
  /// every other record.
  /// Puts meals [ids] in group [groupId], or takes them out of any with
  /// null. The group each was in before is audited.
  void setGroup(Iterable<String> ids, String? groupId) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      for (final id in ids) {
        final previous = _db.select('SELECT group_id FROM meals WHERE id = ?', [
          id,
        ]);
        _db.execute(
          'UPDATE meals SET group_id = ?, updated_at = ?, '
          'revision = revision + 1 WHERE id = ?',
          [groupId, now, id],
        );
        _db.audit(
          entityType: 'meal',
          entityId: id,
          action: groupId == null ? 'ungroup' : 'group',
          payload: {
            'group': groupId,
            'previous': previous.isEmpty ? null : previous.first['group_id'],
          },
        );
      }
    });
  }

  /// The ids of the live meals in group [groupId].
  List<String> groupMembers(String groupId) => [
    for (final row in _db.select(
      'SELECT id FROM meals WHERE group_id = ? AND deleted_at IS NULL',
      [groupId],
    ))
      row['id']! as String,
  ];

  /// The live items of group [groupId], in the order eaten.
  List<MealEvent> inGroup(String groupId) => [
    for (final row in _db.select(
      'SELECT * FROM meals WHERE group_id = ? AND deleted_at IS NULL '
      'ORDER BY eaten_at',
      [groupId],
    ))
      _fromRow(row),
  ];

  /// Calls meals [ids] [mealType], or no sitting with null.
  void setMealType(Iterable<String> ids, MealType? mealType) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      for (final id in ids) {
        _db.execute(
          'UPDATE meals SET meal_type = ?, updated_at = ?, '
          'revision = revision + 1 WHERE id = ?',
          [mealType?.name, now, id],
        );
        _db.audit(
          entityType: 'meal',
          entityId: id,
          action: 'meal_type',
          payload: {'mealType': mealType?.name},
        );
      }
    });
  }

  void delete(String id) => _setDeleted(id, deleted: true);

  void restore(String id) => _setDeleted(id, deleted: false);

  void _setDeleted(String id, {required bool deleted}) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      _db.execute(
        'UPDATE meals SET deleted_at = ?, updated_at = ?, '
        'revision = revision + 1 WHERE id = ?',
        [deleted ? now : null, now, id],
      );
      _db.audit(
        entityType: 'meal',
        entityId: id,
        action: deleted ? 'delete' : 'restore',
      );
    });
  }

  /// Portions logged from saved foods, newest first: which food, how
  /// many servings, which meal it was called and when.
  List<(String, double, MealType?, DateTime)> portionsLogged({
    int limit = 200,
  }) => [
    for (final row in _db.select(
      'SELECT food_id, servings, meal_type, eaten_at, utc_offset_minutes '
      'FROM meals WHERE deleted_at IS NULL AND food_id IS NOT NULL '
      'AND servings IS NOT NULL ORDER BY eaten_at DESC LIMIT ?',
      [limit],
    ))
      (
        row['food_id']! as String,
        (row['servings']! as num).toDouble(),
        switch (row['meal_type'] as String?) {
          final name? => MealType.values.byName(name),
          null => null,
        },
        asLived(
          DateTime.fromMillisecondsSinceEpoch(row['eaten_at']! as int),
          row['utc_offset_minutes'] as int?,
        ),
      ),
  ];

  bool exists(String id) =>
      _db.select('SELECT 1 FROM meals WHERE id = ?', [id]).isNotEmpty;

  /// Stores a new meal eaten at [eatenAt].
  void insert(
    MealEvent meal, {
    required DateTime eatenAt,
    ChangeSource source = ChangeSource.local,
    String? importBatchId,
    Object? auditPayload,
  }) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      _db.execute(
        'INSERT INTO meals (id, name, eaten_at, kcal, protein_g, carb_g, '
        'fat_g, fibre_g, millilitres, consumption_kind, meal_type, '
        'value_type, quality_tag, is_estimated, created_at, updated_at, '
        'source, import_batch_id, local_day, utc_offset_minutes, food_id, '
        'servings, group_id) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, '
        '?, ?, ?)',
        [
          meal.id,
          meal.name,
          eatenAt.millisecondsSinceEpoch,
          meal.kcal,
          meal.proteinGrams,
          meal.carbGrams,
          meal.fatGrams,
          meal.fibreGrams,
          meal.millilitres,
          meal.kind.name,
          meal.mealType?.name,
          meal.valueType.name,
          meal.qualityTag,
          meal.isEstimated ? 1 : 0,
          now,
          now,
          source.name,
          importBatchId,
          localDayOf(eatenAt),
          eatenAt.timeZoneOffset.inMinutes,
          meal.foodId,
          meal.servings,
          meal.groupId,
        ],
      );
      _writeDishes(meal);
      _writeNutrients(meal);
      _db.audit(
        entityType: 'meal',
        entityId: meal.id,
        action: 'create',
        source: source,
        importBatchId: importBatchId,
        payload: auditPayload,
      );
    });
  }

  /// Rewrites what a meal was: its name and its totals. The dishes are
  /// untouched — this is the user correcting the numbers, usually ones
  /// that were estimated for them.
  void updateTotals(MealEvent meal, {required MealEvent previous}) {
    _db.transaction(() {
      _db.execute(
        'UPDATE meals SET name = ?, kcal = ?, protein_g = ?, carb_g = ?, '
        'fat_g = ?, fibre_g = ?, millilitres = ?, is_estimated = ?, '
        'quality_tag = ?, meal_type = ?, updated_at = ?, '
        'revision = revision + 1 WHERE id = ?',
        [
          meal.name,
          meal.kcal,
          meal.proteinGrams,
          meal.carbGrams,
          meal.fatGrams,
          meal.fibreGrams,
          meal.millilitres,
          meal.isEstimated ? 1 : 0,
          meal.qualityTag,
          meal.mealType?.name,
          _db.now().millisecondsSinceEpoch,
          meal.id,
        ],
      );
      // The other nutrients are the meal's too; an edit that left them
      // out kept the old ones under new totals.
      _writeNutrients(meal);
      _db.audit(
        entityType: 'meal',
        entityId: meal.id,
        action: 'edit',
        payload: {
          'previous': {
            'name': previous.name,
            'kcal': previous.kcal,
            'protein_g': previous.proteinGrams,
            'carb_g': previous.carbGrams,
            'fat_g': previous.fatGrams,
            'fibre_g': previous.fibreGrams,
            'millilitres': previous.millilitres,
            'meal_type': previous.mealType?.name,
            'nutrients': {
              for (final MapEntry(key: nutrient, value: amount)
                  in previous.nutrients.entries)
                nutrient.name: amount,
            },
          },
        },
      );
    });
  }

  /// Replaces the dishes of a stored meal. The previous dishes go into the
  /// audit payload so the change stays traceable after an undo.
  void replaceDishes(
    MealEvent meal, {
    required String action,
    required MealEvent previous,
  }) {
    _db.transaction(() {
      _db.execute(
        'UPDATE meals SET updated_at = ?, revision = revision + 1 '
        'WHERE id = ?',
        [_db.now().millisecondsSinceEpoch, meal.id],
      );
      _db.execute('DELETE FROM dish_components WHERE meal_id = ?', [meal.id]);
      _db.execute('DELETE FROM meal_dishes WHERE meal_id = ?', [meal.id]);
      _writeDishes(meal);
      _db.audit(
        entityType: 'meal',
        entityId: meal.id,
        action: action,
        payload: {
          'previousDishes': [for (final dish in previous.dishes) dish.name],
        },
      );
    });
  }

  void _writeNutrients(MealEvent meal) {
    _db.execute('DELETE FROM meal_nutrients WHERE meal_id = ?', [meal.id]);
    for (final MapEntry(key: nutrient, value: amount)
        in meal.nutrients.entries) {
      _db.execute(
        'INSERT INTO meal_nutrients (meal_id, nutrient, amount) '
        'VALUES (?, ?, ?)',
        [meal.id, nutrient.name, amount],
      );
    }
  }

  void _writeDishes(MealEvent meal) {
    for (final (position, dish) in meal.dishes.indexed) {
      _db.execute(
        'INSERT INTO meal_dishes (meal_id, position, name, quantity_label, '
        'subtitle) VALUES (?, ?, ?, ?, ?)',
        [meal.id, position, dish.name, dish.quantityLabel, dish.subtitle],
      );
      for (final (componentPosition, component) in dish.components.indexed) {
        _db.execute(
          'INSERT INTO dish_components (meal_id, dish_position, position, '
          'name, amount_label, source_label) VALUES (?, ?, ?, ?, ?, ?)',
          [
            meal.id,
            position,
            componentPosition,
            component.name,
            component.amountLabel,
            component.source,
          ],
        );
      }
    }
  }

  MealEvent _fromRow(Map<String, Object?> row) {
    final id = row['id']! as String;
    final dishes = _db.select(
      'SELECT * FROM meal_dishes WHERE meal_id = ? ORDER BY position',
      [id],
    );
    final components = _db.select(
      'SELECT * FROM dish_components WHERE meal_id = ? '
      'ORDER BY dish_position, position',
      [id],
    );
    return MealEvent(
      id: id,
      name: row['name']! as String,
      // The clock the person read when they ate, not the one the phone
      // shows now: 08:10 in Taipei does not become 17:10 by flying.
      timeLabel: formatTimeOfDay(
        asLived(
          DateTime.fromMillisecondsSinceEpoch(row['eaten_at']! as int),
          row['utc_offset_minutes'] as int?,
        ),
      ),
      kcal: row['kcal'] as int?,
      proteinGrams: row['protein_g'] as int?,
      fibreGrams: row['fibre_g'] as int?,
      carbGrams: row['carb_g'] as int?,
      fatGrams: row['fat_g'] as int?,
      qualityTag: row['quality_tag']! as String,
      isEstimated: row['is_estimated'] == 1,
      isFavorite: row['is_favorite'] == 1,
      millilitres: row['millilitres'] as int?,
      kind: ConsumptionKind.values.byName(row['consumption_kind']! as String),
      foodId: row['food_id'] as String?,
      servings: (row['servings'] as num?)?.toDouble(),
      groupId: row['group_id'] as String?,
      mealType: switch (row['meal_type'] as String?) {
        final name? => MealType.values.byName(name),
        null => null,
      },
      valueType: NutrientValueType.values.byName(row['value_type']! as String),
      nutrients: readNutrients(_db, 'meal_nutrients', 'meal_id', id),
      dishes: [
        for (final dish in dishes)
          DishEntry(
            name: dish['name'],
            quantityLabel: dish['quantity_label'],
            subtitle: dish['subtitle'],
            components: [
              for (final component in components)
                if (component['dish_position'] == dish['position'])
                  FoodComponent(
                    name: component['name'],
                    amountLabel: component['amount_label'],
                    source: component['source_label'],
                  ),
            ],
          ),
      ],
    );
  }
}

/// Meals as log rows, plus the day's food totals and whether the day's log
/// looks too thin to compare.
class MealTimelineSource extends TimelineSource {
  MealTimelineSource(this._meals);

  final MealRepository _meals;

  @override
  RecordCategory get category => RecordCategory.nutrition;

  @override
  DateTime? earliest() {
    final first = _meals._db
        .select(
          'SELECT MIN(eaten_at) AS first FROM meals '
          'WHERE deleted_at IS NULL',
        )
        .first['first'];
    return first == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(first as int);
  }

  @override
  List<(DateTime, TimelineEntry)> entriesIn(DateTime start, DateTime end) {
    final records = _meals.inDays(
      localDayOf(start),
      localDayOf(end.subtract(const Duration(days: 1))),
    );
    final eatenAt = {for (final (_, at, meal) in records) meal.id: at};
    // One row a meal: a group's items are one meal, at its first item.
    return [
      for (final meal in mealsOf([for (final (_, _, meal) in records) meal]))
        (eatenAt[meal.first.id]!, _entryOf(meal, eatenAt[meal.first.id]!)),
    ];
  }

  static TimelineEntry _entryOf(List<MealEvent> meal, DateTime at) {
    final first = meal.first;
    // Water is how much of it: its 0 kcal and its own name as a tag
    // would say nothing.
    if (meal.length == 1 && first.isWater) {
      return TimelineEntry(
        timeLabel: first.timeLabel,
        at: at,
        recordId: first.id,
        category: RecordCategory.nutrition,
        title: first.name,
        detail: switch (first.millilitres) {
          final millilitres? => '$millilitres ml',
          null => '',
        },
      );
    }
    return TimelineEntry(
      timeLabel: first.timeLabel,
      at: at,
      recordId: first.id,
      category: RecordCategory.nutrition,
      title: meal.map((item) => item.name).join('、'),
      detail: meal.length == 1
          ? first.dishes.map((dish) => dish.name).join('、')
          : '${meal.length} 項',
      tags: [
        '${formatKcalOrDash(mealKcalOf(meal))} kcal',
        if (meal.length == 1) first.qualityTag,
      ],
    );
  }

  @override
  Map<int, String> summariesIn(DateTime start, DateTime end) => {
    for (final MapEntry(key: day, value: meals) in _byDay(start, end).entries)
      day: _summaryOf(summariseDay(meals)),
  };

  @override
  Map<int, String> warningsIn(DateTime start, DateTime end) {
    final today = _meals._db.now();
    final endOfYesterday = DateTime(today.year, today.month, today.day);
    return {
      for (final MapEntry(key: day, value: meals) in _byDay(start, end).entries)
        if (isFoodLogIncomplete(
          summariseDay(
            meals,
            isOver: DateTime(
              start.year,
              start.month,
              day,
            ).isBefore(endOfYesterday),
          ),
        ))
          day: '有未記錄的餐',
    };
  }

  static String _summaryOf(DaySummary summary) =>
      '${summary.mealCount} 餐 · ${formatKcal(summary.kcal)} kcal';

  /// The month's meals by day of the month, grouped by the day each was
  /// eaten on rather than by where the reader is standing now.
  Map<int, List<MealEvent>> _byDay(DateTime start, DateTime end) {
    final byDay = <int, List<MealEvent>>{};
    for (final (day, _, meal) in _meals.inDays(
      localDayOf(start),
      localDayOf(end.subtract(const Duration(days: 1))),
    )) {
      (byDay[day % 100] ??= []).add(meal);
    }
    return byDay;
  }
}
