import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/trends/training_trends_screen.dart';

import '../../support/harness.dart';

void main() {
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
