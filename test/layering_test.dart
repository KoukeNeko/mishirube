import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The layers `AGENTS.md` describes, checked rather than trusted.
///
/// A rule that lives only in a document is a rule somebody will break on
/// a Tuesday and nobody will notice until the domain imports SQLite.
void main() {
  group('layering', () {
    test('the domain knows nothing about storage, engines or screens', () {
      expect(
        _importsMatching(
          'lib/domain',
          RegExp(r"import '.*(backend|features)/"),
        ),
        isEmpty,
        reason: 'domain types hold no storage, file or network logic',
      );
    });

    test('engines take values and return values', () {
      expect(
        _importsMatching(
          'lib/backend/engines',
          RegExp(r"import '.*(storage|application|features)/"),
        ),
        isEmpty,
        reason: 'an engine that reads the database cannot be golden-tested',
      );
    });

    test('screens go through their view model, not the database', () {
      expect(
        _importsMatching('lib/features', RegExp(r"import '.*backend/storage/")),
        isEmpty,
        reason:
            'screens talk to their view model or AppStore, which talk to '
            'the services',
      );
    });

    test('shared widgets carry no feature knowledge', () {
      expect(
        _importsMatching(
          'lib/shared/widgets',
          RegExp(r"import '.*(features|backend)/"),
        ),
        isEmpty,
        reason: 'a shared widget takes plain values and callbacks',
      );
    });
  });
}

/// Every `path: import` in [directory] whose import line matches [banned].
List<String> _importsMatching(String directory, RegExp banned) => [
  for (final file in Directory(directory).listSync(recursive: true))
    if (file is File && file.path.endsWith('.dart'))
      for (final line in file.readAsLinesSync())
        if (banned.hasMatch(line)) '${file.path}: ${line.trim()}',
];
