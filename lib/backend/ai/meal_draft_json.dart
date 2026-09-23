import 'dart:convert';

import '../../domain/domain.dart';

/// What every provider is asked for, in one place, so Apple's model and
/// Ollama's are given the same job. Apple's side also constrains the
/// answer to [DraftItem]'s shape; Ollama Cloud cannot, so the shape is
/// spelled out here too.
const mealDraftInstructions = '''
你把使用者描述的一餐拆成一項一項的食物或飲料。
只回傳 JSON，不要任何說明文字，格式：
{"items":[{"name":"品名","amount":"份量","kcal":整數,"protein_g":整數,"carb_g":整數,"fat_g":整數,"is_drink":false}]}
規則：
- name 用使用者的說法，繁體中文。
- amount 照使用者說的份量；沒說就寫「一份」。
- kcal、protein_g、carb_g、fat_g 是你對這個份量的估計，不確定就填 null。
- 飲料的 is_drink 是 true。
- 使用者沒提到的東西不要加。''';

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
  final items = _itemsOf(_decode(answer), answer);
  if (items.isEmpty) throw AiException(AiFailure.unreadable, answer);
  return MealDraft(items: items, provider: provider, model: model);
}

/// What every provider is asked about a food photo. It returns the same
/// items as [mealDraftInstructions], so the review and logging are the
/// same, plus what the photo cannot show.
const mealPhotoInstructions = '''
你會看到一張食物照片，可能還有使用者補充的一句話。辨識照片裡每一項食物或飲料，估計份量與營養。
只回傳 JSON，不要任何說明文字，格式：
{"items":[{"name":"品名","amount":"估計份量","kcal":整數,"protein_g":整數,"carb_g":整數,"fat_g":整數,"is_drink":false}],"notes":["照片看不出來、但會影響數字的地方"]}
規則：
- name 用台灣常用的說法，繁體中文。便當、自助餐拆成看得到的每一項（白飯、雞腿、青菜），一碗滷肉飯這種一道菜就算一項。
- amount 寫估計的重量或容量與合理範圍，例如「約 180 g（150–220 g）」「約 700 ml」；看不出來就寫「一份」。
- 使用者補充的份量、糖度、冰量、品牌優先於照片的判斷。
- kcal、protein_g、carb_g、fat_g 是你對這個份量的估計；不確定就填 null，不要填 0。
- 看不見的油、醬汁、滷汁、糖（炒菜油、炸物吸的油、手搖飲的糖）寫在 notes，一句一件事，最多三句；不要假裝看得到。
- 同一份食物只算一次，只列照片裡看得到的東西。
- 照片裡沒有食物或飲料時回傳 {"items":[],"notes":[]}。''';

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
          text.trim(),
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
            _ => '一份',
          },
          kcal: _figure(entry['kcal'], _maxKcal),
          proteinGrams: _figure(entry['protein_g'], _maxGrams),
          carbGrams: _figure(entry['carb_g'], _maxGrams),
          fatGrams: _figure(entry['fat_g'], _maxGrams),
          isDrink: entry['is_drink'] == true,
        ),
  ];
}

/// Whether [item]'s energy is far from what its macronutrients add up
/// to. Wide margin: fibre, alcohol and rounding all move it.
String? _energyWarning(DraftItem item) {
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
  return '${item.name}的${MacroLabel.energy}和${MacroLabel.protein}、'
      '${MacroLabel.carb}、${MacroLabel.fat}算起來差得多，請核對。';
}

int? _figure(Object? value, int max) => switch (value) {
  final num number when number >= 0 && number <= max => number.round(),
  _ => null,
};
