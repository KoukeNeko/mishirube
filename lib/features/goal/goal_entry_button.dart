import 'package:flutter/material.dart';

import '../../app/navigation.dart';
import '../../app/view_model.dart';
import '../../app/theme.dart';
import '../../shared/haptics.dart';
import 'goal_screen.dart';
import 'goal_view_model.dart';
import 'weekly_goal_ring.dart';
import '../../l10n/l10n.dart';

const _ringSize = 34.0;
const _ringStroke = 3.0;

/// The way into the weekly goal, in the toolbar's leading corner. It
/// shows how far this week has got rather than a streak number: the
/// useful thing today is what is left, not what might be lost.
class GoalEntryButton extends StatelessWidget {
  const GoalEntryButton({super.key});

  @override
  Widget build(BuildContext context) => ViewModelBuilder(
    create: GoalViewModel.new,
    builder: (context, goal) => _button(context, goal),
  );

  Widget _button(BuildContext context, GoalViewModel goal) {
    if (!goal.isEnabled) return const SizedBox.shrink();
    final week = goal.overview.thisWeek;
    return Semantics(
      button: true,
      label: week.isPaused
          ? context.l10n.weeklyGoalPaused
          : context.l10n.weeklyGoalButtonLabel(
              active: week.activeDays,
              target: week.targetDays,
            ),
      excludeSemantics: true,
      child: Tooltip(
        message: context.l10n.weeklyGoal,
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
