import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/application/exercise_gifs.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/seed/exercise_catalogue.dart';
import 'package:mishirube/backend/seed/seed.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/exercise/exercise_demo.dart';
import 'package:mishirube/features/exercise/exercise_gif_player.dart';
import 'package:mishirube/features/exercise/exercise_detail_screen.dart';

import '../../support/harness.dart';

/// A valid one-pixel GIF: what a download is made of here.
const _tinyGif = [
  0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00, 0x80, 0x00, //
  0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0x21, 0xf9, 0x04, 0x01, 0x00,
  0x00, 0x00, 0x00, 0x2c, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
  0x00, 0x02, 0x02, 0x44, 0x01, 0x00, 0x3b,
];

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
    await pumpScreen(tester, ExerciseDemo(exercise: bench), store: AppStore());
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
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpScreen(tester, ExerciseDemo(exercise: bench), store: AppStore());
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

  group('the animation', () {
    late Directory cache;
    var requests = 0;

    setUp(() {
      cache = Directory.systemTemp.createTempSync('exercise-gifs');
      requests = 0;
      addTearDown(() => cache.deleteSync(recursive: true));
    });

    AppStore storeWith(http.Client client) => AppStore(
      gifs: ExerciseGifs(
        mediaIds: {bench.id: 'abc1234'},
        directory: cache,
        client: client,
      ),
    );

    final isPlayer = find.byType(ExerciseGifPlayer);
    // The poses: pictures from the library's own files.
    final isPoses = find.byWidgetPredicate(
      (widget) => widget is Image && widget.image is AssetImage,
    );

    /// The download is real file work, which the test clock does not drive:
    /// let it run, then let the widget see the result.
    Future<void> downloaded(WidgetTester tester, {Finder? until}) async {
      final done = until ?? isPlayer;
      for (var i = 0; i < 100 && done.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
    }

    testWidgets('replaces the poses once it has been downloaded', (
      tester,
    ) async {
      final store = storeWith(
        MockClient((request) async {
          requests++;
          return http.Response.bytes(_tinyGif, 200);
        }),
      );
      await pumpScreen(tester, ExerciseDemo(exercise: bench), store: store);
      expect(isPlayer, findsNothing, reason: 'the poses meanwhile');

      await downloaded(tester);
      expect(isPlayer, findsOneWidget);
      expect(
        File('${cache.path}/abc1234.gif').existsSync(),
        isTrue,
        reason: 'kept for the next time',
      );
      expect(requests, 1);
      await disposeTree(tester);
    });

    testWidgets('is read from the device when it is already there', (
      tester,
    ) async {
      File('${cache.path}/abc1234.gif').writeAsBytesSync(_tinyGif);
      final store = storeWith(
        MockClient((request) async {
          requests++;
          return http.Response('', 500);
        }),
      );
      await pumpScreen(tester, ExerciseDemo(exercise: bench), store: store);
      expect(isPlayer, findsOneWidget);
      expect(requests, 0);
      await disposeTree(tester);
    });

    testWidgets('that is not a picture is dropped and the poses stay', (
      tester,
    ) async {
      final file = File('${cache.path}/abc1234.gif')
        ..writeAsBytesSync(utf8.encode('GIF89a-cut-off'));
      final store = storeWith(
        MockClient((request) async => http.Response('', 500)),
      );
      await pumpScreen(tester, ExerciseDemo(exercise: bench), store: store);
      await downloaded(tester, until: isPoses);
      expect(isPlayer, findsNothing);
      expect(file.existsSync(), isFalse, reason: 'fetched again next time');
      await disposeTree(tester);
    });

    testWidgets('leaves the poses when it cannot be had', (tester) async {
      final store = storeWith(
        MockClient((request) async => http.Response('', 503)),
      );
      await pumpScreen(tester, ExerciseDemo(exercise: bench), store: store);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(isPlayer, findsNothing);
      expect(find.byType(Image), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('of an exercise without poses can be tried again', (
      tester,
    ) async {
      final bare = ExerciseDefinition(
        id: bench.id,
        name: bench.name,
        equipment: bench.equipment,
        primaryMuscles: bench.primaryMuscles,
        pattern: bench.pattern,
        trackingType: bench.trackingType,
        laterality: bench.laterality,
        family: bench.family,
      );
      var isOnline = false;
      final store = storeWith(
        MockClient((request) async {
          requests++;
          return isOnline
              ? http.Response.bytes(_tinyGif, 200)
              : throw http.ClientException('offline');
        }),
      );
      await pumpScreen(tester, ExerciseDemo(exercise: bare), store: store);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(find.text('重試'), findsOneWidget);

      isOnline = true;
      await tester.tap(find.text('重試'));
      await tester.pump();
      await downloaded(tester);
      expect(isPlayer, findsOneWidget);
      expect(requests, 2);
      await disposeTree(tester);
    });
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
