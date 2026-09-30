import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/engines/food_portion.dart';
import 'package:mishirube/backend/seed/packaged_foods.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/nutrition/food_search_screen.dart';

import '../support/harness.dart';

Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  late Backend backend;
  late PackagedFoods bundled;

  setUpAll(() {
    bundled = PackagedFoods.parse([
      for (final path in packagedFoodFiles) _read(path),
    ]);
  });

  setUp(() {
    backend = Backend.inMemory(clock: FakeClock().now)
      ..nutrition.packagedFoods = bundled;
  });

  tearDown(() => backend.db.close());

  group('packaged food files', () {
    test('each one names its source, licence and attribution', () {
      for (final path in packagedFoodFiles) {
        final file = _read(path);
        expect(file['licence'], isNotEmpty, reason: path);
        expect(file['attribution'], isNotEmpty, reason: path);
        expect(file['sourceUrl'], startsWith('https://'), reason: path);
        expect(file['market'], 'tw', reason: path);
        expect(DateTime.tryParse(file['checkedAt'] as String), isNotNull);
      }
    });

    test('every product is a complete, consistent label', () {
      final ids = <String>{};
      final barcodes = <String>{};
      for (final path in packagedFoodFiles) {
        final file = _read(path);
        final foods = PackagedFoods.parse([file]);
        final rows = file['foods'] as List<dynamic>;
        expect(rows, isNotEmpty, reason: path);
        for (final row in rows) {
          final food = foods.byId((row as List<dynamic>).first as String)!;
          expect(ids.add(food.id), isTrue, reason: 'duplicate id ${food.id}');
          if (food.barcode case final barcode?) {
            expect(barcodes.add(barcode), isTrue, reason: 'duplicate $barcode');
          }
          expect(food.name, isNotEmpty, reason: food.id);
          if (food.barcode == null) expect(food.brand, isNotEmpty);
          expect(food.country, 'TW');
          expect(food.valueType, NutrientValueType.declared);
          expect(food.sourceUrl, startsWith('https://'));
          final amount = food.servingAmount;
          expect(amount, inInclusiveRange(1, 2000), reason: food.id);
          final kcal = food.kcal!, protein = food.proteinGrams!;
          final fat = food.fatGrams!, carb = food.carbGrams!;
          final sodium = food.nutrients[Nutrient.sodium]!;
          expect(protein + fat + carb, lessThanOrEqualTo(amount * 1.02 + 0.5));
          expect(sodium, lessThanOrEqualTo(amount * 400 * 1.02 + 5));
          final calculated = 4 * protein + 4 * carb + 9 * fat;
          expect(kcal, greaterThanOrEqualTo(0.75 * calculated - 10));
          expect(kcal, lessThanOrEqualTo(1.3 * calculated + 10));
        }
      }
    });

    test('the bundled assets load as the app reads them', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final loaded = await PackagedFoods.load();
      expect(loaded.length, bundled.length);
    });
  });

  group('reading a file', () {
    test('a row becomes a food with only the figures it has', () {
      final foods = PackagedFoods.parse([
        {
          'market': 'tw',
          'checkedAt': '2026-10-01',
          'sourceUrl': 'https://example.test/',
          'productUrl': 'https://example.test/product/{barcode}',
          'columns': [
            'id', 'brand', 'name', 'amount', 'unit', 'kcal', 'proteinG', //
            'fatG', 'carbG', 'sugarG', 'sodiumMg', 'beverage', 'barcode',
          ],
          'foods': [
            [
              'a',
              '某公司',
              '無糖茶',
              600,
              'ml',
              0,
              0,
              0,
              0,
              null,
              20,
              1,
              '4710000000005',
            ],
            ['b', '某公司', '麻油', 10, 'ml', 83, 0, 9.2, 0, 0, 0, 0, null],
          ],
        },
      ]);

      final tea = foods.byId('a')!;
      expect(tea.servingUnit, ServingUnit.millilitre);
      expect(tea.kind, ConsumptionKind.beverage);
      expect(tea.sourceUrl, 'https://example.test/product/4710000000005');
      expect(tea.barcode, '4710000000005');
      expect(tea.nutrients, {Nutrient.sodium: 20});

      final oil = foods.byId('b')!;
      expect(oil.kind, ConsumptionKind.food, reason: 'poured, not drunk');
      expect(oil.barcode, isNull);
      expect(oil.sourceUrl, 'https://example.test/');
      expect(oil.nutrients[Nutrient.sugar], 0);
      expect(oil.nutrients, isNot(contains(Nutrient.saturatedFat)));
    });
  });

  group('searching', () {
    // A product printed on the bundled Taiwan FDA file: 新東陽 pineapple
    // cakes, 25 g a piece, 110 kcal.
    const knownId = 'tfda-0b70e32ad5';
    List<FoodItem> search(String query, {bool packaged = true}) =>
        backend.nutrition.searchFoods(query, includePackaged: packaged);

    test('a known product is found by its name and by its maker', () {
      for (final query in ['新東陽鳳梨酥25G', '鳳梨酥 新東陽 盒裝']) {
        final found = search(query).where((food) => food.id == knownId);
        expect(found, hasLength(1), reason: query);
        expect(found.single.brand, '新東陽股份有限公司');
        expect(found.single.kcal, 110);
        expect(found.single.servingAmount, 25);
      }
    });

    test('they are offered only when asked for', () {
      expect(search('新東陽鳳梨酥', packaged: false), isEmpty);
      expect(search('', packaged: true), isEmpty, reason: 'nothing typed');
    });

    test('one search offers a bounded number of them', () {
      expect(search('茶'), hasLength(packagedResultLimit));
    });

    test('logging one saves it as a food, found once and eaten recently', () {
      final food = search('新東陽鳳梨酥25G').firstWhere((f) => f.id == knownId);
      expect(backend.nutrition.isUnsavedPackagedFood(knownId), isTrue);

      final meal = backend.nutrition.logPortion(FoodPortion(food, 2));

      expect(meal.foodId, knownId);
      expect(meal.kcal, 220);
      expect(backend.nutrition.isUnsavedPackagedFood(knownId), isFalse);
      expect(backend.nutrition.foods().map((f) => f.id), [knownId]);
      expect(backend.nutrition.recentFoods().single.food.id, knownId);
      expect(
        search('新東陽鳳梨酥25G').where((f) => f.id == knownId),
        hasLength(1),
        reason: 'the saved copy replaces the packaged one',
      );
    });

    test('starring one saves it too', () {
      backend.nutrition.setFoodFavorite(knownId, isFavorite: true);

      expect(backend.nutrition.favoriteFoods().single.id, knownId);
    });

    test('a saved copy is the user\'s own once they delete it', () {
      final food = search('新東陽鳳梨酥25G').firstWhere((f) => f.id == knownId);
      backend.nutrition.logPortion(FoodPortion(food, 1));
      backend.nutrition.deleteFood(knownId);

      expect(
        search('新東陽鳳梨酥25G').where((f) => f.id == knownId),
        hasLength(1),
        reason: 'the shipped product is still there to be chosen again',
      );
    });
  });

  testWidgets('the food search screen lists a packaged product', (
    tester,
  ) async {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true)
      ..backend.nutrition.packagedFoods = bundled;
    await pumpScreen(tester, const FoodSearchScreen(), store: store);

    await tester.enterText(find.byType(TextField), '新東陽鳳梨酥25G');
    await tester.pumpAndSettle();

    expect(find.textContaining('新東陽鳳梨酥25G*8入-盒裝'), findsOneWidget);
    await disposeTree(tester);
  });
}
