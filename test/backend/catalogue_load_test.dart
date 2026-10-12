import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/seed/catalogue.dart';
import 'package:mishirube/backend/storage/database.dart';
import 'package:mishirube/backend/storage/food_repository.dart';
import 'package:mishirube/backend/storage/schema.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:sqlite3/sqlite3.dart' show ResultSet, sqlite3;

/// Saves the first [allowed] foods, then fails: a launch cut short.
class _FailsAfter extends FoodRepository {
  _FailsAfter(super.db, this.allowed);

  final int allowed;
  var _saved = 0;

  @override
  void save(FoodItem food, {ChangeSource source = ChangeSource.local}) {
    if (_saved++ >= allowed) throw StateError('cut short');
    super.save(food, source: source);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the bundled catalogue is read when its files change', () {
    late Backend backend;
    setUp(() => backend = Backend.inMemory());
    tearDown(() => backend.close());

    int count(String sql) => backend.db.select(sql).first['n'] as int;
    int foodAudits() => count(
      "SELECT COUNT(*) AS n FROM audit_events WHERE entity_type = 'food'",
    );
    int revisions() => count('SELECT SUM(revision) AS n FROM foods');
    Future<void> load() => loadCatalogue(backend.db, backend.storage.foods);

    /// What the files and the schema are now, worked out apart from the
    /// loader: the setting is stored data, so its form is pinned.
    Future<String> hashOfFiles() async {
      final texts = [
        for (final path in catalogueFiles) await rootBundle.loadString(path),
      ];
      return sha256.convert(utf8.encode(texts.join('\n'))).toString();
    }

    test('a launch with the files it already read writes nothing', () async {
      await load();
      final audited = foodAudits();
      final revised = revisions();
      expect(audited, greaterThan(1000), reason: 'the first launch reads it');
      expect(
        backend.db.setting('foods.catalogue'),
        '$latestSchemaVersion:${await hashOfFiles()}',
        reason: 'every file and the schema version are what it was read from',
      );

      await load();

      expect(foodAudits(), audited);
      expect(revisions(), revised);
    });

    for (final (name, stale) in [
      ('an older app', () async => 'an older fingerprint'),
      (
        'an older schema, the same files',
        () async => '${latestSchemaVersion - 1}:${await hashOfFiles()}',
      ),
      (
        'other files, the same schema',
        () async => '$latestSchemaVersion:other files',
      ),
    ]) {
      test('what $name read is read again, once', () async {
        await load();
        final audited = foodAudits();
        backend.db.setSetting('foods.catalogue', await stale());

        await load();
        final reread = foodAudits();
        expect(reread, greaterThan(audited));

        await load();
        expect(foodAudits(), reread, reason: 'marked as read again');
      });
    }

    test(
      'a food no longer shipped goes, and a shipped one comes back',
      () async {
        await load();
        final foods = backend.storage.foods;
        final shipped = foods.all().first;
        foods.save(
          shipped.copyWith(id: 'no-longer-shipped', name: '下架的飲料'),
          source: ChangeSource.catalogue,
        );
        backend.db.execute('UPDATE foods SET deleted_at = 1 WHERE id = ?', [
          shipped.id,
        ]);
        backend.db.setSetting('foods.catalogue', 'an older fingerprint');

        await load();

        bool isGone(String id) =>
            backend.db.select('SELECT deleted_at FROM foods WHERE id = ?', [
              id,
            ]).first['deleted_at'] !=
            null;
        expect(isGone('no-longer-shipped'), isTrue);
        expect(isGone(shipped.id), isFalse);
      },
    );

    test('a launch cut short leaves the catalogue unread', () async {
      await expectLater(
        loadCatalogue(backend.db, _FailsAfter(backend.db, 5)),
        throwsStateError,
      );

      expect(count('SELECT COUNT(*) AS n FROM foods'), 0);
      expect(backend.db.setting('foods.catalogue'), isNull);

      await load();
      expect(count('SELECT COUNT(*) AS n FROM foods'), greaterThan(1000));
    });
  });

  group('the audit rows of every launch rewriting the built-in foods', () {
    // The step that compacts them; released steps keep their place.
    const compaction = 5;

    late Directory directory;
    setUp(() => directory = Directory.systemTemp.createTempSync('audit'));
    tearDown(() => directory.deleteSync(recursive: true));

    /// A store as the step before [compaction] left it.
    String storeBefore(void Function(int Function(List<Object?>) audit) fill) {
      final path = '${directory.path}/store.sqlite3';
      final old = sqlite3.open(path);
      for (var step = 0; step < compaction; step++) {
        old.execute(schemaSteps[step]);
      }
      old.userVersion = compaction;
      fill((row) {
        old.execute(
          'INSERT INTO audit_events '
          '(occurred_at, entity_type, entity_id, action, source) '
          'VALUES (0, ?, ?, ?, ?)',
          row,
        );
        return old.lastInsertRowId;
      });
      old.close();
      return path;
    }

    test('only the last edit of each built-in food is kept', () {
      late List<int> editsOfAAndB;
      final path = storeBefore((audit) {
        int add(String type, String id, String action, String source) =>
            audit([type, id, action, source]);
        add('food', 'a', 'create', 'catalogue');
        editsOfAAndB = [
          for (var launch = 0; launch < 3; launch++) ...[
            add('food', 'a', 'edit', 'catalogue'),
            add('food', 'b', 'edit', 'catalogue'),
          ],
        ];
        add('food', 'mine', 'edit', 'local');
        add('food', 'a', 'delete', 'catalogue');
        add('meal', 'a', 'edit', 'catalogue');
      });

      final db = AppDatabase.open(path);
      addTearDown(db.close);
      final kept = [
        for (final row in db.select(
          'SELECT id, entity_type, entity_id, action, source '
          'FROM audit_events',
        ))
          (
            '${row['entity_type']} ${row['entity_id']} ${row['action']} '
                '${row['source']}',
            row['id'] as int,
          ),
      ];

      expect(
        [for (final (name, _) in kept) name],
        unorderedEquals([
          'food a create catalogue',
          'food a edit catalogue',
          'food b edit catalogue',
          'food mine edit local',
          'food a delete catalogue',
          'meal a edit catalogue',
        ]),
      );
      expect(
        kept.firstWhere((row) => row.$1 == 'food a edit catalogue').$2,
        editsOfAAndB[4],
        reason: 'the one kept is the last',
      );
      expect(
        kept.firstWhere((row) => row.$1 == 'food b edit catalogue').$2,
        editsOfAAndB[5],
      );
    });

    test('the table keeps its shape, and new rows follow', () {
      late int last;
      final path = storeBefore((audit) {
        for (var launch = 0; launch < 3; launch++) {
          last = audit(['food', 'a', 'edit', 'catalogue']);
        }
      });

      // Column by column and index by index, as the step before left it.
      List<Object?> shapeOf(ResultSet Function(String) select) => [
        for (final column in select('PRAGMA table_info(audit_events)'))
          [column['name'], column['type'], column['notnull'], column['pk']],
        for (final index in select('PRAGMA index_list(audit_events)'))
          [
            index['name'],
            index['unique'],
            for (final column in select('PRAGMA index_info(${index['name']})'))
              column['name'],
          ],
        select(
          "SELECT COUNT(*) AS n FROM sqlite_schema "
          "WHERE name LIKE 'audit_events%'",
        ).first['n'],
      ];
      final before = sqlite3.open(path);
      final shapeBefore = shapeOf(before.select);
      before.close();
      expect(shapeBefore, isNotEmpty);

      final db = AppDatabase.open(path);
      addTearDown(db.close);
      expect(shapeOf(db.select), shapeBefore);

      db.setSetting('after', 'migration');
      expect(
        db.select('SELECT MAX(id) AS id FROM audit_events').first['id'] as int,
        greaterThan(last),
        reason: 'an id is never given twice',
      );
    });
  });
}
