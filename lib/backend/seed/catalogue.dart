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
const catalogueFiles = ['assets/catalogue/starbucks-tw.json'];

/// Reads every bundled catalogue into [foods], replacing what is there.
///
/// Meals already logged from these keep their own numbers — they were
/// copied when the meal was logged — so a correction here never rewrites
/// what somebody drank.
Future<void> loadCatalogue(FoodRepository foods) async {
  for (final path in catalogueFiles) {
    final file = jsonDecode(await rootBundle.loadString(path));
    for (final food in parseCatalogue(file as Map<String, dynamic>)) {
      foods.save(food, source: ChangeSource.catalogue);
    }
  }
}

/// The foods one catalogue file describes: a drink, then its cup sizes.
///
/// Sizes are separate foods because they are not proportional — a
/// Starbucks americano is 98 mg of caffeine in a 240 ml short and 195 mg
/// in a 350 ml tall — so each one carries its own figures.
List<FoodItem> parseCatalogue(Map<String, dynamic> file) {
  final brand = file['brand']! as String;
  // Other spellings of the brand, so 'starbucks latte' finds 星巴克's.
  final aliases = [
    for (final alias in file['brandAliases'] as List<dynamic>? ?? const [])
      alias as String,
  ].join(' ');
  final sourceUrl = file['sourceUrl']! as String;
  final checkedAt = DateTime.parse(file['checkedAt']! as String);
  final valueType = NutrientValueType.values.byName(
    file['valueType']! as String,
  );

  return [
    for (final entry in file['drinks']! as List<dynamic>)
      ...(() {
        final drink = entry as Map<String, dynamic>;
        final id = drink['id']! as String;
        final name = drink['name']! as String;
        final sizes = drink['sizes']! as List<dynamic>;

        FoodItem build({
          required String itemId,
          required String sizeName,
          required double millilitres,
          required num? caffeineMg,
          String? parentId,
        }) => FoodItem(
          id: itemId,
          name: name,
          brand: brand,
          searchTerms: aliases,
          kind: ConsumptionKind.beverage,
          sizeName: sizeName,
          parentId: parentId,
          servingAmount: millilitres,
          servingUnit: ServingUnit.millilitre,
          valueType: valueType,
          sourceUrl: sourceUrl,
          checkedAt: checkedAt,
          nutrients: {
            // A size with no published figure holds none: an absent
            // nutrient is nobody having written it down, not a zero.
            if (caffeineMg != null) Nutrient.caffeine: caffeineMg.toDouble(),
          },
        );

        final first = sizes.first as Map<String, dynamic>;
        return [
          // The drink itself takes its smallest size's figures, so
          // picking it without choosing a cup still means something.
          build(
            itemId: id,
            sizeName: '',
            millilitres: (first['millilitres']! as num).toDouble(),
            caffeineMg: first['caffeineMg'] as num?,
          ),
          for (final size in sizes)
            build(
              itemId: '$id-${(size as Map<String, dynamic>)['name']}',
              sizeName: size['name']! as String,
              millilitres: (size['millilitres']! as num).toDouble(),
              caffeineMg: size['caffeineMg'] as num?,
              parentId: id,
            ),
        ];
      })(),
  ];
}
