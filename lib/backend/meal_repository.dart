import '../data/models.dart';
import '../shared/format.dart';
import 'database.dart';

/// Meals keep their real structure: meal → dish → component. Exploding a
/// dish into standalone entries is an audited change that can be undone.
class MealRepository {
  MealRepository(this._db);

  final AppDatabase _db;

  /// Meals eaten on the calendar day of [day], in time order.
  List<MealEvent> onDay(DateTime day) => [
    for (final (_, meal) in between(
      DateTime(day.year, day.month, day.day),
      DateTime(day.year, day.month, day.day + 1),
    ))
      meal,
  ];

  /// Meals eaten in `[start, end)` with their time, oldest first.
  List<(DateTime, MealEvent)> between(DateTime start, DateTime end) => [
    for (final row in _db.select(
      'SELECT * FROM meals WHERE deleted_at IS NULL '
      'AND eaten_at >= ? AND eaten_at < ? ORDER BY eaten_at',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    ))
      (DateTime.fromMillisecondsSinceEpoch(row['eaten_at']), _fromRow(row)),
  ];

  bool exists(String id) =>
      _db.select('SELECT 1 FROM meals WHERE id = ?', [id]).isNotEmpty;

  /// Stores a new meal eaten at [eatenAt].
  void insert(
    MealEvent meal, {
    required DateTime eatenAt,
    ChangeSource source = ChangeSource.local,
    String? importBatchId,
  }) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      _db.execute(
        'INSERT INTO meals (id, name, eaten_at, kcal, protein_g, carb_g, '
        'fat_g, quality_tag, is_estimated, created_at, updated_at, source, '
        'import_batch_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          meal.id,
          meal.name,
          eatenAt.millisecondsSinceEpoch,
          meal.kcal,
          meal.proteinGrams,
          meal.carbGrams,
          meal.fatGrams,
          meal.qualityTag,
          meal.isEstimated ? 1 : 0,
          now,
          now,
          source.name,
          importBatchId,
        ],
      );
      _writeDishes(meal);
      _db.audit(
        entityType: 'meal',
        entityId: meal.id,
        action: 'create',
        source: source,
        importBatchId: importBatchId,
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
      timeLabel: formatTimeOfDay(
        DateTime.fromMillisecondsSinceEpoch(row['eaten_at']! as int),
      ),
      kcal: row['kcal']! as int,
      proteinGrams: row['protein_g']! as int,
      carbGrams: row['carb_g']! as int,
      fatGrams: row['fat_g']! as int,
      qualityTag: row['quality_tag']! as String,
      isEstimated: row['is_estimated'] == 1,
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
