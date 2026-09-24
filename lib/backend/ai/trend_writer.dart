/// A model that puts figures already worked out into a few sentences.
/// It is given the facts as lines of text and adds no figure of its own:
/// [keepsToFacts] throws away an answer that does.
abstract interface class TrendWriter {
  Future<String> summarizeTrends(String facts);
}

/// How the model is asked. The figures are the engine's; the model only
/// words them.
const trendSummaryInstructions =
    '以下每一行是健身紀錄 App 已經算好的趨勢事實。'
    '用繁體中文（台灣用語）寫兩到三句摘要，挑最重要的事實。'
    '只能使用事實裡出現的數字，不要計算新的數字，不要推測原因，'
    '不要給建議或醫療判斷，不要稱呼讀者，不要用「你」。';

final _number = RegExp(r'\d+(?:[.:]\d+)?');

/// Whether every number in [answer] appears in [facts], and it does not
/// address the reader: anything else is the model adding to the record.
bool keepsToFacts(String answer, List<String> facts) {
  String plain(String text) => text.replaceAll(',', '');
  final given = {
    for (final fact in facts)
      for (final match in _number.allMatches(plain(fact))) match.group(0),
  };
  return answer.trim().isNotEmpty &&
      !answer.contains('你') &&
      _number
          .allMatches(plain(answer))
          .every((m) => given.contains(m.group(0)));
}
