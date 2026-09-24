import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/storage/database.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/activity/activity_metric_screen.dart';
import 'package:mishirube/features/activity/daily_activity_screen.dart';
import 'package:mishirube/features/today/today_screen.dart';
import 'package:mishirube/features/today/today_widgets.dart';

import '../../support/harness.dart';

void main() {
  /// A store with the demo records hidden and [samples] read from Apple
  /// Health.
  AppStore storeWith(List<ActivitySample> Function(DateTime today) samples) {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    store.backend.provenance.setShowsDemo(false);
    store.backend.storage.activitySamples.sync(
      samples(store.now()),
      idPrefix: 'healthkit',
      source: ChangeSource.healthKit,
    );
    return store;
  }

  ActivitySample at(
    ActivityMetric metric,
    DateTime today,
    int hour,
    double value,
  ) => ActivitySample(
    metric: metric,
    start: DateTime(today.year, today.month, today.day, hour),
    end: DateTime(today.year, today.month, today.day, hour + 1),
    value: value,
  );

  testWidgets('Today shows the day\'s steps once a platform counted them', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = storeWith(
      (today) => [
        at(ActivityMetric.steps, today, 8, 3200),
        at(ActivityMetric.steps, today, 12, 1100),
        at(ActivityMetric.distance, today, 8, 2400),
      ],
    );
    await pumpScreen(tester, const TodayScreen(), store: store);

    expect(find.byType(TodayActivityCard), findsOneWidget);
    expect(find.text('4,300 步', findRichText: true), findsOneWidget);
    expect(find.text('2.4 km'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('without anything counted Today has no activity card', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await pumpScreen(tester, const TodayScreen(), store: storeWith((_) => []));

    expect(find.byType(TodayActivityCard), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('the day lists only what some source records', (tester) async {
    usePhoneViewport(tester);
    final store = storeWith(
      (today) => [
        at(ActivityMetric.steps, today, 9, 5000),
        ActivitySample(
          metric: ActivityMetric.vo2Max,
          start: DateTime(today.year, today.month, today.day - 3),
          end: DateTime(today.year, today.month, today.day - 2),
          value: 44.1,
        ),
      ],
    );
    await pumpScreen(tester, const DailyActivityScreen(), store: store);

    expect(find.text('步數'), findsWidgets);
    expect(find.text('最大攝氧量'), findsOneWidget);
    expect(find.text('爬樓'), findsNothing, reason: 'no source records it');
    expect(
      find.text('沒有資料'),
      findsOneWidget,
      reason: 'VO₂ max has no reading today, and says so instead of 0',
    );
    await disposeTree(tester);
  });

  testWidgets('a measured metric has no hours to show', (tester) async {
    usePhoneViewport(tester);
    final store = storeWith(
      (today) => [
        ActivitySample(
          metric: ActivityMetric.restingHeartRate,
          start: DateTime(today.year, today.month, today.day),
          end: DateTime(today.year, today.month, today.day + 1),
          value: 58,
        ),
      ],
    );
    await pumpScreen(
      tester,
      ActivityMetricScreen(
        metric: ActivityMetric.restingHeartRate,
        day: store.now(),
      ),
      store: store,
    );

    expect(find.text('日'), findsNothing);
    expect(find.text('半年'), findsOneWidget);
    await disposeTree(tester);
  });
}
