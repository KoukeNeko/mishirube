import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/goal/goal_view_model.dart';

import '../../support/harness.dart';

void main() {
  late Backend backend;
  late GoalViewModel goal;

  setUp(() {
    backend = Backend.inMemory(clock: FakeClock().now);
    goal = GoalViewModel(backend);
  });

  tearDown(() {
    goal.dispose();
    backend.close();
  });

  test('setting, pausing and turning off each rebuild the goal', () {
    var notified = 0;
    goal.addListener(() => notified++);

    goal.setGoal(4, applyThisWeek: true);
    expect(goal.isEnabled, isTrue);
    expect(goal.overview.thisWeek.targetDays, 4);

    goal.pause();
    expect(goal.overview.isPaused, isTrue);
    goal.resume();
    expect(goal.overview.isPaused, isFalse);

    goal.setEnabled(false);
    expect(goal.isEnabled, isFalse);
    expect(notified, greaterThanOrEqualTo(4), reason: 'one per write');
  });

  test('a workout logged elsewhere counts toward this week', () {
    goal.setGoal(3, applyThisWeek: true);
    final before = goal.overview.thisWeek.activeDays;
    backend.activity.log(
      type: ActivityTypes.running,
      startedAt: goal.now().subtract(const Duration(minutes: 40)),
      duration: const Duration(minutes: 30),
    );
    expect(goal.overview.thisWeek.activeDays, before + 1);
  });
}
