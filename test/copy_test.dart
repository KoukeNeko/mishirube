import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The UI copy rules in AGENTS.md that a scanner can hold: labels and
/// states do not talk to the reader. The rest (where an explanation may
/// stand, privacy said once) needs a reviewer; this catches the drift
/// that comes back first.
void main() {
  test('user-facing strings do not address the reader or say 還沒', () {
    final offenders = <String>[];
    for (final file in _userFacingFiles()) {
      final lines = file.readAsLinesSync();
      for (final (index, line) in lines.indexed) {
        if (line.trimLeft().startsWith('//')) continue;
        for (final match in _literal.allMatches(line)) {
          if (_banned.hasMatch(match.group(0)!)) {
            offenders.add('${file.path}:${index + 1}: ${match.group(0)}');
          }
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'write a noun or a short state instead: 未設定, 沒有紀錄, 已暫停. '
          'See 「UI copy」 in AGENTS.md.',
    );
  });
}

final _literal = RegExp(r"'[^'\n]*'");
final _banned = RegExp('你|還沒');

/// Everything under lib/ except the AI prompts, which are written to a
/// model rather than to the user, and the seed's demo content.
Iterable<File> _userFacingFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'))
    .where(
      (file) =>
          !file.path.startsWith('lib/backend/ai/') &&
          !file.path.startsWith('lib/backend/seed/'),
    );
