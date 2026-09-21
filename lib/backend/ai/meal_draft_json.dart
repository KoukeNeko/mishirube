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
  final items = [
    if (decoded case {'items': final List<dynamic> list})
      for (final entry in list)
        if (entry case {'name': final String name} when name.trim().isNotEmpty)
          DraftItem(
            name: name.trim(),
            amount: switch (entry['amount']) {
              final String amount when amount.trim().isNotEmpty =>
                amount.trim(),
              _ => '一份',
            },
            kcal: _figure(entry['kcal'], _maxKcal),
            proteinGrams: _figure(entry['protein_g'], _maxGrams),
            carbGrams: _figure(entry['carb_g'], _maxGrams),
            fatGrams: _figure(entry['fat_g'], _maxGrams),
            isDrink: entry['is_drink'] == true,
          ),
  ];
  if (items.isEmpty) throw AiException(AiFailure.unreadable, answer);
  return MealDraft(items: items, provider: provider, model: model);
}

int? _figure(Object? value, int max) => switch (value) {
  final num number when number >= 0 && number <= max => number.round(),
  _ => null,
};
