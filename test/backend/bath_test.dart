import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/engines/sleep_metrics.dart';
import 'package:mishirube/backend/import_export/canonical_archive.dart';
import 'package:mishirube/backend/storage/database.dart';
import 'package:mishirube/domain/domain.dart';

import '../support/harness.dart';

// The clock stands on 2026-09-19. Night k began (got into bed) at 23:00 on
// the (18 − k)th and ended on the morning of the (19 − k)th.
DateTime _bedtime(int k) => DateTime(2026, 9, 18 - k, 23);

BathEntry _bath(
  String id,
  DateTime bedtime,
  int minutesBefore, {
  BathWater? water = BathWater.warm,
}) => BathEntry(
  id: id,
  bathedAt: bedtime.subtract(Duration(minutes: minutesBefore)),
  water: water,
);

void main() {
  group('the bath factor grouping (research/92f A3)', () {
    final first = DateTime(2026, 1, 1);

    /// One night whose latency is [latency] minutes, set against [baths].
    BathComparison compare(
      List<List<BathEntry>> bathsOfNight, {
      bool excludeUnrecorded = false,
      List<int>? latencies,
    }) {
      final nights = <BedNight>[];
      final baths = <BathEntry>[];
      for (final (k, night) in bathsOfNight.indexed) {
        final bedtime = _bedtime(k);
        nights.add((
          night: SleepEntry(
            id: 'n$k',
            sleptAt: bedtime.add(const Duration(hours: 8)),
            duration: const Duration(hours: 7),
          ),
          inBedAt: bedtime,
          latency: Duration(minutes: latencies?[k] ?? 10),
        ));
        baths.addAll(night);
      }
      return compareBathNights(
        nights,
        baths,
        firstBathAt: first,
        excludeUnrecorded: excludeUnrecorded,
      );
    }

    List<BathEntry> at(int minutesBefore, {BathWater? water}) => [
      _bath('b$minutesBefore$water', _bedtime(0), minutesBefore, water: water),
    ];

    // Every case is night 0, so one bath list is built against its bedtime.
    ({int withCount, int withoutCount}) sides(
      List<BathEntry> baths, {
      bool excludeUnrecorded = false,
    }) {
      final result = compare([baths], excludeUnrecorded: excludeUnrecorded);
      return (
        withCount: result.comparison.withCount,
        withoutCount: result.comparison.withoutCount,
      );
    }

    test('no bath in the six hours before bed is without', () {
      expect(sides([]), (withCount: 0, withoutCount: 1));
      expect(sides(at(361)), (withCount: 0, withoutCount: 1));
    });

    test('a bath after getting into bed is not one before it', () {
      expect(sides(at(-5)), (withCount: 0, withoutCount: 1));
    });

    test('the window is 61 to 180 minutes, ends included', () {
      for (final minutes in [61, 120, 180]) {
        expect(sides(at(minutes)), (withCount: 1, withoutCount: 0));
      }
      for (final minutes in [0, 60, 181, 360]) {
        expect(sides(at(minutes)), (
          withCount: 0,
          withoutCount: 0,
        ), reason: '$minutes minutes is on neither side');
      }
    });

    test('warm, hot and unrecorded water are one kind', () {
      for (final water in [BathWater.warm, BathWater.hot, null]) {
        expect(sides(at(90, water: water)), (withCount: 1, withoutCount: 0));
      }
    });

    test('a known cold bath puts the night on neither side', () {
      expect(sides(at(90, water: BathWater.cold)), (
        withCount: 0,
        withoutCount: 0,
      ));
      expect(sides([...at(90), ...at(30, water: BathWater.cold)]), (
        withCount: 0,
        withoutCount: 0,
      ));
    });

    test('every bath of the night must be in the window', () {
      expect(sides([...at(90), ...at(150)]), (withCount: 1, withoutCount: 0));
      expect(sides([...at(90), ...at(30)]), (withCount: 0, withoutCount: 0));
      expect(sides([...at(90), ...at(240)]), (withCount: 0, withoutCount: 0));
    });

    test('nights before the first bath ever are left out', () {
      final result = compareBathNights(
        [
          (
            night: SleepEntry(
              id: 'early',
              sleptAt: _bedtime(0).add(const Duration(hours: 8)),
              duration: const Duration(hours: 7),
            ),
            inBedAt: _bedtime(0),
            latency: const Duration(minutes: 10),
          ),
        ],
        const [],
        firstBathAt: _bedtime(0).add(const Duration(minutes: 1)),
      );
      expect(result.comparison.withoutCount, 0);
      expect(
        compareBathNights(
          const [],
          const [],
          firstBathAt: null,
        ).comparison.withoutCount,
        0,
      );
    });

    test('averages are of falling asleep, per side', () {
      final own = [
        for (var k = 0; k < 20; k++)
          if (k < 10) [_bath('w$k', _bedtime(k), 100)] else <BathEntry>[],
      ];
      final result = compare(
        own,
        latencies: [for (var k = 0; k < 20; k++) k < 10 ? 10 : 22],
      );
      expect(result.comparison.isEnough, isTrue);
      expect(result.comparison.withAverage, const Duration(minutes: 10));
      expect(result.comparison.withoutAverage, const Duration(minutes: 22));
      expect(result.comparison.difference, const Duration(minutes: -12));
    });

    group('the unrecorded water tag', () {
      List<List<BathEntry>> nights({
        required int unrecorded,
        required int total,
      }) => [
        for (var k = 0; k < total; k++)
          [
            _bath(
              'b$k',
              _bedtime(k),
              100,
              water: k < unrecorded ? null : BathWater.warm,
            ),
          ],
      ];

      test('shows when more than half the nights with a bath have none', () {
        expect(
          compare(nights(unrecorded: 6, total: 10)).isMostlyUnrecorded,
          isTrue,
        );
      });

      test('does not show at exactly half, or below', () {
        expect(
          compare(nights(unrecorded: 5, total: 10)).isMostlyUnrecorded,
          isFalse,
        );
        expect(
          compare(nights(unrecorded: 0, total: 10)).isMostlyUnrecorded,
          isFalse,
        );
      });

      test('a night with one recorded bath among them does not rely on it', () {
        final mixed = [
          for (var k = 0; k < 10; k++)
            [
              _bath('a$k', _bedtime(k), 100, water: null),
              _bath('b$k', _bedtime(k), 120),
            ],
        ];
        expect(compare(mixed).unrecordedOnlyCount, 0);
      });

      test('the version that excludes unrecorded leaves those nights out', () {
        final all = nights(unrecorded: 6, total: 10);
        expect(compare(all).comparison.withCount, 10);
        final strict = compare(all, excludeUnrecorded: true);
        expect(strict.comparison.withCount, 4);
        expect(strict.unrecordedOnlyCount, 0);
      });
    });
  });

  group('baths in storage', () {
    late FakeClock clock;
    late Backend backend;

    setUp(() {
      clock = FakeClock();
      backend = Backend.inMemory(clock: clock.now);
    });
    tearDown(() => backend.close());

    test('only the end is stored unless the user said more', () {
      final bath = backend.journal.recordBath(at: clock.now());
      final stored = backend.journal.entry(bath.id)! as BathEntry;
      expect(stored.bathedAt, clock.now());
      expect(stored.water, isNull);
      expect(stored.kind, isNull);
      expect(stored.duration, isNull);

      final row = backend.db
          .select('SELECT water, kind, duration_minutes FROM bath_entries')
          .single;
      expect(row.values, everyElement(isNull));
    });

    test('a correction is audited and a delete is a tombstone', () {
      final bath = backend.journal.recordBath(
        at: clock.now(),
        water: BathWater.hot,
        kind: BathKind.bath,
        duration: const Duration(minutes: 20),
      );
      backend.journal.updateBath(
        BathEntry(
          id: bath.id,
          bathedAt: clock.now().subtract(const Duration(hours: 1)),
          water: BathWater.warm,
        ),
      );
      final stored = backend.journal.entry(bath.id)! as BathEntry;
      expect(stored.water, BathWater.warm);
      expect(stored.kind, isNull, reason: 'a cleared choice becomes null');
      expect(stored.duration, isNull);
      expect(stored.bathedAt, clock.now().subtract(const Duration(hours: 1)));

      backend.journal.delete(bath.id);
      expect(backend.journal.entry(bath.id), isNull);
      expect(
        backend.db.select(
          'SELECT deleted_at, revision FROM bath_entries WHERE id = ?',
          [bath.id],
        ).single['deleted_at'],
        isNotNull,
      );
      backend.journal.restore(bath.id);
      expect(backend.journal.entry(bath.id), isA<BathEntry>());

      final actions = [
        for (final row in backend.db.select(
          "SELECT action FROM audit_events WHERE entity_type = 'bath_entry' "
          'ORDER BY id',
        ))
          row['action'],
      ];
      expect(actions, ['create', 'edit', 'delete', 'restore']);
    });

    test('survives an export and an import unchanged', () {
      backend.journal
        ..recordBath(
          at: clock.now(),
          water: BathWater.cold,
          kind: BathKind.shower,
          duration: const Duration(minutes: 5),
        )
        ..recordBath(at: clock.now().subtract(const Duration(days: 1)));
      final archive = exportArchive(backend.db);

      final target = Backend.inMemory(clock: clock.now);
      addTearDown(target.close);
      restoreArchive(target.db, jsonDecode(encodeArchive(archive)));

      expect(exportArchive(target.db), archive);
      expect((archive['data'] as Map)['bathEntries'], hasLength(2));
    });
  });

  group('baths on the log', () {
    late FakeClock clock;
    late Backend backend;

    setUp(() {
      clock = FakeClock();
      backend = Backend.inMemory(clock: clock.now);
    });
    tearDown(() => backend.close());

    void workoutEndedAt(DateTime end) {
      final start = end.subtract(const Duration(hours: 1));
      backend.db.execute(
        'INSERT INTO workouts (id, name, status, started_at, finished_at, '
        'created_at, updated_at, local_day, utc_offset_minutes) '
        "VALUES (?, 'Push', 'completed', ?, ?, 0, 0, ?, ?)",
        [
          'w${end.millisecondsSinceEpoch}',
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
          end.year * 10000 + end.month * 100 + end.day,
          end.timeZoneOffset.inMinutes,
        ],
      );
    }

    String detailOf(String id) => backend.storage.timeline
        .month(clock.now())
        .days
        .expand((day) => day.entries)
        .firstWhere((entry) => entry.recordId == id)
        .detail;

    final noon = DateTime(2026, 9, 19, 12);

    test('a bath is a row with what was said of it', () {
      final bath = backend.journal.recordBath(
        at: noon,
        water: BathWater.warm,
        kind: BathKind.shower,
        duration: const Duration(minutes: 10),
      );
      expect(detailOf(bath.id), '溫水 · 淋浴 · 10 分');
    });

    test('a cold bath after a workout says how long after', () {
      workoutEndedAt(noon.subtract(const Duration(minutes: 45)));
      final bath = backend.journal.recordBath(at: noon, water: BathWater.cold);
      expect(detailOf(bath.id), '冷水 · 訓練後 45 分');
    });

    test('a bath with no water recorded never says it', () {
      workoutEndedAt(noon.subtract(const Duration(minutes: 45)));
      final bath = backend.journal.recordBath(at: noon);
      expect(detailOf(bath.id), '');
    });

    test('a warm bath after a workout says nothing of it', () {
      workoutEndedAt(noon.subtract(const Duration(minutes: 45)));
      final bath = backend.journal.recordBath(at: noon, water: BathWater.warm);
      expect(detailOf(bath.id), '溫水');
    });

    test(
      'a workout that ended after the bath, or on another day, is not it',
      () {
        workoutEndedAt(noon.add(const Duration(minutes: 30)));
        workoutEndedAt(noon.subtract(const Duration(days: 1)));
        final bath = backend.journal.recordBath(
          at: noon,
          water: BathWater.cold,
        );
        expect(detailOf(bath.id), '冷水');
      },
    );
  });

  group('the bath factor over the records', () {
    late Backend backend;

    setUp(() => backend = Backend.inMemory(clock: FakeClock().now));
    tearDown(() => backend.close());

    /// A night from a watch: in bed from 23:00, asleep [latency] minutes
    /// later, awake at 07:00.
    void night(int k, {required int latency}) {
      final bed = _bedtime(k);
      final woke = bed.add(const Duration(hours: 8));
      SleepSample stretch(SleepStage stage, DateTime from, DateTime to) =>
          SleepSample(start: from, end: to, stage: stage, source: 'watch');
      final asleep = bed.add(Duration(minutes: latency));
      backend.storage.journal
        ..addSleep(
          SleepEntry(
            id: 'night-$k',
            sleptAt: woke,
            duration: woke.difference(asleep),
            startedAt: bed,
          ),
          source: ChangeSource.healthKit,
        )
        ..replaceSleepSegments('night-$k', [
          stretch(SleepStage.inBed, bed, woke),
          stretch(SleepStage.core, asleep, woke),
        ], source: ChangeSource.healthKit);
    }

    test('sets falling asleep after a bath against falling asleep without', () {
      for (var k = 1; k <= 24; k++) {
        final bathed = k.isEven;
        night(k, latency: bathed ? 10 : 25);
        if (bathed) {
          backend.journal.recordBath(
            at: _bedtime(k).subtract(const Duration(minutes: 90)),
            water: BathWater.warm,
          );
        }
      }
      final bath = backend.sleep.factors().bath;

      expect(bath.comparison.withCount, 12);
      expect(bath.comparison.withoutCount, 12);
      expect(bath.comparison.difference, const Duration(minutes: -15));
      expect(bath.isMostlyUnrecorded, isFalse);
    });

    test('a night typed in has no time in bed and is left out', () {
      backend.journal.recordSleep(
        const Duration(hours: 7),
        at: DateTime(2026, 9, 18, 7),
        startedAt: DateTime(2026, 9, 17, 23),
      );
      backend.journal.recordBath(at: DateTime(2026, 9, 17, 21));
      final bath = backend.sleep.factors().bath;
      expect(bath.comparison.withCount, 0);
      expect(bath.comparison.withoutCount, 0);
    });
  });
}
