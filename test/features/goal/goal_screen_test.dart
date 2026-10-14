import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/features/goal/goal_screen.dart';
import 'package:mishirube/features/goal/goal_setup_sheet.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

import '../../support/harness.dart';

void main() {
  AppStore newStore() {
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    store.backend.provenance.setShowsDemo(false);
    return store;
  }

  testWidgets('this week is one figure against its goal, with a bar', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = newStore()..backend.goal.setGoal(3, applyThisWeek: true);
    await pumpScreen(tester, const GoalScreen(), store: store);

    final hero = tester.widget<SegmentHero>(find.byType(SegmentHero));
    expect(hero.value, '0');
    expect(hero.unit, '/ 3');
    expect(hero.progress, 0);
    expect(find.text('本週運動'), findsOneWidget, reason: 'the category');
    await disposeTree(tester);
  });

  testWidgets('a week with its days done fills the bar', (tester) async {
    usePhoneViewport(tester);
    final store = newStore()
      ..backend.goal.setGoal(1, applyThisWeek: true)
      ..startWorkout()
      ..completeNextSet()
      ..finishWorkout();
    await pumpScreen(tester, const GoalScreen(), store: store);

    final hero = tester.widget<SegmentHero>(find.byType(SegmentHero));
    expect(hero.value, '1');
    expect(hero.progress, 1);
    expect(find.text('本週目標已完成'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('without a streak the page says so, and a goal is set from it', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = newStore()..backend.goal.setGoal(3, applyThisWeek: true);
    await pumpScreen(tester, const GoalScreen(), store: store);

    expect(find.text('連續達標'), findsOneWidget);
    expect(find.byType(SegmentStat), findsOneWidget);
    await disposeTree(tester);

    await pumpScreen(tester, const GoalScreen(), store: newStore());
    await tester.tap(find.text('設定每週目標'));
    await tester.pumpAndSettle();
    expect(find.byType(GoalSetupScreen), findsOneWidget);
    await disposeTree(tester);
  });
}
