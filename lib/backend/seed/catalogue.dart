import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../domain/domain.dart';
import '../storage/database.dart';
import '../storage/food_repository.dart';

/// Brand drinks that ship with the app.
///
/// The figures are transcribed by hand from each brand's own published
/// page, with the URL and the date it was read kept beside them. Nothing
/// is fetched at runtime: the brands' terms of use forbid automated
/// access, and a number that quietly changes under a record is worse
/// than one that is a release behind.
///
/// These records are read-only. Loading replaces them wholesale, which
/// is only safe because nobody can have edited them.
const catalogueFiles = [
  'assets/catalogue/starbucks-tw.json',
  'assets/catalogue/7eleven-citycafe-tw.json',
  'assets/catalogue/7eleven-cityprima-tw.json',
  'assets/catalogue/7eleven-citytea-tw.json',
  'assets/catalogue/7eleven-citypearl-tw.json',
  'assets/catalogue/7eleven-reserve-tw.json',
  'assets/catalogue/7eleven-teabar-tw.json',
  'assets/catalogue/ikea-bistro-tw.json',
  'assets/catalogue/familymart-letstea-tw.json',
  'assets/catalogue/familymart-letscafe-tw.json',
  'assets/catalogue/familymart-bottled-tw.json',
];

/// Reads every bundled catalogue into [foods], replacing what is there.
///
/// Meals already logged from these keep their own numbers — they were
/// copied when the meal was logged — so a correction here never rewrites
/// what somebody drank.
Future<void> loadCatalogue(FoodRepository foods) async {
  final shipped = <String>{};
  for (final path in catalogueFiles) {
    final file = jsonDecode(await rootBundle.loadString(path));
    for (final food in parseCatalogue(file as Map<String, dynamic>)) {
      foods.save(food, source: ChangeSource.catalogue);
      shipped.add(food.id);
    }
  }
  foods.retireCatalogue(shipped);
}

/// The foods one catalogue file describes: a drink, then its cup sizes.
///
/// Sizes are separate foods because they are not proportional — a
/// Starbucks americano is 98 mg of caffeine in a 240 ml short and 195 mg
/// in a 350 ml tall — so each one carries its own figures.
///
/// A size without `millilitres` is a cup whose capacity was not
/// published (不可思議咖啡's 專用杯). A drink without `sizes` carries its
/// figures itself: an add-on such as pearls, sold by the portion.
List<FoodItem> parseCatalogue(Map<String, dynamic> file) {
  final brand = file['brand']! as String;
  final series = file['series'] as String? ?? '';
  // The country the chain's figures are published for.
  final country = (file['market']! as String).toUpperCase();
  // Other spellings of the brand, and the line's own name, so
  // 'starbucks latte' finds 星巴克's and 'city cafe' finds 7-ELEVEN's.
  final searchTerms = [
    for (final alias in file['brandAliases'] as List<dynamic>? ?? const [])
      alias as String,
    if (series.isNotEmpty) series,
  ].join(' ');
  // Chains publish their cup sizes, not what is in the cup.
  final volumeIsCup = file['volumeIs'] == 'cup';
  final sourceUrl = file['sourceUrl']! as String;
  final checkedAt = DateTime.parse(file['checkedAt']! as String);
  final valueType = NutrientValueType.values.byName(
    file['valueType']! as String,
  );
  // Figures published per 100 g beside a portion's weight, as a bakery or
  // a canteen prints them, rather than for the item as served.
  final isPer100g = file['basis'] == 'per100g';

  return [
    for (final drink
        in (file['drinks']! as List<dynamic>).cast<Map<String, dynamic>>())
      ...(() {
        final id = drink['id']! as String;
        final sizes = (drink['sizes'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();

        FoodItem build({
          required String itemId,
          required String sizeName,
          required Map<String, dynamic> figures,
          String? parentId,
        }) {
          final millilitres = figures['millilitres'] as num?;
          final grams = figures['grams'] as num?;
          final scale = isPer100g && grams != null ? grams / 100 : 1;
          double? figure(String key) => switch (figures[key]) {
            final num value => value * scale.toDouble(),
            _ => null,
          };
          return FoodItem(
            id: itemId,
            name: drink['name']! as String,
            brand: brand,
            series: series,
            country: country,
            searchTerms: searchTerms,
            isCupCapacity: volumeIsCup && millilitres != null,
            kind: ConsumptionKind.values.byName(
              drink['kind'] as String? ?? ConsumptionKind.beverage.name,
            ),
            sizeName: sizeName,
            parentId: parentId,
            servingLabel: millilitres == null
                ? (sizes.isEmpty ? '一份' : '一杯')
                : '',
            servingAmount: (millilitres ?? grams)?.toDouble() ?? 1,
            servingUnit: millilitres != null
                ? ServingUnit.millilitre
                : grams != null
                ? ServingUnit.gram
                : ServingUnit.serving,
            valueType: valueType,
            sourceUrl: drink['sourceUrl'] as String? ?? sourceUrl,
            checkedAt: checkedAt,
            kcal: _wholeKcal(figure('kcal'), valueType)?.toDouble(),
            proteinGrams: figure('proteinG'),
            carbGrams: figure('carbG'),
            fatGrams: figure('fatG'),
            // A size with no published figure holds none: an absent
            // nutrient is nobody having written it down, not a zero.
            nutrients: {
              Nutrient.saturatedFat: ?figure('saturatedFatG'),
              Nutrient.transFat: ?figure('transFatG'),
              Nutrient.sugar: ?figure('sugarG'),
              Nutrient.sodium: ?figure('sodiumMg'),
              Nutrient.caffeine: ?figure('caffeineMg'),
            },
            // Declared per item; a file that says nothing of them leaves
            // them unknown.
            allergens: switch (drink['allergens']) {
              final List<dynamic> names => {
                for (final name in names)
                  Allergen.values.byName(name as String),
              },
              _ => null,
            },
          );
        }

        return [
          // The drink itself takes its first size's figures, so picking
          // it without choosing a cup still means something.
          build(
            itemId: id,
            sizeName: '',
            figures: sizes.isEmpty ? drink : sizes.first,
          ),
          for (final size in sizes)
            build(
              itemId: '$id-${size['name']}',
              sizeName: size['name']! as String,
              figures: size,
              parentId: id,
            ),
        ];
      })(),
  ];
}

/// Energy is kept in whole kcal. A published ceiling of 15.4 rounds up,
/// so "at most 16" stays true; anything else rounds to the nearest.
int? _wholeKcal(num? kcal, NutrientValueType valueType) {
  if (kcal == null) return null;
  return valueType == NutrientValueType.max ? kcal.ceil() : kcal.round();
}
