import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/exercise/exercise_detail_screen.dart';
import 'package:mishirube/features/trends/muscle_map.dart';
import 'package:mishirube/features/trends/training_trends_screen.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

import '../../support/harness.dart';

void main() {
  Future<void> scrollTo(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );

  testWidgets('the muscles, their weeks and every exercise are on the page', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const TrainingTrendsScreen(), store: store);

    await scrollTo(tester, find.byType(MuscleMap));
    expect(find.byType(MuscleMap), findsOneWidget);
    await scrollTo(tester, find.text('每週工作組數 · 近 8 週'));
    // A trained exercise, with its best set and its estimate, not a row
    // that opens a page of them.
    await scrollTo(tester, find.text('槓鈴深蹲'));
    await tester.ensureVisible(find.text('槓鈴深蹲'));
    await tester.pump();
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('槓鈴深蹲'),
          matching: find.byType(AppCard),
        ),
        matching: find.textContaining('最重'),
      ),
      findsOneWidget,
      reason: 'the best set is on the exercise itself',
    );
    expect(
      find.byType(AccentRow),
      findsOneWidget,
      reason: 'the volume page is the only one left to open from here',
    );
    expect(find.widgetWithText(AccentRow, '訓練量'), findsOneWidget);

    await tester.tap(find.text('槓鈴深蹲'));
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseDetailScreen), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('all reads back to the first workout, past a year, with years', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    store.backend.provenance.setShowsDemo(false);
    final now = store.now();
    final first = DateTime(now.year, now.month, now.day - 400, 18);
    for (final (id, startedAt) in [
      ('first', first),
      ('recent', now.subtract(const Duration(days: 2))),
    ]) {
      final session = WorkoutSession(
        id: id,
        routineName: '全身',
        startedAt: startedAt,
        exercises: const [],
      )..finishedAt = startedAt.add(const Duration(minutes: 45));
      store.backend.storage.workouts.save(session, action: 'create');
    }
    await pumpScreen(tester, const TrainingTrendsScreen(), store: store);

    expect(
      find.textContaining('年'),
      findsNothing,
      reason: 'a month within one year needs no year',
    );
    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        '${first.year} 年 ${first.month} 月 ${first.day} 日 – '
        '${now.year} 年 ${now.month} 月 ${now.day} 日',
      ),
      findsOneWidget,
      reason:
          'from the first workout\'s day, not a year back, and a span '
          'across a new year says both years',
    );
    await disposeTree(tester);
  });
}
