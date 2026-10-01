import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/trends/training_trends_screen.dart';

import '../../support/harness.dart';

void main() {
  testWidgets('all reads back to the first workout, past a year', (
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

    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('${first.month} 月 ${first.day} 日 –'),
      findsOneWidget,
      reason: 'the range starts on the first workout\'s day, not a year back',
    );
    await disposeTree(tester);
  });
}
