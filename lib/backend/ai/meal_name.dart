import 'dart:convert';

/// The longest name a merged meal is given, in characters.
const mealNameMaxLength = 16;

/// What every provider is asked when a merged meal needs a name. Plain
/// text rather than JSON: the answer is the name itself.
String mealNameInstructions(String language) =>
    '''
替一餐取一個簡短的名稱，例如「牛丼套餐」。
只回答名稱本身：不超過 $mealNameMaxLength 個字，不加引號、標點或說明。
用$language。''';

final _quotes = RegExp('["\'“”‘’「」『』]');

/// A model's answer as a name: the first line, without quotes, cut to
/// [mealNameMaxLength]. Empty when there is nothing usable. A model held
/// to JSON (Gemini's chat is) may wrap it as `{"name": "…"}`; its first
/// text value is taken.
String cleanMealName(String answer) {
  var text = answer.trim();
  if (text.startsWith('{')) {
    try {
      if (jsonDecode(text) case final Map<String, Object?> object) {
        text = object.values.whereType<String>().firstOrNull ?? '';
      }
    } on FormatException {
      // Not JSON after all: read as text.
    }
  }
  final line = text.split('\n').first.replaceAll(_quotes, '').trim();
  return String.fromCharCodes(line.runes.take(mealNameMaxLength)).trim();
}
