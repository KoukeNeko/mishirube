import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../shared/haptics.dart';
import 'goal_screen.dart';
import 'weekly_goal_ring.dart';

const _ringSize = 34.0;
const _ringStroke = 3.0;

/// The way into the weekly goal, in the toolbar's leading corner. It
/// shows how far this week has got rather than a streak number: the
/// useful thing today is what is left, not what might be lost.
class GoalEntryButton extends StatelessWidget {
  const GoalEntryButton({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    if (!store.isGoalEnabled) return const SizedBox.shrink();
    final week = store.goalOverview.thisWeek;
    return Semantics(
      button: true,
      label: week.isPaused
          ? '每週目標已暫停'
          : '本週 ${week.activeDays} / ${week.targetDays} 個運動日，查看每週目標',
      excludeSemantics: true,
      child: Tooltip(
        message: '每週目標',
        excludeFromSemantics: true,
        child: InkResponse(
          onTap: () {
            AppHaptics.tap();
            pushPage(context, const GoalScreen());
          },
          radius: _ringSize,
          child: WeeklyGoalRing(
            value: week.activeDays,
            target: week.targetDays,
            isPaused: week.isPaused,
            size: _ringSize,
            strokeWidth: _ringStroke,
            child: Icon(
              Icons.local_fire_department,
              size: 16,
              color: week.isMet ? AppColors.training : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
