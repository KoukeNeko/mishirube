import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/app/theme.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/health/health_source.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/training/workout_summary_screen.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

import '../../support/harness.dart';

/// A platform answering with [samples] for any range asked, and noting
/// the range.
class _Health extends NoHealthSource {
  _Health(this.samples, {this.fails = false});

  final List<(DateTime, double)> Function(DateTime from, DateTime to) samples;
  final bool fails;
  final asked = <(DateTime, DateTime)>[];

  @override
  Future<Map<OvernightMeasure, List<(DateTime, double)>>> overnightSeries(
    DateTime from,
    DateTime to,
  ) async {
    asked.add((from, to));
    if (fails) throw PlatformException(code: 'unavailable');
    return {OvernightMeasure.heartRate: samples(from, to)};
  }
}

void main() {
  AppStore store(_Health? health) {
    final clock = FakeClock();
    final backend = Backend.inMemory(clock: clock.now);
    if (health != null) backend.db.setSetting('health.connected', 'true');
    return AppStore(
      clock: clock.now,
      isOnboarded: true,
      backend: backend,
      health: health,
    );
  }

  /// One sample a minute through the workout, 100 rising by 2.
  List<(DateTime, double)> rising(DateTime from, DateTime to) => [
    for (var m = 0; from.add(Duration(minutes: m)).isBefore(to); m++)
      (from.add(Duration(minutes: m)), 100.0 + m * 2),
    (from.subtract(const Duration(minutes: 5)), 40),
  ];

  testWidgets('the platform\'s heart rate over the workout is charted', (
    tester,
  ) async {
    final health = _Health(rising);
    final store0 = store(health);
    final workout = store0.lastFinishedWorkout!;
    await pumpScreen(tester, const WorkoutSummaryScreen(), store: store0);
    await tester.pumpAndSettle();

    expect(health.asked.single, (workout.startedAt, workout.finishedAt));
    expect(find.text('心率'), findsOneWidget);
    final line = tester.widget<Sparkline>(find.byType(Sparkline));
    expect(line.color, AppColors.heart);
    expect(line.values.first, 100, reason: 'before the start is left out');
    expect(find.textContaining('平均'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('zones follow from a birth year', (tester) async {
    final store0 = store(_Health(rising));
    store0.backend.journal.setBirthYear(1990);
    await pumpScreen(tester, const WorkoutSummaryScreen(), store: store0);
    await tester.pumpAndSettle();

    expect(find.text('區間 1'), findsOneWidget);
    await disposeTree(tester);
  });

  Future<void> expectNoSection(WidgetTester tester, _Health? health) async {
    await pumpScreen(
      tester,
      const WorkoutSummaryScreen(),
      store: store(health),
    );
    await tester.pumpAndSettle();
    expect(find.text('心率'), findsNothing);
    expect(find.byType(Sparkline), findsNothing);
    await disposeTree(tester);
  }

  testWidgets('no samples: no section', (tester) async {
    await expectNoSection(tester, _Health((_, _) => const []));
  });

  testWidgets('no platform: no section', (tester) async {
    await expectNoSection(tester, null);
  });

  testWidgets('a failed read: no section, and the error is reported', (
    tester,
  ) async {
    await expectNoSection(tester, _Health(rising, fails: true));
    expect(tester.takeException(), isA<PlatformException>());
  });
}
