import 'dart:convert';

import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/services.dart' show rootBundle;

import '../../domain/domain.dart';
import '../engines/exercise_search.dart' show normalizeTerm;
import '../engines/food_search.dart';

/// Packaged foods sold in Taiwan and Japan, read from their labels.
///
/// Built by `tool/build_packaged_foods.py`; the sources, their licences
/// and what was left out are in `research/76-taiwan-food-labels.md` and
/// `research/83-japan-food-labels.md`.
/// Each file is one source, kept apart from the others so its licence
/// stays with it.
const packagedFoodFiles = [
  'assets/packaged/tfda-tw.json',
  'assets/packaged/openfoodfacts-tw.json',
  'assets/packaged/openfoodfacts-jp.json',
];

/// How many packaged foods one search offers: the list draws every row
/// it is given, and a word like 茶 matches thousands.
const packagedResultLimit = 50;

/// The bundled packaged foods, searched in memory.
///
/// They are not stored as foods: tens of thousands of rows would be
/// read by every food query, exported with every backup and listed as
/// brands. A packaged food becomes a saved food only when the user
/// logs or stars it (`NutritionService`), and from then on it is an
/// ordinary food of theirs.
class PackagedFoods {
  PackagedFoods._(this._entries)
    : _byId = {for (final entry in _entries) entry.id: entry};

  static final empty = PackagedFoods._(const []);

  /// Reads [files], each as `tool/build_packaged_foods.py` writes it.
  factory PackagedFoods.parse(Iterable<Map<String, dynamic>> files) {
    final entries = <_Entry>[];
    for (final file in files) {
      final source = _Source(file);
      for (final row
          in (file['foods']! as List<dynamic>).cast<List<dynamic>>()) {
        entries.add(_Entry(source, row));
      }
    }
    return PackagedFoods._(entries);
  }

  /// Reads the bundled [packagedFoodFiles].
  static Future<PackagedFoods> load() async => PackagedFoods.parse([
    for (final path in packagedFoodFiles)
      jsonDecode(await rootBundle.loadString(path)) as Map<String, dynamic>,
  ]);

  final List<_Entry> _entries;
  final Map<String, _Entry> _byId;

  int get length => _entries.length;

  bool contains(String id) => _byId.containsKey(id);

  FoodItem? byId(String id) => _byId[id]?.food;

  /// The foods [words] find, best first, at most [limit]. [words] are
  /// normalised as `foodMatchTier` expects; [except] are ids to leave
  /// out, such as those the user already saved.
  List<FoodItem> search(
    List<String> words, {
    Set<String> except = const {},
    int limit = packagedResultLimit,
  }) {
    final found = <(int, _Entry)>[];
    for (final entry in _entries) {
      if (foodMatchTier(words, entry.name, entry.elsewhere) case final tier?) {
        if (!except.contains(entry.id)) found.add((tier, entry));
      }
    }
    found.sort((a, b) {
      if (a.$1 != b.$1) return a.$1.compareTo(b.$1);
      return a.$2.title.compareTo(b.$2.title);
    });
    return [for (final (_, entry) in found.take(limit)) entry.food];
  }
}

/// What one file says of all its rows.
class _Source {
  _Source(Map<String, dynamic> file)
    : columns = {
        for (final (index, name) in (file['columns']! as List<dynamic>).indexed)
          name as String: index,
      },
      country = (file['market']! as String).toUpperCase(),
      sourceUrl = file['sourceUrl']! as String,
      productUrl = file['productUrl'] as String?,
      checkedAt = DateTime.parse(file['checkedAt']! as String);

  final Map<String, int> columns;
  final String country;
  final String sourceUrl;

  /// Where one product is listed, with `{barcode}` for its barcode;
  /// null when the source has no page per product.
  final String? productUrl;
  final DateTime checkedAt;
}

class _Entry {
  _Entry(this.source, this.row)
    : id = row[source.columns['id']!] as String,
      title = row[source.columns['name']!] as String,
      name = normalizeTerm(row[source.columns['name']!] as String),
      elsewhere = normalizeTerm(row[source.columns['brand']!] as String);

  final _Source source;
  final List<dynamic> row;
  final String id;

  /// As printed, for ordering.
  final String title;

  /// Normalised, for matching.
  final String name;
  final String elsewhere;

  /// A column's number; null when the file has no such column or the row
  /// leaves it empty, which is not a zero.
  double? _figure(String column) => switch (source.columns[column]) {
    final index? => (row[index] as num?)?.toDouble(),
    null => null,
  };

  FoodItem get food {
    final barcodeColumn = source.columns['barcode'];
    final barcode = barcodeColumn == null
        ? null
        : row[barcodeColumn] as String?;
    final isMillilitres = row[source.columns['unit']!] == 'ml';
    return FoodItem(
      id: id,
      name: title,
      brand: row[source.columns['brand']!] as String,
      country: source.country,
      servingAmount: _figure('amount')!,
      servingUnit: isMillilitres ? ServingUnit.millilitre : ServingUnit.gram,
      kind: _figure('beverage') == 1
          ? ConsumptionKind.beverage
          : ConsumptionKind.food,
      valueType: NutrientValueType.declared,
      sourceUrl: switch ((source.productUrl, barcode)) {
        (final url?, final code?) => url.replaceFirst('{barcode}', code),
        _ => source.sourceUrl,
      },
      checkedAt: source.checkedAt,
      kcal: _figure('kcal'),
      proteinGrams: _figure('proteinG'),
      carbGrams: _figure('carbG'),
      fatGrams: _figure('fatG'),
      nutrients: {
        Nutrient.saturatedFat: ?_figure('saturatedFatG'),
        Nutrient.transFat: ?_figure('transFatG'),
        Nutrient.sugar: ?_figure('sugarG'),
        Nutrient.sodium: ?_figure('sodiumMg'),
      },
      barcode: barcode,
    );
  }
}

/// Puts the notices the data's licences ask for on the open-source
/// licences page.
void registerPackagedFoodLicences() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      ['衛生福利部食品藥物管理署 食品追溯追蹤系統消費者查詢資料集'],
      '資料來源：衛生福利部食品藥物管理署「食品追溯追蹤系統消費者查詢資料集」'
      '（https://data.gov.tw/dataset/33575）。\n'
      '依政府資料開放授權條款－第1版（https://data.gov.tw/license）使用；'
      '營養標示由各廠商自行登錄，本應用程式已剔除數值互相矛盾的品項。',
    );
    yield const LicenseEntryWithLineBreaks(
      ['Open Food Facts'],
      'Contains information from Open Food Facts (https://world.openfoodfacts.org/), '
      'which is made available under the Open Database License 1.0 '
      '(https://opendatacommons.org/licenses/odbl/1-0/). Individual contents '
      'are under the Database Contents License 1.0 '
      '(https://opendatacommons.org/licenses/dbcl/1-0/).\n\n'
      'The data ships as assets/packaged/openfoodfacts-tw.json and '
      'assets/packaged/openfoodfacts-jp.json, machine-readable copies that '
      'remain under the ODbL. Products whose '
      'figures contradict one another were left out.',
    );
  });
}
