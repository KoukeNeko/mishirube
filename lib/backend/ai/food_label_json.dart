import 'dart:convert';

import '../../domain/domain.dart';

/// What every provider is asked when reading a nutrition label's text,
/// already read off the photo on the phone, one table row per line: for
/// a provider that cannot look at the photo itself.
final foodLabelInstructions = '''
你會拿到一張食品營養標示的文字，是從照片辨識出來的，一行是表格的一列。
$labelReadingRules''';

/// What Apple's on-device model is asked when reading a label's text.
/// Its guided schema already names each country's rows in its fields'
/// descriptions and enforces the answer's shape, so the prompt keeps
/// only what no field says; the JSON other providers need spelled out
/// would not fit its small context with the schema.
final appleFoodLabelInstructions =
    '''
你會拿到一張食品營養標示的文字，是從照片辨識出來的，一行是表格的一列。照標示填每個欄位。
$labelRowRule
$labelColumnRules
$labelFigureRules
$appleEmptyFieldRule''';

/// For Apple's schema, where null is a field left empty: without it the
/// model fills an energy column the label does not print.
const appleEmptyFieldRule =
    '- 欄位留空就是 null：標示上沒有印的列（包括 kJ 與「每100」那一欄的熱量）都留空，不要填 0。';

/// Every figure stays on its row: the mistake a model makes most.
const labelRowRule =
    '- 每個數字屬於同一列左邊的那個營養素，不要照常見的順序猜。表格裡有意料之外的列（胺基酸、維生素、礦物質）時，它們各占自己的一列，後面各列的數字不會因此往上或往下移。';

/// Which column of a label is read.
const labelColumnRules = '''
- 一律用「每份」那一欄，不要用「每100公克」或「每100毫升」那一欄。只有每100一欄時，數字照填，每一份量填 100。
- 「每日參考值百分比」那一欄是百分比，不是份量，不要填進任何欄位。''';

/// How a label's figures are copied.
const labelFigureRules = '''
- 數字照標示寫，保留小數點，例如 6.7、274.4，不要四捨五入。
- 標示上有的每一列都要填，包括縮排的那幾列；標示上是 0 就填 0。標示上沒有的列（例如沒有膳食纖維那一列）填 null，不要填 0。
- 看不到或不確定的欄位填 null，不要猜。''';

/// How a nutrition label is read into JSON, whether the model gets its
/// text or the photo itself ([photoInstructions]): its layout in each
/// country, the answer's shape, and the rules that keep every figure on
/// its own row.
final labelReadingRules =
    '''
標示可能是台灣、日本、美國、歐盟、澳洲或紐西蘭、韓國、中國或加拿大的。
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
{"label_region":"TW、JP、US、EU、AU、NZ、KR、CN 或 CA","name":"品名","brand":"品牌","serving_amount":數字,"serving_unit":"g 或 ml",
"kcal":數字,"kj":數字,"kcal_per_100":數字,"protein_g":數字,"fat_g":數字,"saturated_fat_g":數字,"trans_fat_g":數字,
"carb_g":數字,"net_carb_g":數字,"sugar_g":數字,"sodium_mg":數字,"salt_g":數字,"fibre_g":數字,"caffeine_mg":數字,
"nutrients":{"calcium_mg":數字}}
各國標示的對應：
- 台灣（營養標示）：label_region 是 TW，照上面的例子。
- 日本（栄養成分表示）：label_region 是 JP。熱量（エネルギー）是 kcal，たんぱく質是 protein_g，脂質是 fat_g，炭水化物是 carb_g，糖質是 net_carb_g，食物繊維是 fibre_g，糖類是 sugar_g，食塩相当量是 salt_g（公克，不要換成鈉），ナトリウム是 sodium_mg。基準常寫成「1袋（65g）当たり」「100g当たり」：serving_amount 填括號或文字裡的重量或容量。
- 美國（Nutrition Facts）：label_region 是 US。Calories 是 kcal，Total Carbohydrate 是 carb_g（含 Dietary Fiber），Dietary Fiber 是 fibre_g，Total Sugars 是 sugar_g，Sodium 是 sodium_mg，Serving size 括號裡的公克數是 serving_amount。
- 歐盟（Nutrition declaration）：label_region 是 EU。Energy 用 kcal 那個數字，不要用 kJ。Carbohydrate 不含膳食纖維，填在 net_carb_g，carb_g 填 null。Fibre 是 fibre_g，of which sugars 是 sugar_g，of which saturates 是 saturated_fat_g，Salt 是 salt_g（公克，不要換成鈉）。
- 澳洲或紐西蘭（Nutrition Information Panel）：label_region 是 AU 或 NZ。能量常只印 kJ：印了 Cal／kcal 就填 kcal，只有 kJ 就填 kj、kcal 填 null。Carbohydrate 不含膳食纖維，填在 net_carb_g，carb_g 填 null。Dietary fibre 是 fibre_g，Sugars 是 sugar_g，Sodium 是 sodium_mg，Quantity per serving 那一欄是每份。
- 韓國（영양정보）：label_region 是 KR。열량是 kcal，단백질是 protein_g，지방是 fat_g，포화지방是 saturated_fat_g，트랜스지방是 trans_fat_g，탄수화물是 carb_g，당류是 sugar_g，나트륨是 sodium_mg（毫克），식이섬유是 fibre_g；總內容量或 1회 제공량的公克數是 serving_amount。
- 中國（营养成分表）：label_region 是 CN。能量通常只印 kJ：填 kj、kcal 填 null，不要自己換算。蛋白质是 protein_g，脂肪是 fat_g，碳水化合物是 carb_g，糖是 sugar_g，钠是 sodium_mg，膳食纤维是 fibre_g；每 100 克（毫升）那一欄只有它時 serving_amount 填 100，另有「每份」那一欄就用每份。
- 加拿大（Nutrition Facts / Valeur nutritive）：label_region 是 CA。Calories 是 kcal，Carbohydrate / Glucides 是 carb_g（含 Fibre），Fibre / Fibres 是 fibre_g，Sugars / Sucres 是 sugar_g，Sodium 是 sodium_mg。
- 看不出是哪一國的就填 null，照台灣的方式填。
規則：
$labelColumnRules
- kcal_per_100 是「每100公克／毫升」那一欄的熱量，只用來核對；沒有那一欄就填 null。
- name 是品名，brand 是包裝上的品牌或製造商（例如「統一」「義美」「明治」），不要把品牌寫進 name；看不到就填 null。
- serving_amount 是「每一份量」的數字，serving_unit 是它的單位（公克是 g，毫升是 ml）。
- 鈉的單位是毫克（mg）；如果標示寫的是公克，換成毫克。
$labelFigureRules
- 照片可能歪斜，一行文字裡的數字可能屬於上一列或下一列。照營養素的順序對齊：台灣標示每一欄由上到下依序是熱量、蛋白質、脂肪、飽和脂肪、反式脂肪、碳水化合物、糖、鈉；飽和脂肪與反式脂肪不會大於脂肪，糖不會大於碳水化合物。
- 辨識錯字要照上下文判斷，例如把字母 O 當成 0；但無法判斷就填 null。
- 上面沒有欄位的列（鈣、膽固醇、胺基酸、維生素等）照「每份」放進 nutrients，鍵只能用這些（單位在鍵名裡：g 公克、mg 毫克、ug 微克）：
  ${Nutrient.values.map(nutrientAnswerKey).join('、')}
  例如白胺酸 1571 毫克是 "leucine_mg":1571，纈胺酸是 valine_mg，異白胺酸是 isoleucine_mg。
- 胺基酸的單位是毫克；標示寫公克就換成毫克，例如支鏈胺基酸（BCAA）5.5 公克是 "bcaa_mg":5500。必需胺基酸（EAA）是 essential_amino_acids_mg，麩醯胺酸是 glutamine_mg。
- 支鏈胺基酸的總量只在標示印了總量時才填，不要自己把三項加起來。''';

/// The labels read, by where their rules come from; Australia and New
/// Zealand share one food code.
const _regions = {'TW', 'JP', 'US', 'EU', 'AU', 'NZ', 'KR', 'CN', 'CA'};

/// Figures past these are a misread, not a food.
const _limits = {
  'kcal': 2000.0,
  'kj': 8400.0,
  'kcal_per_100': 1000.0,
  'protein_g': 200.0,
  'fat_g': 200.0,
  'saturated_fat_g': 200.0,
  'trans_fat_g': 50.0,
  'carb_g': 300.0,
  'sugar_g': 300.0,
  'sodium_mg': 10000.0,
  'salt_g': 25.0,
  'net_carb_g': 300.0,
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

  final region = switch (text('label_region')?.toUpperCase()) {
    final code? when _regions.contains(code) => code,
    _ => null,
  };
  final fat = figure('fat_g');
  // 糖質, or the EU's carbohydrate: carbohydrate less its fibre.
  final netCarb = figure('net_carb_g');
  final fibreAsPrinted = figure('fibre_g');
  // The app's carbohydrate holds its fibre, as Taiwan's, Japan's and the
  // US's labels do; the EU's does not, and one without its fibre leaves
  // the whole unknown rather than short.
  final carb =
      figure('carb_g') ??
      switch ((netCarb, fibreAsPrinted)) {
        (final net?, final fibre?) => net + fibre,
        _ => null,
      };
  double? partOf(String key, double? whole) => switch (figure(key)) {
    final part? when whole == null || part <= whole => part,
    _ => null,
  };
  final serving = switch (_number(fields['serving_amount'])) {
    final value? when value > 0 && value <= 5000 => value,
    _ => null,
  };
  final unit = switch (text('serving_unit')?.toLowerCase()) {
    // l10n-ignore: the units a model may copy off a Chinese label.
    'g' || '公克' => ServingUnit.gram,
    // l10n-ignore: as above.
    'ml' || '毫升' => ServingUnit.millilitre,
    _ => null,
  };

  // A label that prints only kJ, as China's and Australia's often do:
  // one energy in another unit, 4.184 kJ to the kcal.
  final kcal =
      figure('kcal') ??
      switch (figure('kj')) {
        final kj? => (kj / 4.184 * 10).round() / 10,
        null => null,
      };
  final protein = figure('protein_g');
  final warnings = <DraftWarning>[
    if (carb == null && netCarb != null) const CarbWithoutFibre(),
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
    country: region,
    servingAmount: unit == null ? null : serving,
    servingUnit: serving == null ? null : unit,
    kcal: kcal,
    proteinGrams: protein,
    fatGrams: fat,
    carbGrams: carb,
    fibreGrams: partOf('fibre_g', carb),
    nutrients: {
      // The rows with no field of their own first, so the checked ones
      // below win where a model gave both.
      ...?switch (fields['nutrients']) {
        final Map<String, dynamic> extra => {
          for (final nutrient in Nutrient.values)
            if (extra[nutrientAnswerKey(nutrient)] case final num amount
                when amount >= 0 && amount <= 50000)
              nutrient: amount.toDouble(),
        },
        _ => null,
      },
      Nutrient.saturatedFat: ?partOf('saturated_fat_g', fat),
      Nutrient.transFat: ?partOf('trans_fat_g', fat),
      Nutrient.sugar: ?partOf('sugar_g', carb),
      Nutrient.sodium: ?figure('sodium_mg'),
      Nutrient.saltEquivalent: ?figure('salt_g'),
      Nutrient.netCarb: ?netCarb,
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
ColumnMismatch? _columnWarning(double? kcal, double? per100, double? serving) {
  if (kcal == null || per100 == null || serving == null || serving == 100) {
    return null;
  }
  final expected = per100 * serving / 100;
  final gap = (kcal - expected).abs();
  if (gap <= 5 || gap <= 0.15 * (kcal > expected ? kcal : expected)) {
    return null;
  }
  return const ColumnMismatch();
}

/// Whether the energy roughly matches the macronutrients (4 kcal a gram
/// of protein and carbohydrate, 9 of fat). Only a prompt to look: fibre,
/// sugar alcohols and rounding all move it, so the margin is wide.
EnergyMismatch? _energyWarning(
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
  return const EnergyMismatch();
}
