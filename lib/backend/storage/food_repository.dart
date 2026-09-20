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
  /// Sizes are left out: they belong to the food they are a size of.
  List<FoodItem> all() => [
    for (final row in _db.select(
      'SELECT * FROM foods WHERE deleted_at IS NULL AND parent_id IS NULL '
      'ORDER BY name',
    ))
      _fromRow(row),
  ];

  /// The size names this brand already uses, in the order they were
  /// first seen. A brand's cups are a fixed set — Short, Tall, Grande,
  /// Venti — so the second drink from the same shop should not have to
  /// be told about them again.
  List<String> sizeNamesFor(String brand) => [
    for (final row in _db.select(
      'SELECT DISTINCT size_name FROM foods '
      'WHERE brand = ? AND size_name <> \'\' AND deleted_at IS NULL '
      'ORDER BY serving_amount',
      [brand],
    ))
      row['size_name']! as String,
  ];

  /// The sizes of [foodId], smallest first.
  List<FoodItem> sizesOf(String foodId) => [
    for (final row in _db.select(
      'SELECT * FROM foods WHERE parent_id = ? AND deleted_at IS NULL '
      'ORDER BY serving_amount',
      [foodId],
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
          'carb_g = ?, fat_g = ?, fibre_g = ?, parent_id = ?, '
          'size_name = ?, consumption_kind = ?, value_type = ?, '
          'source_url = ?, checked_at = ?, deleted_at = NULL, '
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
            food.parentId,
            food.sizeName,
            food.kind.name,
            food.valueType.name,
            food.sourceUrl,
            food.checkedAt?.millisecondsSinceEpoch,
            now,
            food.id,
          ],
        );
      } else {
        _db.execute(
          'INSERT INTO foods (id, name, brand, serving_label, '
          'serving_amount, serving_unit, kcal, protein_g, carb_g, fat_g, '
          'fibre_g, parent_id, size_name, consumption_kind, value_type, '
          'source_url, checked_at, created_at, updated_at, source) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
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
            food.parentId,
            food.sizeName,
            food.kind.name,
            food.valueType.name,
            food.sourceUrl,
            food.checkedAt?.millisecondsSinceEpoch,
            now,
            now,
            source.name,
          ],
        );
      }
      _db.execute('DELETE FROM food_nutrients WHERE food_id = ?', [food.id]);
      for (final MapEntry(key: nutrient, value: amount)
          in food.nutrients.entries) {
        _db.execute(
          'INSERT INTO food_nutrients (food_id, nutrient, amount) '
          'VALUES (?, ?, ?)',
          [food.id, nutrient.name, amount],
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

  /// Tombstones [id] and any sizes of it. Meals logged from them keep
  /// their numbers: those were copied when the meal was logged.
  void delete(String id) {
    _db.transaction(() {
      for (final size in sizesOf(id)) {
        _db.execute(
          'UPDATE foods SET deleted_at = ?, updated_at = ?, '
          'revision = revision + 1 WHERE id = ?',
          [
            _db.now().millisecondsSinceEpoch,
            _db.now().millisecondsSinceEpoch,
            size.id,
          ],
        );
      }
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

  FoodItem _fromRow(Map<String, Object?> row) {
    final id = row['id']! as String;
    return FoodItem(
      id: id,
      name: row['name']! as String,
      brand: row['brand']! as String,
      servingLabel: row['serving_label']! as String,
      servingAmount: (row['serving_amount']! as num).toDouble(),
      servingUnit: ServingUnit.values.byName(row['serving_unit']! as String),
      kcal: row['kcal'] as int?,
      proteinGrams: row['protein_g'] as int?,
      carbGrams: row['carb_g'] as int?,
      fatGrams: row['fat_g'] as int?,
      fibreGrams: row['fibre_g'] as int?,
      nutrients: readNutrients(_db, 'food_nutrients', 'food_id', id),
      parentId: row['parent_id'] as String?,
      sizeName: row['size_name']! as String,
      kind: ConsumptionKind.values.byName(
        row['consumption_kind']! as String,
      ),
      valueType: NutrientValueType.values.byName(row['value_type']! as String),
      sourceUrl: row['source_url']! as String,
      checkedAt: switch (row['checked_at'] as int?) {
        final at? => DateTime.fromMillisecondsSinceEpoch(at),
        null => null,
      },
    );
  }
}

/// The nutrients stored for one record. Only what is known has a row, so
/// what comes back is only what somebody actually wrote down.
Nutrients readNutrients(
  AppDatabase db,
  String table,
  String idColumn,
  String id,
) => {
  for (final row in db.select(
    'SELECT nutrient, amount FROM $table WHERE $idColumn = ?',
    [id],
  ))
    ?_nutrientNamed(row['nutrient']! as String): (row['amount']! as num)
        .toDouble(),
};

/// Rows written by a later version of the app can name a nutrient this
/// one does not have. Dropping them beats refusing to read the record;
/// the archive still carries them across untouched.
Nutrient? _nutrientNamed(String name) {
  for (final nutrient in Nutrient.values) {
    if (nutrient.name == name) return nutrient;
  }
  return null;
}
