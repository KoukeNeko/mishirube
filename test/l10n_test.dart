import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Words on screen come from the ARB files, in every language the app
/// ships. A Chinese literal left in code is a string an English, Japanese
/// or Korean reader sees untranslated; a message missing from one ARB
/// falls back to another language without a word.
void main() {
  test('code outside lib/l10n writes no words of its own', () {
    final offenders = <String>[];
    for (final file in _codeFiles()) {
      var isIgnoring = false;
      String? previous;
      for (final (index, line) in file.readAsLinesSync().indexed) {
        if (line.contains('l10n-ignore-start')) isIgnoring = true;
        if (line.contains('l10n-ignore-end')) isIgnoring = false;
        final isExempt =
            isIgnoring || (previous?.contains('l10n-ignore') ?? false);
        previous = line;
        if (isExempt) continue;
        final code = line.replaceFirst(RegExp('//.*'), '');
        if (_cjk.hasMatch(code)) {
          offenders.add('${file.path}:${index + 1}: ${line.trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'move the words into lib/l10n/app_zh.arb and its translations; '
          'data that is not shown as words (stored markers, parser '
          'vocabulary, citations) goes under a `// l10n-ignore:` comment.',
    );
  });

  test('every ARB file has every message, filling in only its values', () {
    final template = _arb('zh');
    final keys = template.keys.where((key) => !key.startsWith('@')).toSet();
    for (final locale in _translations) {
      final arb = _arb(locale);
      final messages = arb.keys.where((key) => !key.startsWith('@')).toSet();
      expect(
        keys.difference(messages),
        isEmpty,
        reason: 'app_$locale.arb is missing these',
      );
      expect(
        messages.difference(keys),
        isEmpty,
        reason: 'app_$locale.arb has these the template does not',
      );
      // A translation may leave a value out (`1 year` needs no count),
      // never bring one of its own.
      for (final key in keys) {
        expect(
          _placeholders(template[key] as String),
          containsAll(_placeholders(arb[key] as String)),
          reason: 'app_$locale.arb: $key',
        );
      }
    }
  });
}

/// Han, kana and Hangul: the scripts of the languages the app writes in
/// other than English.
final _cjk = RegExp('[一-鿿぀-ヿ가-힯]');

const _translations = ['zh_Hans', 'en', 'ja', 'ko'];

/// Everything under lib/ except what is not shown as words: the ARB
/// files and their generated code, the AI prompts, which are written to
/// a model, the seed's demo content, and the released schema steps.
Iterable<File> _codeFiles() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where(
          (file) =>
              !file.path.startsWith('lib/l10n/app_localizations') &&
              !file.path.startsWith('lib/backend/ai/') &&
              !file.path.startsWith('lib/backend/seed/') &&
              file.path != 'lib/backend/storage/schema.dart',
        );

Map<String, dynamic> _arb(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

/// The `{name}`s a message fills in, whatever the plural and select
/// syntax around them.
Set<String> _placeholders(String message) => {
  for (final match in RegExp(r'\{(\w+)[,}]').allMatches(message))
    match.group(1)!,
};
