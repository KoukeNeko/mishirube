import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/engines/overnight_series.dart';
import 'package:mishirube/backend/health/health_source.dart';
import 'package:mishirube/backend/storage/database.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/sleep/sleep_screen.dart';

import '../../support/harness.dart';

/// A platform holding a night's heart rate, one sample every ten minutes.
class _Health extends NoHealthSource {
  const _Health();

  @override
  Future<Map<OvernightMeasure, List<(DateTime, double)>>> overnightSeries(
    DateTime from,
    DateTime to,
  ) async => {
    OvernightMeasure.heartRate: [
      for (var i = 0; i < 48; i++)
        (from.add(Duration(minutes: 10 * i)), 50.0 + i % 12),
    ],
  };
}

void main() {
  test('a night is split into stretches of lowest and highest', () {
    final from = DateTime(2026, 9, 19, 0);
    final to = from.add(const Duration(hours: 8));
    final ranges = rangeBins(
      [
        (from.add(const Duration(minutes: 5)), 60),
        (from.add(const Duration(minutes: 20)), 52),
        (from.add(const Duration(hours: 7, minutes: 50)), 70),
      ],
      from,
      to,
    );
    expect(ranges, hasLength(defaultRangeBins));
    expect(ranges.first, (52, 60));
    expect(ranges.last, (70, 70));
    expect(ranges[5], isNull, reason: 'no sample in that half hour');
  });

  testWidgets('the night shows its heart rate through the night', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final clock = FakeClock();
    final backend = Backend.inMemory(clock: clock.now);
    backend.db.setSetting('health.connected', 'true');
    final store = AppStore(
      clock: clock.now,
      isOnboarded: true,
      backend: backend,
      health: const _Health(),
    );
    final woke = clock.now().subtract(const Duration(hours: 1));
    backend.storage.journal.addSleep(
      SleepEntry(
        id: 'night',
        sleptAt: woke,
        duration: const Duration(hours: 8),
        startedAt: woke.subtract(const Duration(hours: 8)),
      ),
      source: ChangeSource.healthKit,
    );
    await pumpScreen(tester, const SleepScreen(), store: store);
    await tester.pump();

    await tester.dragUntilVisible(
      find.text('睡眠時心率'),
      find.byType(CustomScrollView).hitTestable().first,
      const Offset(0, -200),
    );
    expect(find.text('50–61 次/分'), findsOneWidget);
    expect(find.text('睡眠時呼吸速率'), findsNothing, reason: 'no samples');
    await disposeTree(tester);
  });
}
