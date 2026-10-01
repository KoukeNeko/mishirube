import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/health/health_source.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/activity/activity_metric_screen.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

import '../../support/harness.dart';

/// A platform holding a day's heart rate: 60 in the small hours, 100
/// through the afternoon.
class _Health extends NoHealthSource {
  const _Health();

  @override
  Future<Map<OvernightMeasure, List<(DateTime, double)>>> overnightSeries(
    DateTime from,
    DateTime to,
  ) async => {
    OvernightMeasure.heartRate: [
      (from.add(const Duration(hours: 2)), 58),
      (from.add(const Duration(hours: 2, minutes: 10)), 62),
      (from.add(const Duration(hours: 15)), 100),
    ],
  };
}

void main() {
  testWidgets('heart rate opens on its day, read through the day', (
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
    await pumpScreen(
      tester,
      ActivityMetricScreen(metric: ActivityMetric.heartRate, day: store.now()),
      store: store,
    );
    await tester.pumpAndSettle();

    expect(find.text('58–100 次/分'), findsOneWidget);
    final ranges = tester
        .widget<RangeBarChart>(find.byType(RangeBarChart))
        .ranges;
    expect(ranges, hasLength(48), reason: 'half an hour a bar');
    expect(ranges[4], (58, 62), reason: '02:00–02:30');
    expect(ranges[30], (100, 100), reason: '15:00–15:30');
    expect(ranges[10], isNull, reason: 'no reading, no bar');
    await disposeTree(tester);
  });
}
