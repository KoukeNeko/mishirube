import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/seed/exercise_catalogue.dart';
import 'package:mishirube/backend/seed/seed.dart';
import 'package:mishirube/features/exercise/exercise_picker_screen.dart';

import '../../support/harness.dart';

void main() {
  testWidgets('the picker opens, scrolls and searches the whole library', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final clock = FakeClock();
    final backend = Backend.inMemory(clock: clock.now);
    addTearDown(backend.close);
    seedDemoData(backend, clock.now());
    await tester.runAsync(
      () => loadExerciseCatalogue(backend.db, backend.storage.exercises),
    );
    final store = AppStore(
      clock: clock.now,
      backend: backend,
      isOnboarded: true,
    );
    expect(store.exercises.length, greaterThan(1300));

    final opening = Stopwatch()..start();
    await pumpScreen(
      tester,
      const ExercisePickerScreen(purpose: PickerPurpose.browse),
      store: store,
    );
    await tester.pump();
    expect(
      opening.elapsed,
      lessThan(const Duration(seconds: 5)),
      reason: 'it runs on the UI isolate',
    );

    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, -3000),
      3000,
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byType(TextField), '啞鈴');
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });
}
