import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/storage/database.dart';
import 'package:mishirube/backend/engines/trend_findings.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/journal/bath_entry_screen.dart';
import 'package:mishirube/features/journal/journal_detail_screen.dart';
import 'package:mishirube/features/trends/trend_detail_screen.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

import '../../support/harness.dart';

void main() {
  AppStore newStore() {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    store.backend.provenance.setShowsDemo(false);
    return store;
  }

  List<BathEntry> baths(AppStore store) => store.backend.storage.journal
      .bathsBetween(DateTime(2020), DateTime(2030));

  /// Whether the chip named [label] shows as chosen.
  bool chosen(WidgetTester tester, String label) => tester
      .widget<SelectChip>(find.widgetWithText(SelectChip, label))
      .isSelected;

  testWidgets('water and kind start unchosen and nothing says optional', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = newStore();
    await pumpScreen(tester, const BathEntryScreen(), store: store);

    for (final label in ['冷水', '溫水', '熱水', '淋浴', '泡澡']) {
      expect(chosen(tester, label), isFalse, reason: label);
    }
    expect(find.textContaining('選填'), findsNothing);

    await tester.tap(find.text('儲存'));
    await tester.pump();
    final bath = baths(store).single;
    expect(bath.water, isNull);
    expect(bath.kind, isNull);
    expect(bath.duration, isNull);
    await disposeTree(tester);
  });

  testWidgets('a chosen chip is cleared by tapping it again', (tester) async {
    usePhoneViewport(tester);
    final store = newStore();
    await pumpScreen(tester, const BathEntryScreen(), store: store);

    await tester.tap(find.text('熱水'));
    await tester.pump();
    expect(chosen(tester, '熱水'), isTrue);
    await tester.tap(find.text('溫水'));
    await tester.pump();
    expect(chosen(tester, '熱水'), isFalse, reason: 'one water at a time');
    await tester.tap(find.text('溫水'));
    await tester.pump();
    expect(chosen(tester, '溫水'), isFalse);

    await tester.tap(find.text('泡澡'));
    await tester.pump();
    await tester.tap(find.text('泡澡'));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('bath-minutes')), '15');
    await tester.tap(find.text('儲存'));
    await tester.pump();
    final bath = baths(store).single;
    expect(bath.water, isNull);
    expect(bath.kind, isNull);
    expect(bath.duration, const Duration(minutes: 15));
    await disposeTree(tester);
  });

  testWidgets('the last bath is not carried over to the next', (tester) async {
    usePhoneViewport(tester);
    final store = newStore();
    store.backend.journal.recordBath(
      at: store.now(),
      water: BathWater.cold,
      kind: BathKind.shower,
      duration: const Duration(minutes: 5),
    );
    await pumpScreen(tester, const BathEntryScreen(), store: store);

    for (final label in ['冷水', '淋浴']) {
      expect(chosen(tester, label), isFalse, reason: label);
    }
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('bath-minutes')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller!.text, isEmpty);
    await disposeTree(tester);
  });

  testWidgets('a bath is opened, corrected and deleted with an undo', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = newStore();
    final bath = store.backend.journal.recordBath(
      at: store.now(),
      water: BathWater.warm,
    );
    await pumpScreen(
      tester,
      JournalDetailScreen(id: bath.id, at: bath.bathedAt),
      store: store,
    );
    expect(find.text('溫水'), findsOneWidget);

    await tester.tap(find.text('編輯'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('淋浴'));
    await tester.pump();
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();
    expect(baths(store).single.kind, BathKind.shower);

    await tester.tap(find.text('刪除這筆紀錄'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(baths(store), isEmpty);
    await tester.tap(find.text('復原'));
    await tester.pump();
    expect(baths(store), hasLength(1));
    await disposeTree(tester);
  });

  testWidgets('the factor row says when most baths have no water recorded', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = newStore();
    final now = store.now();
    for (var back = 1; back <= 24; back++) {
      final woke = DateTime(now.year, now.month, now.day - back, 7);
      final bed = woke.subtract(const Duration(hours: 8));
      final bathed = back.isEven;
      final asleep = bed.add(Duration(minutes: bathed ? 10 : 25));
      SleepSample stretch(SleepStage stage, DateTime from) =>
          SleepSample(start: from, end: woke, stage: stage, source: 'watch');
      store.backend.storage.journal
        ..addSleep(
          SleepEntry(
            id: 'night-$back',
            sleptAt: woke,
            duration: woke.difference(asleep),
            startedAt: bed,
          ),
          source: ChangeSource.healthKit,
        )
        ..replaceSleepSegments('night-$back', [
          stretch(SleepStage.inBed, bed),
          stretch(SleepStage.core, asleep),
        ], source: ChangeSource.healthKit);
      if (bathed) {
        store.backend.journal.recordBath(
          at: bed.subtract(const Duration(minutes: 90)),
        );
      }
    }
    await pumpScreen(
      tester,
      const TrendDetailScreen(domain: TrendDomain.sleep),
      store: store,
    );

    await tester.scrollUntilVisible(
      find.text('洗澡'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('洗澡'), findsOneWidget);
    expect(find.text('入睡所需少 15 分 · 12 晚對 12 晚 · 含未填水溫'), findsOneWidget);
    await disposeTree(tester);
  });
}
