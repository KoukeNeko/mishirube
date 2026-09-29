import 'dart:convert';

import '../../domain/domain.dart';
import 'food_label_json.dart';

/// What every provider is asked for, in one place, so Apple's model and
/// Ollama's are given the same job. Apple's side also constrains the
/// answer to [DraftItem]'s shape; Ollama Cloud cannot, so the shape is
/// spelled out here too.
final mealDraftInstructions =
    '''
你把使用者描述的一餐拆成一項一項的食物或飲料。
只回傳 JSON，不要任何說明文字，格式：
{"name":"這一餐的名稱","items":[{"name":"品名","amount":"份量","kcal":數字,"protein_g":數字,"carb_g":數字,"fat_g":數字,"fibre_g":數字,"nutrients":{"sugar_g":數字,"sodium_mg":數字},"is_drink":false}]}
規則：
- 最外層的 name 是整餐的簡短名稱，例如「雞腿便當」「蛋餅加奶茶」，繁體中文，不超過 12 個字。
- items 裡的 name 用使用者的說法，繁體中文。
- amount 照使用者說的份量；沒說就寫「一份」。
- kcal、protein_g、carb_g、fat_g、fibre_g 是你對這個份量的估計，不確定就填 null。
$_nutrientRules
- 飲料的 is_drink 是 true。
- 使用者沒提到的東西不要加。''';

/// How every prompt asks for the nutrients beyond the five: under keys
/// that carry their unit, taken from [Nutrient] so the list is the
/// app's own.
final _nutrientRules =
    '''
- nutrients 放其他營養素，鍵只能用這些（單位在鍵名裡：g 公克、mg 毫克、ug 微克）：
  ${Nutrient.values.map(nutrientAnswerKey).join('、')}
- 使用者給了營養標示、或照片裡看得到營養標示時，標示上的每一列都要填（例如糖、鈉、飽和脂肪、鈣、白胺酸），數字照標示的「每份」，保留小數點；沒有依據就不要填，不要猜。
- 含酒精的飲料要填 alcohol_g：容量（毫升）× 酒精度 × 0.789，酒精度照使用者說的或這種酒常見的度數。''';

/// Figures past these are not a meal but a misreading: a number the
/// model wrote in the wrong unit, or invented.
const _maxKcal = 4000;
const _maxGrams = 500;

/// Reads a model's answer into a draft, or throws
/// [AiFailure.unreadable].
///
/// Tolerant of what models wrap JSON in (code fences, a sentence before
/// it), strict about what goes into the draft: a figure out of range is
/// dropped rather than kept, because a blank asks the user for a number
/// and a wrong one looks like an answer.
MealDraft parseMealDraft(
  String answer, {
  required AiProviderKind provider,
  required String model,
}) {
  final decoded = _decode(answer);
  final items = _itemsOf(decoded, answer);
  if (items.isEmpty) throw AiException(AiFailure.unreadable, answer);
  return MealDraft(
    items: items,
    provider: provider,
    model: model,
    name: switch (decoded) {
      {'name': final String name} when name.trim().isNotEmpty => name.trim(),
      _ => null,
    },
  );
}

/// What every provider that can look at a photo is asked about one. The
/// model decides what it shows: a nutrition label, read into the label's
/// JSON as [labelReadingRules] says, or food, estimated item by item into
/// the same items as [mealDraftInstructions] plus what the photo cannot
/// show. Nobody picks which beforehand.
final photoInstructions =
    '''
你會看到一張照片，可能還有使用者補充的一句話。先判斷照片拍的是什麼，只回傳 JSON，不要任何說明文字：
- 照片裡有包裝的營養標示表格（營養標示、栄養成分表示、Nutrition Facts、영양정보、营养成分表 等）時，照下面「營養標示」的方式讀表格，回傳 {"label":{…}}，label 裡照營養標示的格式。
- 其他情況（餐點、飲料、沒有營養表格的包裝）照下面「食物」的方式估計，回傳 {"items":[…],"notes":[…]}。

【營養標示】
一列一列對著表格讀：
$labelRowRule
$labelReadingRules

【食物】
辨識照片裡每一項食物或飲料，估計份量與營養，格式：
{"items":[{"name":"品名","amount":"估計份量","kcal":數字,"protein_g":數字,"carb_g":數字,"fat_g":數字,"fibre_g":數字,"nutrients":{"sugar_g":數字,"sodium_mg":數字},"is_drink":false}],"notes":["照片看不出來、但會影響數字的地方"]}
規則：
$_photoItemRules
- kcal、protein_g、carb_g、fat_g、fibre_g 是你對這個份量的估計；不確定就填 null，不要填 0。
$_nutrientRules
$_photoNoteRules
- 照片裡沒有食物、飲料或營養標示時回傳 {"items":[],"notes":[]}。''';

/// [photoInstructions] for Apple's on-device model: the same judgement
/// without the JSON, which its guided schema enforces and whose fields'
/// descriptions carry each label's rows. Spelled out, it would not fit
/// the model's context beside the schema and the photo.
final applePhotoInstructions =
    '''
你會看到一張照片，可能還有使用者補充的一句話。先判斷照片拍的是什麼：
- 照片裡有包裝的營養標示表格時，照表格填 label，items 留空。
- 其他情況（餐點、飲料、沒有營養表格的包裝）估計每一項食物填 items，label 留空。

【營養標示】
一列一列對著表格讀：
$labelRowRule
$labelColumnRules
$labelFigureRules
$appleEmptyFieldRule

【食物】
$_photoItemRules
- 熱量與營養素是你對這個份量的估計；不確定就留空，不要填 0。
$_photoNoteRules
- 照片裡沒有食物、飲料或營養標示時，items 與 notes 都是空的。''';

/// How each food in a photo is named and measured.
const _photoItemRules = '''
- name 用台灣常用的說法，繁體中文。便當、自助餐拆成看得到的每一項（白飯、雞腿、青菜），一碗滷肉飯這種一道菜就算一項。
- amount 寫估計的重量或容量與合理範圍，例如「約 180 g（150–220 g）」「約 700 ml」；看不出來就寫「一份」。
- 使用者補充的份量、糖度、冰量、品牌優先於照片的判斷。''';

/// What a photo cannot show, and what it must not count twice.
const _photoNoteRules = '''
- 看不見的油、醬汁、滷汁、糖（炒菜油、炸物吸的油、手搖飲的糖）寫在 notes，一句一件事，最多三句；不要假裝看得到。
- 同一份食物只算一次，只列照片裡看得到的東西。''';

/// Reads a model's answer about a photo ([photoInstructions]): a label
/// when it answered with one, otherwise the food it saw. Throws as
/// [parseFoodLabel] and [parseMealPhoto] do.
PhotoDraft parsePhoto(
  String answer, {
  required AiProviderKind provider,
  required String model,
}) {
  if (_decode(answer) case {'label': final Map<String, dynamic> label}) {
    return PhotoOfLabel(
      parseFoodLabel(jsonEncode(label), provider: provider, model: model),
    );
  }
  return PhotoOfFood(parseMealPhoto(answer, provider: provider, model: model));
}

/// Reads a model's answer about a food photo into a draft. Throws
/// [AiFailure.noFood] when it saw nothing to eat, and
/// [AiFailure.unreadable] when the answer is not the JSON asked for.
///
/// An item whose energy does not come near its macronutrients (4 kcal a
/// gram of protein and carbohydrate, 9 of fat) is flagged, not changed:
/// the check is a prompt to look, and the figures are the model's.
MealDraft parseMealPhoto(
  String answer, {
  required AiProviderKind provider,
  required String model,
}) {
  final decoded = _decode(answer);
  final items = _itemsOf(decoded, answer);
  if (items.isEmpty) throw AiException(AiFailure.noFood, answer);
  final notes = [
    if (decoded case {'notes': final List<dynamic> notes})
      for (final note in notes.take(3))
        if (note case final String text when text.trim().isNotEmpty)
          ModelNote(text.trim()),
  ];
  return MealDraft(
    items: items,
    provider: provider,
    model: model,
    warnings: [...notes, ...items.map(_energyWarning).nonNulls],
  );
}

Object? _decode(String answer) {
  final start = answer.indexOf('{');
  final end = answer.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw AiException(AiFailure.unreadable, answer);
  }
  try {
    return jsonDecode(answer.substring(start, end + 1));
  } on FormatException {
    throw AiException(AiFailure.unreadable, answer);
  }
}

List<DraftItem> _itemsOf(Object? decoded, String answer) {
  if (decoded is! Map<String, dynamic> || decoded['items'] is! List) {
    throw AiException(AiFailure.unreadable, answer);
  }
  return [
    for (final entry in decoded['items'] as List<dynamic>)
      if (entry case {'name': final String name} when name.trim().isNotEmpty)
        DraftItem(
          name: name.trim(),
          amount: switch (entry['amount']) {
            final String amount when amount.trim().isNotEmpty => amount.trim(),
            // Nothing said: the item is one of whatever it is.
            _ => '',
          },
          kcal: _figure(entry['kcal'], _maxKcal),
          proteinGrams: _figure(entry['protein_g'], _maxGrams),
          carbGrams: _figure(entry['carb_g'], _maxGrams),
          fatGrams: _figure(entry['fat_g'], _maxGrams),
          fibreGrams: _figure(entry['fibre_g'], _maxGrams),
          nutrients: _nutrientsOf(entry['nutrients']),
          isDrink: entry['is_drink'] == true,
        ),
  ];
}

/// Whether [item]'s energy is far from what its macronutrients add up
/// to. Wide margin: fibre, alcohol and rounding all move it.
EnergyMismatch? _energyWarning(DraftItem item) {
  final (kcal, protein, carb, fat) = (
    item.kcal,
    item.proteinGrams,
    item.carbGrams,
    item.fatGrams,
  );
  if (kcal == null || protein == null || carb == null || fat == null) {
    return null;
  }
  final estimate = 4 * protein + 4 * carb + 9 * fat;
  final gap = (kcal - estimate).abs();
  if (gap <= 30 || gap <= 0.15 * kcal) return null;
  return EnergyMismatch(item.name);
}

double? _figure(Object? value, int max) => switch (value) {
  final num number when number >= 0 && number <= max => number.toDouble(),
  _ => null,
};

/// The nutrients a model gave under their answer keys; an unknown key or
/// a figure no portion could hold is left out.
Nutrients _nutrientsOf(Object? value) {
  if (value is! Map<String, dynamic>) return const {};
  return {
    for (final nutrient in Nutrient.values)
      if (value[nutrientAnswerKey(nutrient)] case final num amount
          when amount >= 0 && amount <= _maxNutrient[nutrient.unit]!)
        nutrient: amount.toDouble(),
  };
}

/// More than a day's food could hold, by unit.
const _maxNutrient = {
  NutrientUnit.gram: 500.0,
  NutrientUnit.milligram: 50000.0,
  NutrientUnit.microgram: 50000.0,
};
