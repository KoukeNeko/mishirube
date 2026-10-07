import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/engines/training_metrics.dart';
import 'package:mishirube/features/trends/insight_detail_screen.dart';
import 'package:mishirube/features/trends/volume_records_screen.dart';
import 'package:mishirube/features/training/workout_summary_screen.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

import '../../support/harness.dart';

void main() {
  testWidgets(
    'the raw records are the sessions behind the report, not the log',
    (tester) async {
      usePhoneViewport(tester);
      final store = AppStore(clock: FakeClock().now, isOnboarded: true);
      final report = store.backend.insights.volumeReport()!;
      final latest = store.backend.insights
          .volumeSessions(report.exercise.id, from: report.from)
          .first;
      await pumpScreen(tester, const InsightDetailScreen(), store: store);

      await tester.scrollUntilVisible(find.text('查看這段期間的原始紀錄'), 300);
      await tester.tap(find.text('查看這段期間的原始紀錄'));
      await tester.pumpAndSettle();

      expect(find.byType(VolumeRecordsScreen), findsOneWidget);
      expect(
        store.selectedTab,
        HomeTab.today,
        reason: 'the tab is not switched',
      );
      expect(find.text(report.exercise.name), findsWidgets);
      expect(
        find.textContaining('${latest.date.month} 月 ${latest.date.day} 日'),
        findsWidgets,
        reason: 'the latest session leads',
      );
      expect(
        find.text('${countedSets(latest.sets).length} 組'),
        findsWidgets,
        reason: 'what it adds to the weekly sets',
      );

      await tester.tap(find.byType(NavRow).first);
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutSummaryScreen), findsOneWidget);
      await disposeTree(tester);
    },
  );
}
