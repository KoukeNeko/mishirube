import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/features/training/workout_share.dart';
import 'package:mishirube/features/training/workout_summary_screen.dart';
import 'package:mishirube/l10n/l10n.dart';

import '../../support/harness.dart';

const _share = MethodChannel('dev.fluttercommunity.plus/share');
const _paths = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  /// What the system's share sheet was asked to share.
  final shared = <Map<Object?, Object?>>[];
  late Directory temporary;

  setUp(() {
    shared.clear();
    temporary = Directory.systemTemp.createTempSync('share');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_share, (call) async {
      shared.add(call.arguments as Map<Object?, Object?>);
      return 'dev.fluttercommunity.plus/share/success';
    });
    messenger.setMockMethodCallHandler(_paths, (_) async => temporary.path);
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_share, null);
    messenger.setMockMethodCallHandler(_paths, null);
    temporary.deleteSync(recursive: true);
  });

  testWidgets('a workout is shared as text: its totals, then each set', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    final workout = store.lastFinishedWorkout!;
    final review = store.workoutReview(workout);
    await pumpScreen(tester, const WorkoutSummaryScreen(), store: store);

    await tester.tap(find.bySemanticsLabel('分享'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutShareCard), findsOneWidget);

    await tester.tap(find.text('分享文字'));
    await tester.pumpAndSettle();
    final text = shared.single['text']! as String;
    expect(
      text,
      workoutShareText(testL10n, AppDates.of(testL10n), workout, review),
    );
    final lines = text.split('\n');
    expect(lines.first, workout.routineName);
    for (final item in review.exercises) {
      expect(
        lines,
        contains(
          item.record == null
              ? item.exercise.name
              : '${item.exercise.name} · PR',
        ),
      );
    }
    expect(
      lines.where((line) => RegExp(r'^\d+\. ').hasMatch(line)),
      hasLength(review.sets),
      reason: 'a line for each set done',
    );
    await disposeTree(tester);
  });

  testWidgets('a workout is shared as a picture of its card', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(tester, const WorkoutSummaryScreen(), store: store);
    await tester.tap(find.bySemanticsLabel('分享'));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.text('分享圖片'));
      for (var i = 0; i < 50 && shared.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    final paths = shared.single['paths']! as List<Object?>;
    expect(shared.single['mimeTypes'], ['image/png']);
    final png = File(paths.single! as String).readAsBytesSync();
    expect(png.sublist(1, 4), 'PNG'.codeUnits, reason: 'a PNG file');
    await disposeTree(tester);
  });
}
