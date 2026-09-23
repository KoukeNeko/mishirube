import 'dart:convert';

import '../../domain/domain.dart';

/// What every provider is asked when reading a nutrition label. The
/// label arrives as text already read off the photo on the phone, one
/// table row per line.
const foodLabelInstructions = '''
你會拿到一張台灣食品營養標示的文字，是從照片辨識出來的，一行是表格的一列。
台灣的營養標示長這樣（每 100 那一欄有時是「每日參考值百分比」，有時兩欄都有）：
營養標示
每一份量 30 公克
本包裝含 3 份
              每份        每100公克
熱量          150 大卡    500 大卡
蛋白質        3.2 公克    10.7 公克
脂肪          8.1 公克    27.0 公克
　飽和脂肪    3.5 公克    11.7 公克
　反式脂肪    0 公克      0 公克
碳水化合物    16.3 公克   54.3 公克
　糖          5.0 公克    16.7 公克
鈉            120 毫克    400 毫克
膳食纖維      1.2 公克    4.0 公克
飽和脂肪、反式脂肪算在脂肪裡，糖、膳食纖維算在碳水化合物裡，所以它們在下一行縮排。
「熱量」也可能寫成「能量」；「碳水化合物」可能寫成「醣類」；飲料的份量單位是毫升。
把它整理成 JSON，不要任何說明文字，數字只填數字本身、不要加單位，格式：
{"name":"品名","brand":"品牌","serving_amount":數字,"serving_unit":"g 或 ml",
"kcal":數字,"kcal_per_100":數字,"protein_g":數字,"fat_g":數字,"saturated_fat_g":數字,"trans_fat_g":數字,
"carb_g":數字,"sugar_g":數字,"sodium_mg":數字,"fibre_g":數字,"caffeine_mg":數字}
規則：
- 一律用「每份」那一欄，不要用「每100公克」或「每100毫升」那一欄。只有每100一欄時，數字照填，serving_amount 填 100。
- 「每日參考值百分比」那一欄是百分比，不是份量，不要填進任何欄位。
- kcal_per_100 是「每100公克／毫升」那一欄的熱量，只用來核對；沒有那一欄就填 null。
- serving_amount 是「每一份量」的數字，serving_unit 是它的單位（公克是 g，毫升是 ml）。
- 鈉的單位是毫克（mg）；如果標示寫的是公克，換成毫克。
- 標示上有的每一列都要填，包括縮排的那幾列；標示上是 0 就填 0。
- 看不到或不確定的欄位填 null，不要猜。
- 辨識錯字要照上下文判斷，例如把字母 O 當成 0；但無法判斷就填 null。''';

/// Figures past these are a misread, not a food.
const _limits = {
  'kcal': 2000.0,
  'kcal_per_100': 1000.0,
  'protein_g': 200.0,
  'fat_g': 200.0,
  'saturated_fat_g': 200.0,
  'trans_fat_g': 50.0,
  'carb_g': 300.0,
  'sugar_g': 300.0,
  'sodium_mg': 10000.0,
  'fibre_g': 100.0,
  'caffeine_mg': 1000.0,
};

/// Reads a model's answer into a label draft, or throws
/// [AiFailure.unreadable].
///
/// A figure out of range, or one that cannot be what the label says —
/// saturated fat above total fat, sugar above carbohydrate — is dropped:
/// a blank asks the user to look, a wrong number looks like an answer.
FoodLabelDraft parseFoodLabel(
  String answer, {
  required AiProviderKind provider,
  required String model,
}) {
  final start = answer.indexOf('{');
  final end = answer.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw AiException(AiFailure.unreadable, answer);
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(answer.substring(start, end + 1));
  } on FormatException {
    throw AiException(AiFailure.unreadable, answer);
  }
  if (decoded is! Map<String, dynamic>) {
    throw AiException(AiFailure.unreadable, answer);
  }
  final fields = decoded;

  double? figure(String key) => switch (_number(fields[key])) {
    final value? when value >= 0 && value <= _limits[key]! => value,
    _ => null,
  };
  String? text(String key) => switch (fields[key]) {
    final String value when value.trim().isNotEmpty => value.trim(),
    _ => null,
  };

  final fat = figure('fat_g');
  final carb = figure('carb_g');
  double? partOf(String key, double? whole) => switch (figure(key)) {
    final part? when whole == null || part <= whole => part,
    _ => null,
  };
  final serving = switch (_number(fields['serving_amount'])) {
    final value? when value > 0 && value <= 5000 => value,
    _ => null,
  };
  final unit = switch (text('serving_unit')?.toLowerCase()) {
    'g' || '公克' => ServingUnit.gram,
    'ml' || '毫升' => ServingUnit.millilitre,
    _ => null,
  };

  final kcal = figure('kcal');
  final protein = figure('protein_g');
  final warnings = [
    ?_columnWarning(
      kcal,
      figure('kcal_per_100'),
      unit == null ? null : serving,
    ),
    ?_energyWarning(kcal, protein, carb, fat),
  ];

  final draft = FoodLabelDraft(
    provider: provider,
    model: model,
    name: text('name'),
    brand: text('brand'),
    servingAmount: unit == null ? null : serving,
    servingUnit: serving == null ? null : unit,
    kcal: kcal?.round(),
    proteinGrams: protein?.round(),
    fatGrams: fat?.round(),
    carbGrams: carb?.round(),
    fibreGrams: partOf('fibre_g', carb)?.round(),
    nutrients: {
      Nutrient.saturatedFat: ?partOf('saturated_fat_g', fat),
      Nutrient.transFat: ?partOf('trans_fat_g', fat),
      Nutrient.sugar: ?partOf('sugar_g', carb),
      Nutrient.sodium: ?figure('sodium_mg'),
      Nutrient.caffeine: ?figure('caffeine_mg'),
    },
    warnings: warnings,
  );
  if (draft.isEmpty) throw AiException(AiFailure.unreadable, answer);
  return draft;
}

/// A figure as a model sends it: usually a number, sometimes the text
/// off the label with its unit still on (`"3.2"`, `"1,200毫克"`).
double? _number(Object? value) => switch (value) {
  final num number => number.toDouble(),
  final String text => double.tryParse(
    RegExp(r'^\s*(\d+(\.\d+)?)')
            .firstMatch(text.replaceAll(',', ''))
            ?.group(1) ??
        '',
  ),
  _ => null,
};

/// Whether the per-serving figures might come from the per-100 column.
///
/// The two columns are tied by the serving size: 30 g of something with
/// 400 kcal per 100 g is 120 kcal a serving. Every digit can be read
/// right and the columns still swapped, and this is the check that
/// catches it. Labels round, so a sixth either way is allowed.
String? _columnWarning(double? kcal, double? per100, double? serving) {
  if (kcal == null || per100 == null || serving == null || serving == 100) {
    return null;
  }
  final expected = per100 * serving / 100;
  final gap = (kcal - expected).abs();
  if (gap <= 5 || gap <= 0.15 * (kcal > expected ? kcal : expected)) {
    return null;
  }
  return '每份的熱量和每 100 的熱量依份量換算對不上，可能填到另一欄，請核對。';
}

/// Whether the energy roughly matches the macronutrients (4 kcal a gram
/// of protein and carbohydrate, 9 of fat). Only a prompt to look: fibre,
/// sugar alcohols and rounding all move it, so the margin is wide.
String? _energyWarning(
  double? kcal,
  double? protein,
  double? carb,
  double? fat,
) {
  if (kcal == null || protein == null || carb == null || fat == null) {
    return null;
  }
  final estimate = 4 * protein + 4 * carb + 9 * fat;
  final gap = (kcal - estimate).abs();
  if (gap <= 10 || gap <= 0.15 * kcal) return null;
  return '${MacroLabel.energy}和${MacroLabel.protein}、${MacroLabel.carb}、'
      '${MacroLabel.fat}算起來差得多，請核對這幾格。';
}
