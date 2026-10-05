import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/app/watch_sync.dart';

import 'support/harness.dart';

void main() {
  const channel = MethodChannel('mishirube/watch');

  AppStore newStore(FakeClock clock) =>
      AppStore(clock: clock.now, isOnboarded: true);

  /// What the phone sends the watch, newest last.
  List<Map<Object?, Object?>> listenForUpdates(WidgetTester tester) {
    final updates = <Map<Object?, Object?>>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'update') {
        updates.add(Map.of(call.arguments as Map<Object?, Object?>));
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    return updates;
  }

  Future<void> fromWatch(
    WidgetTester tester,
    String method, [
    Object? arguments,
  ]) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(MethodCall(method, arguments)),
      (_) {},
    );
    await tester.pump();
  }

  Future<void> pumpSync(WidgetTester tester, AppStore store) => pumpScreen(
    tester,
    const WatchSync(child: SizedBox.shrink()),
    store: store,
  );

  testWidgets('with no workout it offers today\'s, and starts it', (
    tester,
  ) async {
    final updates = listenForUpdates(tester);
    final store = newStore(FakeClock());
    await pumpSync(tester, store);

    expect(updates.last['phase'], 'idle');
    expect(updates.last['routine'], store.selectedRoutine!.name);
    expect(updates.last['canStart'], isTrue);

    await fromWatch(tester, 'startWorkout');
    expect(store.activeWorkout, isNotNull);
    expect(updates.last['phase'], 'ready');
    await disposeTree(tester);
  });

  testWidgets('the words on the watch are the app\'s, in its language', (
    tester,
  ) async {
    final updates = listenForUpdates(tester);
    final store = newStore(FakeClock());
    await pumpScreen(
      tester,
      const WatchSync(child: SizedBox.shrink()),
      store: store,
      locale: const Locale('en'),
    );

    final labels = updates.last['labels'] as Map<Object?, Object?>;
    expect(labels['logSet'], 'Complete set');
    expect(labels['sets'], '{} sets', reason: 'the watch puts its number in');
    expect(labels['reps'], contains('{}'));
    await disposeTree(tester);
  });

  testWidgets('a running workout is sent whole, and logs from the wrist', (
    tester,
  ) async {
    final updates = listenForUpdates(tester);
    final clock = FakeClock();
    final store = newStore(clock)
      ..startWorkout()
      ..beginWorkout();
    await pumpSync(tester, store);

    final state = updates.last;
    final workout = store.activeWorkout!;
    expect(state['phase'], 'running');
    expect(state['exercise'], workout.currentExercise.exercise.name);
    expect(state['index'], 0);
    expect((state['exercises'] as List), hasLength(workout.exercises.length));
    expect(state['hasNext'], isTrue);
    expect(state['clockAt'], isNotNull);
    expect(state['elapsedMs'], isNull, reason: 'it is running');

    final before = workout.completedSets;
    await fromWatch(tester, 'logNextSet');
    expect(workout.completedSets, before + 1);
    expect(store.restEndsAt, isNotNull, reason: 'a rest follows the set');
    expect(updates.last['restEndsAt'], isNotNull);
    expect(updates.last['restLength'], isNotNull);
    await disposeTree(tester);
  });

  testWidgets('a set is logged at the weight and reps the wrist left', (
    tester,
  ) async {
    final store = newStore(FakeClock())
      ..startWorkout()
      ..beginWorkout();
    await pumpSync(tester, store);
    final exercise = store.activeWorkout!.currentExercise;
    final index = exercise.nextSetIndex!;

    await fromWatch(tester, 'logNextSet', {'weightKg': 62.5, 'reps': 7});
    expect(exercise.sets[index].weightKg, 62.5);
    expect(exercise.sets[index].reps, 7);
    expect(exercise.sets[index].isDone, isTrue);
    await disposeTree(tester);
  });

  testWidgets('a set asked for twice is logged once', (tester) async {
    final updates = listenForUpdates(tester);
    final store = newStore(FakeClock())
      ..startWorkout()
      ..beginWorkout();
    await pumpSync(tester, store);
    final workout = store.activeWorkout!;
    final key = updates.last['setKey'];
    final before = workout.completedSets;

    await fromWatch(tester, 'logNextSet', {'setKey': key});
    await fromWatch(tester, 'logNextSet', {'setKey': key});
    expect(workout.completedSets, before + 1, reason: 'the second is stale');
    expect(
      updates.last['setKey'],
      isNot(key),
      reason: 'the next set has its own',
    );

    await fromWatch(tester, 'logNextSet', {'setKey': updates.last['setKey']});
    expect(workout.completedSets, before + 2);
    await disposeTree(tester);
  });

  testWidgets('the rest is lengthened and skipped from the wrist', (
    tester,
  ) async {
    final store = newStore(FakeClock())
      ..startWorkout()
      ..beginWorkout()
      ..logNextSet();
    await pumpSync(tester, store);
    final endsAt = store.restEndsAt!;

    await fromWatch(tester, 'extendRest', {'seconds': 15});
    expect(store.restEndsAt, endsAt.add(const Duration(seconds: 15)));

    await fromWatch(tester, 'skipRest');
    expect(store.restEndsAt, isNull);
    await disposeTree(tester);
  });

  testWidgets('the workout is paused, switched and finished from the wrist', (
    tester,
  ) async {
    final updates = listenForUpdates(tester);
    final clock = FakeClock();
    final store = newStore(clock)
      ..startWorkout()
      ..beginWorkout();
    await pumpSync(tester, store);

    // Paused the moment it began it would read as not yet begun.
    clock.advance(const Duration(minutes: 1));
    await fromWatch(tester, 'togglePause');
    expect(store.activeWorkout!.isPaused, isTrue);
    expect(updates.last['phase'], 'paused');
    expect(updates.last['clockAt'], isNull);
    expect(updates.last['elapsedMs'], isNotNull);

    await fromWatch(tester, 'togglePause');
    expect(store.activeWorkout!.isPaused, isFalse);

    await fromWatch(tester, 'selectExercise', {'index': 1});
    expect(store.activeWorkout!.currentExerciseIndex, 1);
    expect(updates.last['index'], 1);

    await fromWatch(tester, 'selectExercise', {'index': 99});
    expect(
      store.activeWorkout!.currentExerciseIndex,
      1,
      reason: 'an index that is not an exercise is ignored',
    );

    await fromWatch(tester, 'finishWorkout');
    expect(store.activeWorkout, isNull);
    expect(updates.last['phase'], 'idle');
    await disposeTree(tester);
  });

  testWidgets('a request with nothing to act on does nothing', (tester) async {
    final store = newStore(FakeClock());
    await pumpSync(tester, store);

    for (final method in [
      'logNextSet',
      'skipRest',
      'togglePause',
      'finishWorkout',
      'beginWorkout',
    ]) {
      await fromWatch(tester, method, <String, Object?>{});
    }
    await fromWatch(tester, 'extendRest', {'seconds': 15});
    await fromWatch(tester, 'selectExercise', {'index': 0});
    expect(store.activeWorkout, isNull);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });
}
