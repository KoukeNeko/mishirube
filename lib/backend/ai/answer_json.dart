import 'dart:convert';

/// The JSON a model's answer holds, or null when it holds none.
///
/// Every prompt asks for JSON alone and nothing else, and models answer
/// with a sentence before it, a code fence around it or a second object
/// after it anyway. This reads the first value whose brackets balance,
/// rather than the text between the first `{` and the last `}`, which a
/// word after the answer would break.
Object? decodeAnswer(String answer) {
  for (var start = 0; start < answer.length; start++) {
    if (answer[start] != '{' && answer[start] != '[') continue;
    final end = _endOfValue(answer, start);
    if (end < 0) continue;
    try {
      return jsonDecode(answer.substring(start, end + 1));
    } on FormatException {
      // Prose that only looks like JSON: the next bracket may be the
      // answer's own.
      continue;
    }
  }
  return null;
}

/// Where the object or array opened at [start] closes, or -1 when it
/// never does. A bracket inside a string — a name with one in it — does
/// not count.
int _endOfValue(String text, int start) {
  var depth = 0;
  var isInString = false;
  var isEscaped = false;
  for (var index = start; index < text.length; index++) {
    final char = text[index];
    if (isInString) {
      if (isEscaped) {
        isEscaped = false;
      } else if (char == r'\') {
        isEscaped = true;
      } else if (char == '"') {
        isInString = false;
      }
      continue;
    }
    switch (char) {
      case '"':
        isInString = true;
      case '{' || '[':
        depth++;
      case '}' || ']':
        depth--;
        if (depth == 0) return index;
    }
  }
  return -1;
}
