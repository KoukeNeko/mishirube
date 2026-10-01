import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/app/theme.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/health/health_source.dart';
import 'package:mishirube/backend/storage/database.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/today/today_screen.dart';
import 'package:mishirube/features/today/today_widgets.dart';
import 'package:mishirube/features/trends/usual_range_trend.dart';
import 'package:mishirube/features/vitals/vitals_screen.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

import '../../support/harness.dart';

/// A platform holding heart rate samples on two days of the week.
class _Health extends NoHealthSource {
  const _Health();

  @override
  Future<Map<OvernightMeasure, List<(DateTime, double)>>> overnightSeries(
    DateTime from,
    DateTime to,
  ) async => {
    OvernightMeasure.heartRate: [
      (from.add(const Duration(hours: 3)), 52),
      (from.add(const Duration(hours: 15)), 96),
      (to.subtract(const Duration(hours: 10)), 60),
      (to.subtract(const Duration(hours: 9)), 110),
    ],
  };
}

void main() {
  /// Twenty days of resting heart rate up to today, the last one well
  /// above the others, and today's blood pressure.
  AppStore store({HealthSource? health}) {
    final clock = FakeClock();
    final backend = Backend.inMemory(clock: clock.now);
    if (health != null) backend.db.setSetting('health.connected', 'true');
    final store = AppStore(
      clock: clock.now,
      isOnboarded: true,
      backend: backend,
      health: health,
    );
    store.backend.provenance.setShowsDemo(false);
    final today = store.now();
    ActivitySample daily(ActivityMetric metric, int back, double value) =>
        ActivitySample(
          metric: metric,
          start: DateTime(today.year, today.month, today.day - back),
          end: DateTime(today.year, today.month, today.day - back + 1),
          value: value,
        );
    store.backend.storage.activitySamples.sync(
      [
        for (var back = 19; back >= 1; back--)
          daily(ActivityMetric.restingHeartRate, back, 58.0 + back % 3),
        daily(ActivityMetric.restingHeartRate, 0, 70),
        daily(ActivityMetric.heartRate, 0, 72),
        daily(ActivityMetric.bloodPressureSystolic, 0, 118),
        daily(ActivityMetric.bloodPressureDiastolic, 0, 76),
      ],
      idPrefix: 'healthkit',
      source: ChangeSource.healthKit,
    );
    return store;
  }

  Sparkline lineIn(WidgetTester tester, Finder row) => tester.widget<Sparkline>(
    find.descendant(of: row, matching: find.byType(Sparkline)),
  );

  testWidgets('each reading carries its week against its usual range', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await pumpScreen(tester, const VitalsScreen(), store: store());

    final resting = find.widgetWithText(NavRow, '靜止心率');
    final line = lineIn(tester, resting);
    expect(line.values, hasLength(7), reason: 'a week, a day a point');
    expect(line.color, AppColors.heart);
    expect(line.bands!.last, isNotNull, reason: '19 days before today');
    expect(line.outside, {6}, reason: 'today apart from the weeks before');
    final pressure = tester.widget<RangeSpark>(
      find.descendant(
        of: find.widgetWithText(NavRow, '血壓'),
        matching: find.byType(RangeSpark),
      ),
    );
    expect(pressure.ranges.last, (76, 118), reason: 'diastolic to systolic');
    expect(pressure.ranges.first, isNull, reason: 'not taken that day');
    await disposeTree(tester);
  });

  testWidgets('heart rate\'s week is each day\'s lowest to highest', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await pumpScreen(
      tester,
      const VitalsScreen(),
      store: store(health: const _Health()),
    );
    await tester.pumpAndSettle();
    final ranges = tester
        .widget<RangeSpark>(
          find.descendant(
            of: find.widgetWithText(NavRow, '平均心率'),
            matching: find.byType(RangeSpark),
          ),
        )
        .ranges;
    expect(ranges, hasLength(7));
    expect(ranges.first, (52, 96), reason: 'the first day\'s samples');
    expect(ranges.last, (60, 110), reason: 'today\'s samples');
    expect(ranges[3], isNull, reason: 'no samples, no bar');
    await disposeTree(tester);
  });

  testWidgets('without the platform\'s samples heart rate is a line', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await pumpScreen(tester, const VitalsScreen(), store: store());
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.widgetWithText(NavRow, '平均心率'),
        matching: find.byType(UsualRangeSpark),
      ),
      findsOneWidget,
    );
    await disposeTree(tester);
  });

  testWidgets('Today\'s card sets each figure beside its week', (tester) async {
    usePhoneViewport(tester);
    await pumpScreen(tester, const TodayScreen(), store: store());
    final card = find.byType(VitalsCard);
    await tester.scrollUntilVisible(
      card,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.descendant(of: card, matching: find.byType(UsualRangeSpark)),
      findsOneWidget,
      reason: 'resting heart rate as a line',
    );
    expect(
      find.descendant(of: card, matching: find.byType(RangeSpark)),
      findsOneWidget,
      reason: 'blood pressure as its pair',
    );
    await disposeTree(tester);
  });
}
