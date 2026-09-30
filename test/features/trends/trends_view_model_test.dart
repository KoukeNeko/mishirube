import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/trends/trends_view_model.dart';

import '../../support/harness.dart';

void main() {
  late Backend backend;
  late TrendsViewModel trends;

  setUp(() {
    backend = Backend.inMemory(clock: FakeClock().now);
    trends = TrendsViewModel(backend);
  });

  tearDown(() {
    trends.dispose();
    backend.close();
  });

  test('the muscle figure is stored and rebuilds the card', () {
    var notified = 0;
    trends.addListener(() => notified++);

    trends.setMuscleFigure(MuscleFigure.female);

    expect(trends.muscleFigure, MuscleFigure.female);
    expect(notified, 1);
  });

  test('a night recorded elsewhere reaches the average', () {
    const week = Duration(days: 7);
    expect(trends.overview(week).averageSleep, isNull);
    backend.journal.recordSleep(const Duration(hours: 7));
    expect(trends.overview(week).averageSleep, const Duration(hours: 7));
  });

  test('training over a range adds up its workouts, sets and time', () {
    final clock = FakeClock();
    final store = AppStore(clock: clock.now, isOnboarded: true);
    final model = TrendsViewModel(store.backend);
    addTearDown(model.dispose);
    // Past the demo's workouts, then one of the user's own.
    clock.advance(const Duration(days: 90));
    const window = Duration(days: 28);
    expect(model.trainingTotals(window).workouts, 0);

    store
      ..startWorkout()
      ..beginWorkout();
    clock.advance(const Duration(minutes: 40));
    store
      ..completeNextSet()
      ..completeNextSet()
      ..completeNextSet()
      ..finishWorkout();

    final totals = model.trainingTotals(window);
    expect(totals.workouts, 1);
    final working = [
      for (final exercise in store.lastFinishedWorkout!.exercises)
        for (final set in exercise.sets)
          if (set.isDone && set.type != SetType.warmup) set,
    ];
    expect(working, isNotEmpty);
    expect(totals.sets, working.length, reason: 'working sets done only');
    expect(totals.time, const Duration(minutes: 40));
    expect(totals.averageLength, const Duration(minutes: 40));
  });
}
