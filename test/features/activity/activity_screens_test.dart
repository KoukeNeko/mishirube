import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/app/theme.dart';
import 'package:mishirube/backend/storage/database.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/activity/activity_metric_screen.dart';
import 'package:mishirube/features/activity/daily_activity_screen.dart';
import 'package:mishirube/features/body/body_screen.dart';
import 'package:mishirube/features/today/today_screen.dart';
import 'package:mishirube/features/today/today_view_model.dart';
import 'package:mishirube/features/today/today_widgets.dart';
import 'package:mishirube/features/vitals/vitals_screen.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

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
          metric: ActivityMetric.walkingSpeed,
          start: DateTime(today.year, today.month, today.day - 3),
          end: DateTime(today.year, today.month, today.day - 2),
          value: 1.3,
        ),
      ],
    );
    await pumpScreen(tester, const DailyActivityScreen(), store: store);

    expect(find.text('步數'), findsWidgets);
    expect(find.text('步行速度'), findsOneWidget);
    expect(find.text('爬樓'), findsNothing, reason: 'no source records it');
    expect(
      find.text('沒有紀錄'),
      findsOneWidget,
      reason: 'walking speed has no reading today, and says so instead of 0',
    );
    await disposeTree(tester);
  });

  testWidgets('the heart has its own page, at its last reading', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = storeWith(
      (today) => [
        at(ActivityMetric.steps, today, 9, 5000),
        ActivitySample(
          metric: ActivityMetric.restingHeartRate,
          start: DateTime(today.year, today.month, today.day),
          end: DateTime(today.year, today.month, today.day + 1),
          value: 58,
        ),
        ActivitySample(
          metric: ActivityMetric.vo2Max,
          start: DateTime(today.year, today.month, today.day - 3),
          end: DateTime(today.year, today.month, today.day - 2),
          value: 44.1,
        ),
      ],
    );
    await pumpScreen(tester, const DailyActivityScreen(), store: store);
    expect(find.text('心臟與心肺'), findsNothing, reason: 'not what it did');
    expect(find.text('靜止心率'), findsNothing);
    await disposeTree(tester);

    await pumpScreen(tester, const BodyScreen(), store: store);
    expect(find.text('心臟與心肺', skipOffstage: false), findsNothing);
    await disposeTree(tester);

    await pumpScreen(tester, const VitalsScreen(), store: store);
    expect(find.text('心臟與心肺'), findsOneWidget);
    expect(find.text('58 次/分'), findsOneWidget);
    expect(find.text('44.1 mL/kg/min'), findsOneWidget, reason: 'its last');
    await disposeTree(tester);
  });

  ActivitySample daily(ActivityMetric metric, DateTime today, double value) =>
      ActivitySample(
        metric: metric,
        start: DateTime(today.year, today.month, today.day),
        end: DateTime(today.year, today.month, today.day + 1),
        value: value,
      );

  testWidgets('vitals are beside the heart, blood pressure as a pair', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = storeWith(
      (today) => [
        at(ActivityMetric.steps, today, 9, 5000),
        daily(ActivityMetric.bloodPressureSystolic, today, 118),
        daily(ActivityMetric.bloodPressureDiastolic, today, 76),
        daily(ActivityMetric.oxygenSaturation, today, 0.97),
      ],
    );
    await pumpScreen(tester, const DailyActivityScreen(), store: store);
    expect(find.text('生命徵象'), findsNothing, reason: 'not what it did');
    await disposeTree(tester);

    await pumpScreen(tester, const VitalsScreen(), store: store);
    expect(find.text('118/76 mmHg'), findsOneWidget);
    expect(find.text('生命徵象'), findsOneWidget);
    expect(find.text('收縮壓'), findsNothing, reason: 'one reading, one row');
    expect(find.text('97%'), findsOneWidget, reason: 'a fraction as %');
    await disposeTree(tester);
  });

  testWidgets('a vital taken today or a resting heart rate shows on Today, '
      'a watch\'s oxygen alone not', (tester) async {
    usePhoneViewport(tester);
    var store = storeWith(
      (today) => [daily(ActivityMetric.oxygenSaturation, today, 0.97)],
    );
    await pumpScreen(tester, const TodayScreen(), store: store);
    expect(find.byType(VitalsCard), findsNothing);
    await disposeTree(tester);

    // Every section kept: what the watch read shows, not "none".
    TodayViewModel(store.backend)
      ..setShowsOnlyWithData(false)
      ..dispose();
    await pumpScreen(tester, const TodayScreen(), store: store);
    await tester.scrollUntilVisible(
      find.byType(VitalsCard),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('97%'), findsOneWidget);
    await disposeTree(tester);

    store = storeWith(
      (today) => [
        daily(ActivityMetric.bloodPressureSystolic, today, 118),
        daily(ActivityMetric.bloodPressureDiastolic, today, 76),
        daily(ActivityMetric.oxygenSaturation, today, 0.97),
      ],
    );
    await pumpScreen(tester, const TodayScreen(), store: store);
    await tester.scrollUntilVisible(
      find.byType(VitalsCard),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('118/76 mmHg'), findsOneWidget);
    await disposeTree(tester);

    // A watch's resting heart rate is the day's one figure, as steps are.
    store = storeWith(
      (today) => [daily(ActivityMetric.restingHeartRate, today, 58)],
    );
    await pumpScreen(tester, const TodayScreen(), store: store);
    await tester.scrollUntilVisible(
      find.byType(VitalsCard),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('心臟與生命徵象'), findsOneWidget);
    expect(find.text('58 次/分'), findsOneWidget);
    await tester.tap(find.byType(VitalsCard));
    await tester.pumpAndSettle();
    expect(find.byType(VitalsScreen), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('mindful minutes are counted like exercise minutes', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = storeWith(
      (today) => [
        at(ActivityMetric.steps, today, 9, 5000),
        at(ActivityMetric.mindfulTime, today, 7, 10),
        at(ActivityMetric.mindfulTime, today, 21, 5),
      ],
    );
    await pumpScreen(tester, const DailyActivityScreen(), store: store);

    await tester.scrollUntilVisible(
      find.text('正念時間'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('15', findRichText: true), findsWidgets, reason: 'summed');
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
    expect(find.text('6 個月'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('a vital is set against the user\'s own usual range', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = storeWith(
      (today) => [
        for (var back = 0; back < 20; back++)
          ActivitySample(
            metric: ActivityMetric.respiratoryRate,
            start: DateTime(today.year, today.month, today.day - back),
            end: DateTime(today.year, today.month, today.day - back, 1),
            value: 14 + back % 3,
          ),
      ],
    );
    await pumpScreen(
      tester,
      ActivityMetricScreen(
        metric: ActivityMetric.respiratoryRate,
        day: store.now(),
      ),
      store: store,
    );
    await tester.tap(find.text('月'));
    await tester.pump();

    expect(find.text('平常範圍'), findsWidgets);
    expect(
      tester.widget<Sparkline>(find.byType(Sparkline)).color,
      AppColors.breathing,
      reason: 'breathing is drawn in the colour Apple Health gives it',
    );
    final bands = tester.widget<Sparkline>(find.byType(Sparkline)).bands!;
    expect(
      bands.last,
      isNotNull,
      reason: 'today read against the 19 days before it',
    );
    expect(
      bands.first,
      isNull,
      reason: 'the first day shown has no weeks before it on record',
    );
    expect(find.textContaining('天在平常範圍內'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('days that reached the chosen step goal carry a check', (
    tester,
  ) async {
    usePhoneViewport(tester);
    // Six finished days and today, alternately under and over 8,000.
    final store = storeWith(
      (today) => [
        for (var back = 6; back >= 0; back--)
          ActivitySample(
            metric: ActivityMetric.steps,
            start: DateTime(today.year, today.month, today.day - back, 10),
            end: DateTime(today.year, today.month, today.day - back, 11),
            value: back.isEven ? 9000 : 4000,
          ),
      ],
    );
    store.backend.activity.setStepGoal(8000);
    await pumpScreen(
      tester,
      ActivityMetricScreen(metric: ActivityMetric.steps, day: store.now()),
      store: store,
    );
    await tester.tap(find.text('週'));
    await tester.pump();

    final chart = tester.widget<MiniBarChart>(find.byType(MiniBarChart));
    expect(chart.goal, 80000, reason: "in the bars' tenths");
    expect(chart.met, {0, 2, 4, 6});
    expect(find.text('6 天中 3 天'), findsOneWidget, reason: 'finished days');
    expect(find.text('8,000 步'), findsOneWidget);

    store.backend.activity.setStepGoal(null);
    await tester.pump();
    expect(tester.widget<MiniBarChart>(find.byType(MiniBarChart)).goal, isNull);
    expect(find.text('未設定'), findsOneWidget);
    await disposeTree(tester);
  });
}
