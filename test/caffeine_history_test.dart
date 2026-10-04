import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/engines/caffeine.dart';
import 'package:mishirube/backend/engines/caffeine_history.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/caffeine/caffeine_screen.dart';
import 'package:mishirube/shared/format.dart';

import 'support/harness.dart';

/// Saturday 19 September 2026: the 28 days are 22 August to 18 September,
/// four Saturdays and four Sundays among them.
final _today = DateTime(2026, 9, 19);

MealEvent _record(
  String id,
  String name, {
  double? caffeine,
  ConsumptionKind kind = ConsumptionKind.food,
}) => MealEvent(
  id: id,
  name: name,
  timeLabel: '',
  qualityTag: '手動',
  dishes: const [],
  kind: caffeine == null ? kind : ConsumptionKind.beverage,
  nutrients: caffeine == null ? const {} : {Nutrient.caffeine: caffeine},
);

/// Three meals on [day]: all a day needs to be logged in full.
List<(DateTime, MealEvent)> _meals(DateTime day) => [
  for (final hour in [8, 12, 19])
    (
      day.add(Duration(hours: hour)),
      _record('meal-${day.day}-${day.month}-$hour', '餐'),
    ),
];

(DateTime, MealEvent) _coffee(
  DateTime day,
  double milligrams, {
  int hour = 9,
  int minute = 0,
  String name = '美式',
}) => (
  day.add(Duration(hours: hour, minutes: minute)),
  _record(
    'coffee-${day.month}-${day.day}-$hour$minute-$name',
    name,
    caffeine: milligrams,
  ),
);

DateTime _day(int day, {int month = 9}) => DateTime(2026, month, day);

void main() {
  group('caffeine history', () {
    test('a day logged in full is a total, any other is a gap, not a zero', () {
      final history = caffeineHistory([
        // The 17th: three meals and two coffees.
        ..._meals(_day(17)),
        _coffee(_day(17), 100, hour: 8, minute: 10),
        _coffee(_day(17), 200, hour: 15, minute: 20, name: '拿鐵'),
        // The 16th: one coffee and one meal, too little to call the day
        // logged.
        (_day(16).add(const Duration(hours: 12)), _record('lone', '餐')),
        _coffee(_day(16), 80),
        // The 14th: logged in full without any caffeine, a true zero.
        ..._meals(_day(14)),
      ], today: _today);

      expect(history.days, hasLength(caffeineHistoryDays));
      expect(history.days.first.day, DateTime(2026, 8, 22));
      expect(history.days.last.day, _day(18));

      CaffeineDay on(int day) =>
          history.days.singleWhere((entry) => entry.day == _day(day));
      expect(on(17).completeTotal, 300);
      expect(on(16).isComplete, isFalse);
      expect(on(16).completeTotal, isNull);
      expect(on(15).completeTotal, isNull, reason: 'nothing logged');
      expect(on(14).completeTotal, 0);

      // Averages and the highest take the complete days alone.
      expect(history.average, 150);
      expect(history.highest, 300);
    });

    test('with no complete day there is no average and no highest', () {
      final history = caffeineHistory([_coffee(_day(17), 90)], today: _today);

      expect(history.average, isNull);
      expect(history.highest, isNull);
    });

    test('today is not a day yet', () {
      final history = caffeineHistory([
        ..._meals(_today),
        _coffee(_today, 400),
      ], today: _today);

      expect(history.days.last.day, _day(18));
      expect(history.days.expand((day) => day.records), isEmpty);
      expect(history.bands.every((milligrams) => milligrams == 0), isTrue);
    });

    test('a day keeps its first and last record in time order', () {
      final history = caffeineHistory([
        _coffee(_day(17), 100, hour: 8, minute: 10),
        _coffee(_day(17), 200, hour: 15, minute: 20, name: '拿鐵'),
        _coffee(_day(17), 50, hour: 11, name: '茶'),
      ], today: _today);

      final day = history.days.singleWhere((entry) => entry.day == _day(17));
      expect(day.first!.at, DateTime(2026, 9, 17, 8, 10));
      expect(day.last!.at, DateTime(2026, 9, 17, 15, 20));
      expect(day.last!.milligrams, 200);
    });

    test('the sources are the top five by milligrams, then count', () {
      final history = caffeineHistory([
        for (var i = 0; i < 3; i++) _coffee(_day(10 + i), 100, name: '美式'),
        _coffee(_day(13), 250, name: '濃縮'),
        _coffee(_day(14), 150, name: '拿鐵'),
        _coffee(_day(15), 150, name: '紅茶'),
        _coffee(_day(15), 0, hour: 10, name: '無咖啡因'),
        // Equal milligrams to 拿鐵 and 紅茶 but one cup more: first of the
        // three.
        _coffee(_day(11), 75, hour: 14, name: '可樂'),
        _coffee(_day(12), 75, hour: 14, name: '可樂'),
        _coffee(_day(16), 20, name: '綠茶'),
        _coffee(_day(17), 10, name: '巧克力'),
      ], today: _today);

      expect(history.sources.map((source) => source.name), [
        '美式',
        '濃縮',
        '可樂',
        '拿鐵',
        '紅茶',
      ]);
      expect(history.sources.first.milligrams, 300);
      expect(history.sources.first.count, 3);
      expect(
        history.sources.map((source) => source.name),
        isNot(contains('無咖啡因')),
        reason: 'a record without caffeine is not a source of it',
      );
    });

    test('milligrams fall into the five bands of the day', () {
      final history = caffeineHistory([
        _coffee(_day(10), 10, hour: 0, minute: 30),
        _coffee(_day(10), 20, hour: 11, minute: 59),
        _coffee(_day(11), 30, hour: 12),
        _coffee(_day(11), 40, hour: 14, minute: 59),
        _coffee(_day(12), 50, hour: 15),
        _coffee(_day(12), 60, hour: 18),
        _coffee(_day(13), 70, hour: 20, minute: 59),
        _coffee(_day(13), 80, hour: 21),
        _coffee(_day(14), 90, hour: 23, minute: 59),
      ], today: _today);

      expect(history.bands, [30, 70, 50, 130, 170]);
      expect(caffeineBandOf(DateTime(2026, 9, 1, 11, 59)), 0);
      expect(caffeineBandOf(DateTime(2026, 9, 1, 12)), 1);
      expect(caffeineBandOf(DateTime(2026, 9, 1, 21)), 4);
    });

    test('weekday and weekend averages need four complete days each', () {
      List<(DateTime, MealEvent)> logged(List<int> days, double milligrams) => [
        for (final day in days) ..._meals(_day(day)),
        for (final day in days) _coffee(_day(day), milligrams),
      ];
      // Saturdays 5, 12 and Sundays 6, 13: three weekend days short of
      // four; the weekdays are four Mondays to Thursdays.
      final threeWeekendDays = caffeineHistory([
        ...logged([7, 8, 9, 10], 100),
        ...logged([5, 6, 12], 300),
      ], today: _today);
      expect(threeWeekendDays.weekdayAverage, 100);
      expect(threeWeekendDays.weekendAverage, isNull);

      final fourWeekendDays = caffeineHistory([
        ...logged([7, 8, 9, 10], 100),
        ...logged([5, 6, 12, 13], 300),
      ], today: _today);
      expect(fourWeekendDays.weekendAverage, 300);

      // A Saturday logged only in part is not one of the four.
      final partlyLogged = caffeineHistory([
        ...logged([7, 8, 9, 10], 100),
        ...logged([5, 6, 12], 300),
        _coffee(_day(13), 900),
      ], today: _today);
      expect(partlyLogged.weekendAverage, isNull);

      final threeWeekdays = caffeineHistory([
        ...logged([7, 8, 9], 100),
      ], today: _today);
      expect(threeWeekdays.weekdayAverage, isNull);
    });

    test('the estimate at bedtime is the usual bedtime of that evening', () {
      const bedtime = Duration(hours: 23);
      final intakes = [
        _coffee(_day(17), 100, hour: 8, minute: 10),
        _coffee(_day(17), 200, hour: 15, minute: 20, name: '拿鐵'),
      ];
      final history = caffeineHistory(
        [
          ..._meals(_day(17)),
          ..._meals(_day(14)),
          ...intakes,
          // Logged in part: its evening is a gap.
          _coffee(_day(16), 400, hour: 20),
        ],
        today: _today,
        usualBedtime: bedtime,
      );

      final at17 = history.days.indexWhere((day) => day.day == _day(17));
      final expected = estimatedCaffeineRemaining(
        caffeineIntakes(intakes),
        now: DateTime(2026, 9, 17, 23),
      );
      expect(history.atBedtime[at17], closeTo(expected, 0.001));
      expect(expected, greaterThan(caffeineBedtimeReferenceMg));
      expect(
        history.atBedtime[history.days.indexWhere(
          (day) => day.day == _day(16),
        )],
        isNull,
      );
      // Logged in full without caffeine: nothing left, not a gap.
      expect(
        history.atBedtime[history.days.indexWhere(
          (day) => day.day == _day(14),
        )],
        0,
      );
    });

    test('a bedtime after midnight is read on the next morning', () {
      final history = caffeineHistory(
        [..._meals(_day(17)), _coffee(_day(17), 100, hour: 22)],
        today: _today,
        usualBedtime: const Duration(minutes: 40),
      );

      final at17 = history.days.indexWhere((day) => day.day == _day(17));
      // 22:00 to 00:40 is 2 h 40 min.
      expect(
        history.atBedtime[at17],
        closeTo(
          estimatedCaffeineRemaining([
            CaffeineIntake(at: DateTime(2026, 9, 17, 22), milligrams: 100),
          ], now: DateTime(2026, 9, 18, 0, 40)),
          0.001,
        ),
      );
    });

    test('without a usual bedtime there is no estimate at bedtime', () {
      final history = caffeineHistory([
        ..._meals(_day(17)),
        _coffee(_day(17), 100),
      ], today: _today);

      expect(history.atBedtime.every((milligrams) => milligrams == null), true);
    });

    test('the distance to bedtime is only for a cup before it', () {
      final at = DateTime(2026, 9, 17, 15, 20);
      expect(
        caffeineBeforeBedtime(at, const Duration(hours: 23)),
        const Duration(hours: 7, minutes: 40),
      );
      expect(
        caffeineBeforeBedtime(
          DateTime(2026, 9, 17, 22),
          const Duration(minutes: 40),
        ),
        const Duration(hours: 2, minutes: 40),
      );
      expect(
        caffeineBeforeBedtime(
          DateTime(2026, 9, 17, 23, 30),
          const Duration(hours: 23),
        ),
        isNull,
        reason: 'after the usual bedtime',
      );
      expect(caffeineBeforeBedtime(at, null), isNull);
    });
  });

  group('caffeine history from the database', () {
    late FakeClock clock;
    late Backend backend;

    setUp(() {
      clock = FakeClock();
      backend = Backend.inMemory(clock: clock.now);
      addTearDown(backend.close);
    });

    void night(int daysAgo) {
      final woke = DateTime(2026, 9, 19 - daysAgo, 7);
      backend.storage.journal.addSleep(
        SleepEntry(
          id: 'night-$daysAgo',
          sleptAt: woke,
          duration: const Duration(hours: 8),
          startedAt: woke.subtract(const Duration(hours: 8)),
          sourceName: 'Apple Watch',
        ),
      );
    }

    void log((DateTime, MealEvent) record) =>
        backend.nutrition.logMeal(record.$2, eatenAt: record.$1);

    test('the usual bedtime waits for three nights that say when', () {
      night(1);
      night(2);
      expect(backend.sleep.usualBedtime(), isNull);

      night(3);
      expect(backend.sleep.usualBedtime(), const Duration(hours: 23));
    });

    test('stored records come back as the 28 days, today left out', () {
      for (final record in [
        ..._meals(_day(17)),
        _coffee(_day(17), 100, hour: 8, minute: 10),
        _coffee(_day(17), 200, hour: 15, minute: 20, name: '拿鐵'),
        // The day the window starts on, and the one before it.
        _coffee(_day(22, month: 8), 60),
        _coffee(_day(21, month: 8), 500),
        // Today, still going.
        _coffee(_today, 300, hour: 8),
      ]) {
        log(record);
      }
      for (var daysAgo = 1; daysAgo <= 3; daysAgo++) {
        night(daysAgo);
      }

      final history = backend.nutrition.recentCaffeine(
        backend.sleep.usualBedtime(),
      );

      expect(history.days.first.day, DateTime(2026, 8, 22));
      expect(history.days.first.records.single.milligrams, 60);
      expect(history.days.last.records, isEmpty);
      expect(history.average, 300);
      expect(history.bands, [160, 0, 200, 0, 0]);
      final at17 = history.days.indexWhere((day) => day.day == _day(17));
      expect(history.atBedtime[at17], closeTo(81.9, 0.1));
    });

    test('a deleted record is not counted', () {
      final record = _coffee(_day(17), 100);
      log(record);
      backend.nutrition.deleteMeals([record.$2.id]);

      expect(
        backend.nutrition
            .recentCaffeine(null)
            .days
            .expand((day) => day.records),
        isEmpty,
      );
    });
  });

  group('caffeine page', () {
    late FakeClock clock;
    late AppStore store;

    setUp(() {
      clock = FakeClock();
      store = AppStore(
        clock: clock.now,
        isOnboarded: true,
        backend: Backend.inMemory(clock: clock.now),
      );
      // The demo records are not this month.
      store.backend.provenance.setShowsDemo(false);
    });

    /// Every day of the month logged in full, a coffee at 08:30 and a
    /// second one in the afternoon, with seven nights at 23:00.
    void logMonth() {
      for (var daysAgo = 1; daysAgo <= 28; daysAgo++) {
        final day = DateTime(2026, 9, 19 - daysAgo);
        for (final (hour, name, caffeine) in [
          (8, '早餐', null),
          (12, '午餐', null),
          (19, '晚餐', null),
        ]) {
          store.backend.nutrition.logMeal(
            _record('page-$daysAgo-$hour', name, caffeine: caffeine),
            eatenAt: day.add(Duration(hours: hour)),
          );
        }
        for (final (hour, minute, name, caffeine) in [
          (8, 30, '美式', 95.0),
          (15, 20, '拿鐵', 150.0),
        ]) {
          store.backend.nutrition.logMeal(
            _record('cup-$daysAgo-$hour', name, caffeine: caffeine),
            eatenAt: day.add(Duration(hours: hour, minutes: minute)),
          );
        }
      }
      for (var daysAgo = 1; daysAgo <= 7; daysAgo++) {
        final woke = DateTime(2026, 9, 19 - daysAgo, 7);
        store.backend.storage.journal.addSleep(
          SleepEntry(
            id: 'page-night-$daysAgo',
            sleptAt: woke,
            duration: const Duration(hours: 8),
            startedAt: woke.subtract(const Duration(hours: 8)),
            sourceName: 'Apple Watch',
          ),
        );
      }
    }

    testWidgets('every section shows once a month is logged', (tester) async {
      logMonth();
      await pumpScreen(tester, const CaffeineScreen(), store: store);

      final l10n = testL10n;
      Future<void> shows(String label) async {
        final finder = find.text(label);
        await tester.scrollUntilVisible(
          finder,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(finder, findsOneWidget, reason: label);
      }

      await shows(l10n.caffeineDailySection);
      expect(find.text(l10n.statAverageLabel), findsWidgets);
      expect(find.text(l10n.statHighest), findsWidgets);
      expect(
        find.textContaining('245', findRichText: true),
        findsWidgets,
        reason: 'the daily average',
      );
      await shows(l10n.caffeineLastIntakeSection);
      expect(
        find.text(
          '${l10n.lastIntakeAt(time: '15:20')} · '
          '${l10n.timeBeforeBedtime(time: l10n.hoursMinutes(hours: 7, minutes: 40))}',
        ),
        findsWidgets,
        reason: 'the dose sits on the row with its time',
      );
      await shows(l10n.caffeineAtBedtimeSection);
      expect(
        find.text(
          l10n.caffeineReference(mg: formatAmount(caffeineBedtimeReferenceMg)),
        ),
        findsWidgets,
      );
      await shows(l10n.sourceLabel);
      await shows(l10n.timeOfDaySection);
      await shows(l10n.weekdaysAndDaysOffSection);
      expect(find.text(l10n.weekdaysLabel), findsOneWidget);
      expect(find.text(l10n.daysOffLabel), findsOneWidget);

      // What the page must never say.
      for (final word in ['上限', '戒斷', '耐受', '重置', '連續', '安全', '睡眠']) {
        expect(find.textContaining(word), findsNothing, reason: word);
      }
      await disposeTree(tester);
    });

    testWidgets('without a usual bedtime nothing is read against one', (
      tester,
    ) async {
      logMonth();
      // Two nights are too few to say when bedtime usually is.
      for (var daysAgo = 3; daysAgo <= 7; daysAgo++) {
        store.backend.journal.delete('page-night-$daysAgo');
      }
      await pumpScreen(tester, const CaffeineScreen(), store: store);
      await tester.scrollUntilVisible(
        find.text(testL10n.timeOfDaySection),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(store.backend.sleep.usualBedtime(), isNull);
      expect(find.text(testL10n.caffeineAtBedtimeSection), findsNothing);
      expect(
        find.textContaining(testL10n.timeBeforeBedtime(time: '')),
        findsNothing,
      );
      expect(find.text(testL10n.caffeineLastIntakeSection), findsOneWidget);
      await disposeTree(tester);
    });
  });
}
