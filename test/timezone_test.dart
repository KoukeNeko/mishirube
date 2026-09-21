import 'package:flutter_test/flutter_test.dart';

import 'dart:convert';

import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/import_export/canonical_archive.dart';
import 'package:mishirube/backend/engines/food_portion.dart';
import 'package:mishirube/domain/domain.dart';

import 'support/harness.dart';

/// A record belongs to the day the person lived, not to the day the
/// phone is having right now.
///
/// The app cannot change the test runner's own zone, so travel is
/// simulated the only honest way available: the row is rewritten to say
/// what a phone in the other zone would have written, and then read
/// back here. That is exactly the situation after a flight — the rows
/// were written somewhere else, and this machine is somewhere new.
void main() {
  late FakeClock clock;
  late Backend backend;

  setUp(() {
    clock = FakeClock();
    backend = Backend.inMemory(clock: clock.now);
  });

  tearDown(() => backend.close());

  /// Logs a meal at [at] and then rewrites the row as a phone
  /// [hoursBehind] hours behind this one would have stored it.
  MealEvent logFromAbroad(DateTime at, {required int hoursBehind}) {
    final meal = backend.nutrition.logPortion(
      FoodPortion(FoodItem(id: 'abroad', name: '機場早餐', kcal: 400), 1),
    );
    final abroad = at.subtract(Duration(hours: hoursBehind));
    backend.db.execute(
      'UPDATE meals SET eaten_at = ?, local_day = ?, '
      'utc_offset_minutes = ? WHERE id = ?',
      [
        at.millisecondsSinceEpoch,
        localDayOf(abroad),
        at.timeZoneOffset.inMinutes - hoursBehind * 60,
        meal.id,
      ],
    );
    return meal;
  }

  test('a meal stays on the day it was eaten after the flight home', () {
    // 03:00 here is the previous afternoon twelve hours west.
    final at = DateTime(2026, 9, 19, 3);
    clock.current = at;
    logFromAbroad(at, hoursBehind: 12);

    expect(
      backend.nutrition.mealsOn(DateTime(2026, 9, 18)),
      hasLength(1),
      reason: 'it was eaten on the 18th where the person was',
    );
    expect(
      backend.nutrition.mealsOn(at),
      isEmpty,
      reason:
          'the 19th is this phone\'s day, not theirs. Grouping by the '
          'reader\'s zone is what moved breakfast to yesterday.',
    );
  });

  test('the clock shown is the one they read', () {
    final at = DateTime(2026, 9, 19, 3);
    clock.current = at;
    logFromAbroad(at, hoursBehind: 12);

    expect(
      backend.nutrition.mealsOn(DateTime(2026, 9, 18)).single.timeLabel,
      '15:00',
      reason: '03:00 here was 15:00 there, and 15:00 is what they saw',
    );
  });

  test('a row from before the app kept a day falls back to this one', () {
    final at = DateTime(2026, 9, 19, 3);
    clock.current = at;
    final meal = logFromAbroad(at, hoursBehind: 12);
    backend.db.execute(
      'UPDATE meals SET local_day = NULL, utc_offset_minutes = NULL '
      'WHERE id = ?',
      [meal.id],
    );

    expect(
      backend.nutrition.mealsOn(at),
      hasLength(1),
      reason:
          'an old row keeps the day it has always been shown on, '
          'rather than being given a day nobody recorded',
    );
  });

  test('the day survives a backup and a restore', () {
    final at = DateTime(2026, 9, 19, 3);
    clock.current = at;
    logFromAbroad(at, hoursBehind: 12);

    final restored = Backend.inMemory(clock: clock.now);
    addTearDown(restored.close);
    restoreArchive(
      restored.db,
      jsonDecode(encodeArchive(exportArchive(backend.db))),
    );

    expect(restored.nutrition.mealsOn(DateTime(2026, 9, 18)), hasLength(1));
    expect(restored.nutrition.mealsOn(at), isEmpty);
  });
}
