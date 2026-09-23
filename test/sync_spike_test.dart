import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/engines/food_portion.dart';
import 'package:mishirube/backend/import_export/canonical_archive.dart';
import 'package:mishirube/domain/domain.dart';

import 'support/harness.dart';

/// A spike, not a feature: what two clients editing the same data would
/// actually do to each other.
///
/// The app has no sync and has not decided whether to get one. This runs
/// the situation anyway, because that decision should be made against
/// evidence rather than after it. Findings are written up in
/// `research/30-sync-spike.md`; these tests are the evidence, so they
/// assert what today's code really does — including where it loses data.
void main() {
  final clock = FakeClock();

  /// Two clients that start from the same backup, the way two devices
  /// restoring the same archive would.
  (Backend, Backend) twoClientsFrom(Backend origin) {
    final archive = jsonDecode(encodeArchive(exportArchive(origin.db)));
    final clients = [
      for (var i = 0; i < 2; i++) Backend.inMemory(clock: clock.now),
    ];
    for (final client in clients) {
      restoreArchive(client.db, archive);
    }
    return (clients.first, clients.last);
  }

  FoodItem food(String id, String name, {double kcal = 100}) =>
      FoodItem(id: id, name: name, kind: ConsumptionKind.food, kcal: kcal);

  test('restoring one client onto another discards the other entirely', () {
    final origin = Backend.inMemory(clock: clock.now);
    addTearDown(origin.close);
    origin.storage.foods.save(food('shared', '雞胸肉'));

    final (a, b) = twoClientsFrom(origin);
    addTearDown(a.close);
    addTearDown(b.close);

    a.storage.foods.save(food('only-on-a', '地瓜'));
    b.storage.foods.save(food('only-on-b', '豆漿'));

    // What the app can do today: take B's backup and restore it on A.
    restoreArchive(a.db, jsonDecode(encodeArchive(exportArchive(b.db))));

    expect(
      a.storage.foods.all().map((f) => f.id).toSet(),
      {'shared', 'only-on-b'},
      reason:
          'restore replaces every table, so A\'s own work is gone. '
          'Today there is no merge, only replacement.',
    );
  });

  test('every record already carries what last-write-wins would need', () {
    final origin = Backend.inMemory(clock: clock.now);
    addTearDown(origin.close);
    origin.storage.foods.save(food('shared', '雞胸肉'));

    final (a, b) = twoClientsFrom(origin);
    addTearDown(a.close);
    addTearDown(b.close);

    final before = a.storage.foods.byId('shared')!;
    a.storage.foods.save(before.copyWith(name: 'A 改的'));
    clock.advance(const Duration(minutes: 5));
    b.storage.foods.save(before.copyWith(name: 'B 改的'));

    Map<String, Object?> rowOf(Backend client) => client.db.select(
      'SELECT revision, updated_at FROM foods WHERE id = ?',
      ['shared'],
    ).single;

    // Both bumped the same revision from the same ancestor, so the
    // revision alone cannot say who is newer — only that they diverged.
    expect(rowOf(a)['revision'], rowOf(b)['revision']);
    expect(
      rowOf(b)['updated_at'] as int,
      greaterThan(rowOf(a)['updated_at'] as int),
      reason:
          'the timestamps can order them, which is all LWW needs — '
          'and LWW would silently drop the other edit',
    );
  });

  test('a record edited on one client and deleted on the other', () {
    final origin = Backend.inMemory(clock: clock.now);
    addTearDown(origin.close);
    origin.storage.foods.save(food('shared', '雞胸肉'));

    final (a, b) = twoClientsFrom(origin);
    addTearDown(a.close);
    addTearDown(b.close);

    a.storage.foods.delete('shared');
    b.storage.foods.save(b.storage.foods.byId('shared')!.copyWith(kcal: 165));

    expect(a.storage.foods.byId('shared'), isNull);
    expect(b.storage.foods.byId('shared')!.kcal, 165);
    // Nothing in the data says which one the user meant. A timestamp can
    // pick a winner; it cannot know that deleting and correcting are not
    // the same kind of act.
  });

  test('what was logged survives a conflict, because it was copied', () {
    final origin = Backend.inMemory(clock: clock.now);
    addTearDown(origin.close);
    final soy = food('soy', '豆漿', kcal: 130);
    origin.storage.foods.save(soy);
    origin.nutrition.logPortion(FoodPortion(soy, 1));

    final (a, b) = twoClientsFrom(origin);
    addTearDown(a.close);
    addTearDown(b.close);

    a.storage.foods.save(a.storage.foods.byId('soy')!.copyWith(kcal: 90));
    b.storage.foods.delete('soy');

    for (final client in [a, b]) {
      expect(
        client.nutrition.mealsOn(clock.now()).single.kcal,
        130,
        reason:
            'meals copied their numbers, so a fight over the food '
            'cannot rewrite what was drunk. This is the one part of the '
            'model that is already conflict-free.',
      );
    }
  });

  test('two clients naming the same thing make two different foods', () {
    final origin = Backend.inMemory(clock: clock.now);
    addTearDown(origin.close);

    final (a, b) = twoClientsFrom(origin);
    addTearDown(a.close);
    addTearDown(b.close);

    a.storage.foods.save(food('a-milk', '鮮奶'));
    b.storage.foods.save(food('b-milk', '鮮奶'));

    expect(
      {
        ...a.storage.foods.all(),
        ...b.storage.foods.all(),
      }.map((f) => f.name).toList(),
      hasLength(2),
      reason:
          'ids are per-device, so merging would leave duplicates. '
          'No app in the competitor review solves this automatically.',
    );
  });
}
