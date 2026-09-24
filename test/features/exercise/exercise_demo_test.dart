import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/seed/exercise_catalogue.dart';
import 'package:mishirube/backend/seed/seed.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/exercise/exercise_demo.dart';
import 'package:mishirube/features/exercise/exercise_detail_screen.dart';

import '../../support/harness.dart';

void main() {
  final bench = parseExerciseCatalogue(
    jsonDecode(File(exerciseCatalogueFile).readAsStringSync())
        as Map<String, dynamic>,
  ).firstWhere((exercise) => exercise.id == 'bench-press');

  String shownFrame(WidgetTester tester) =>
      ((tester.widget<Image>(find.byType(Image).last).image) as AssetImage)
          .assetName;

  testWidgets('the poses play there and back, and a tap pauses them', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ExerciseDemo(name: bench.name, frames: bench.frames),
      ),
    );
    final seen = [shownFrame(tester)];
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 750));
      seen.add(shownFrame(tester));
    }
    expect(seen, [
      bench.frames[0],
      bench.frames[1],
      bench.frames[2],
      bench.frames[1],
      bench.frames[0],
    ]);

    await tester.tap(find.byType(ExerciseDemo));
    await tester.pump(const Duration(seconds: 3));
    expect(shownFrame(tester), bench.frames[0], reason: 'paused');
  });

  testWidgets('with reduced motion the poses stand side by side', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: ExerciseDemo(name: bench.name, frames: bench.frames),
        ),
      ),
    );
    expect(find.byType(Image), findsNWidgets(3));
  });

  testWidgets('an exercise page shows how, where and with what', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final clock = FakeClock();
    final backend = Backend.inMemory(clock: clock.now);
    seedDemoData(backend, clock.now());
    await tester.runAsync(
      () => loadExerciseCatalogue(backend.db, backend.storage.exercises),
    );
    final store = AppStore(
      clock: clock.now,
      backend: backend,
      isOnboarded: true,
    );
    await pumpScreen(
      tester,
      ExerciseDetailScreen(exercise: bench),
      store: store,
    );

    expect(find.byType(ExerciseDemo), findsOneWidget);
    expect(find.textContaining('CC BY-SA 4.0'), findsOneWidget);
    expect(find.text('三頭肌、三角肌前束'), findsOneWidget);
    expect(find.text('雙側'), findsOneWidget);
    await disposeTree(tester);
  });

  test('a region finds its muscles, and a muscle finds the region', () {
    expect(MuscleGroup.back.covers(MuscleGroup.lats), isTrue);
    expect(MuscleGroup.lats.covers(MuscleGroup.back), isTrue);
    expect(MuscleGroup.lats.covers(MuscleGroup.traps), isFalse);
    expect(MuscleGroup.back.covers(MuscleGroup.chest), isFalse);
    expect(
      const ExerciseFilter(muscles: {MuscleGroup.shoulders}).matches(bench),
      isFalse,
      reason: 'the bench press leads with the chest',
    );
    expect(
      const ExerciseFilter(muscles: {MuscleGroup.chest}).matches(bench),
      isTrue,
    );
  });
}
