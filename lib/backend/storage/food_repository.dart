import '../../domain/domain.dart';
import 'database.dart';

/// The foods the user saved, so a meal eaten often is typed once.
///
/// Rows are never hard deleted: removing a food tombstones it, which
/// leaves every meal already logged from it exactly as it was.
class FoodRepository {
  FoodRepository(this._db);

  final AppDatabase _db;

  /// Every saved food, by name so the list never shuffles between opens.
  List<FoodItem> all() => [
    for (final row in _db.select(
      'SELECT * FROM foods WHERE deleted_at IS NULL ORDER BY name',
    ))
      _fromRow(row),
  ];

  FoodItem? byId(String id) {
    final rows = _db.select(
      'SELECT * FROM foods WHERE id = ? AND deleted_at IS NULL',
      [id],
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  /// Stores [food], inserting it or rewriting the one with its id.
  void save(FoodItem food, {ChangeSource source = ChangeSource.local}) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      final exists = _db
          .select('SELECT 1 FROM foods WHERE id = ?', [food.id])
          .isNotEmpty;
      if (exists) {
        _db.execute(
          'UPDATE foods SET name = ?, brand = ?, serving_label = ?, '
          'serving_amount = ?, serving_unit = ?, kcal = ?, protein_g = ?, '
          'carb_g = ?, fat_g = ?, fibre_g = ?, deleted_at = NULL, '
          'updated_at = ?, revision = revision + 1 WHERE id = ?',
          [
            food.name,
            food.brand,
            food.servingLabel,
            food.servingAmount,
            food.servingUnit.name,
            food.kcal,
            food.proteinGrams,
            food.carbGrams,
            food.fatGrams,
            food.fibreGrams,
            now,
            food.id,
          ],
        );
      } else {
        _db.execute(
          'INSERT INTO foods (id, name, brand, serving_label, '
          'serving_amount, serving_unit, kcal, protein_g, carb_g, fat_g, '
          'fibre_g, created_at, updated_at, source) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            food.id,
            food.name,
            food.brand,
            food.servingLabel,
            food.servingAmount,
            food.servingUnit.name,
            food.kcal,
            food.proteinGrams,
            food.carbGrams,
            food.fatGrams,
            food.fibreGrams,
            now,
            now,
            source.name,
          ],
        );
      }
      _db.audit(
        entityType: 'food',
        entityId: food.id,
        action: exists ? 'edit' : 'create',
        source: source,
      );
    });
  }

  /// Tombstones [id]. Meals logged from it keep their numbers: they were
  /// copied when the meal was logged, not linked.
  void delete(String id) {
    _db.transaction(() {
      _db.execute(
        'UPDATE foods SET deleted_at = ?, updated_at = ?, '
        'revision = revision + 1 WHERE id = ? AND deleted_at IS NULL',
        [
          _db.now().millisecondsSinceEpoch,
          _db.now().millisecondsSinceEpoch,
          id,
        ],
      );
      _db.audit(entityType: 'food', entityId: id, action: 'delete');
    });
  }

  /// Brings a deleted food back, for undoing a delete.
  void undelete(String id) {
    _db.transaction(() {
      _db.execute(
        'UPDATE foods SET deleted_at = NULL, updated_at = ?, '
        'revision = revision + 1 WHERE id = ?',
        [_db.now().millisecondsSinceEpoch, id],
      );
      _db.audit(entityType: 'food', entityId: id, action: 'undelete');
    });
  }

  FoodItem _fromRow(Map<String, Object?> row) => FoodItem(
    id: row['id']! as String,
    name: row['name']! as String,
    brand: row['brand']! as String,
    servingLabel: row['serving_label']! as String,
    servingAmount: (row['serving_amount']! as num).toDouble(),
    servingUnit: ServingUnit.values.byName(row['serving_unit']! as String),
    kcal: row['kcal']! as int,
    proteinGrams: row['protein_g']! as int,
    carbGrams: row['carb_g']! as int,
    fatGrams: row['fat_g']! as int,
    fibreGrams: row['fibre_g']! as int,
  );
}
