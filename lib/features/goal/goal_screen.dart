import 'package:flutter/material.dart';

import '../../app/navigation.dart';
import '../../app/view_model.dart';
import '../../app/theme.dart';
import '../../backend/application/goal_service.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import 'goal_setup_sheet.dart';
import 'goal_view_model.dart';
import 'weekly_goal_ring.dart';
import '../../l10n/l10n.dart';

/// This week's rhythm, the run of weeks met, and the month behind it.
/// The order is deliberate: the week comes first, the streak second.
/// The goal is to move, not to keep a number alive.
class GoalScreen extends StatelessWidget {
  const GoalScreen({super.key});

  @override
  Widget build(BuildContext context) => ViewModelBuilder(
    create: GoalViewModel.new,
    builder: (context, goal) => _page(context, goal),
  );

  Widget _page(BuildContext context, GoalViewModel goal) {
    final overview = goal.overview;
    final today = goal.now();
    return DetailPage(
      appBar: PageAppBar(
        title: context.l10n.weeklyGoal,
        subtitle: overview.hasGoal
            ? context.l10n.activeDaysPerWeek(
                count: overview.thisWeek.targetDays,
              )
            : context.l10n.notSet,
        actions: [
          HeaderAction(
            icon: Icons.tune,
            semanticLabel: context.l10n.adjustWeeklyGoal,
            onTap: () => pushPage(context, GoalSetupScreen(overview: overview)),
          ),
        ],
      ),
      children: overview.hasGoal
          ? _progress(context, overview, today)
          : _setUp(context, overview),
    );
  }

  List<Widget> _setUp(BuildContext context, GoalOverview overview) => [
    Gutter(
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.weeklyGoalPrompt, style: AppTextStyles.body),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: context.l10n.setWeeklyGoal,
              onPressed: () =>
                  pushPage(context, GoalSetupScreen(overview: overview)),
            ),
          ],
        ),
      ),
    ),
  ];

  List<Widget> _progress(
    BuildContext context,
    GoalOverview overview,
    DateTime today,
  ) {
    final week = overview.thisWeek;
    final streak = overview.streak;
    return [
      Gutter(
        child: AppCard(
          child: Column(
            children: [
              WeeklyGoalRing(
                value: week.activeDays,
                target: week.targetDays,
                isPaused: week.isPaused,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${week.activeDays}',
                      style: AppTextStyles.hugeNumber.copyWith(
                        color: week.isMet
                            ? AppColors.training
                            : AppColors.textPrimary,
                      ),
                    ),
                    Text('/ ${week.targetDays}', style: AppTextStyles.caption),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _headline(context.l10n, week),
                style: AppTextStyles.cardTitle,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(_detail(context.l10n, week), style: AppTextStyles.caption),
            ],
          ),
        ),
      ),
      Gutter(child: SectionLabel(context.l10n.streakSection)),
      Gutter(child: _StreakCard(streak: streak)),
      Gutter(child: SectionLabel(context.dates.month(today.month))),
      Gutter(
        child: AppCard(
          child: _GoalMonth(month: today, today: today, overview: overview),
        ),
      ),
    ];
  }

  static String _headline(AppLocalizations l10n, WeekProgress week) {
    if (week.isPaused) return l10n.sessionPausedStatus;
    if (week.isMet) return l10n.weekGoalMet;
    return l10n.weekActivity;
  }

  static String _detail(AppLocalizations l10n, WeekProgress week) {
    if (week.isPaused) return l10n.notCountedInStreak;
    if (week.isMet) return l10n.activeDaysCount(count: week.activeDays);
    return l10n.activeDaysToGo(count: week.remaining);
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});

  final StreakSummary streak;

  @override
  Widget build(BuildContext context) {
    // Nothing to keep alive yet, and nothing lost either.
    if (!streak.hasRun) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              streak.previous > 0
                  ? context.l10n.streakRestartsThisWeek
                  : context.l10n.noStreakYet,
              style: AppTextStyles.cardTitle,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              streak.previous > 0
                  ? context.l10n.lastStreak(
                      previous: streak.previous,
                      best: streak.best,
                    )
                  : context.l10n.streakStartsAfterGoal,
              style: AppTextStyles.caption,
            ),
          ],
        ),
      );
    }
    return AppCard(
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department,
            color: AppColors.training,
            size: 28,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.streakWeeks(count: streak.current),
                  style: AppTextStyles.cardTitle,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  streak.isThisWeekPending
                      ? context.l10n.streakPendingBest(best: streak.best)
                      : context.l10n.streakBest(best: streak.best),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The month with a dot on the days something was done, and how each
/// week ended up in a column of its own.
class _GoalMonth extends StatelessWidget {
  const _GoalMonth({
    required this.month,
    required this.today,
    required this.overview,
  });

  final DateTime month;
  final DateTime today;
  final GoalOverview overview;

  WeekProgress? _weekOf(DateTime start) {
    for (final week in overview.weeks) {
      if (week.start == start) return week;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MonthGrid(
      month: month,
      dayBuilder: (context, day) {
        final date = DateTime(month.year, month.month, day);
        return _DayCell(
          day: day,
          isActive: overview.activeDays.contains(date),
          isToday: date == DateTime(today.year, today.month, today.day),
          isFuture: date.isAfter(today),
        );
      },
      weekTrailingBuilder: (context, start) =>
          _WeekResult(week: _weekOf(start)),
    );
  }
}

const _cellMinHeight = 44.0;
const _dotSize = 8.0;

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isActive,
    required this.isToday,
    required this.isFuture,
  });

  final int day;
  final bool isActive;
  final bool isToday;
  final bool isFuture;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isActive
          ? context.l10n.goalDayActive(day: day)
          : context.l10n.goalDayLabel(day: day),
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _cellMinHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: isToday ? Border.all(color: AppColors.training) : null,
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Text(
                  '$day',
                  style: TextStyle(
                    color: isFuture
                        ? AppColors.textTertiary
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            // Always as tall as a dot, so the dates line up.
            SizedBox(
              height: _dotSize,
              width: _dotSize,
              child: isActive
                  ? const DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.training,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// A week's result: met, still running, paused, or simply short — said
/// with a count rather than a verdict.
class _WeekResult extends StatelessWidget {
  const _WeekResult({required this.week});

  final WeekProgress? week;

  @override
  Widget build(BuildContext context) {
    final week = this.week;
    if (week == null) return const SizedBox.shrink();
    final (icon, color) = switch (week) {
      _ when week.isPaused => (
        Icons.pause_circle_outline,
        AppColors.textTertiary,
      ),
      _ when week.isMet => (Icons.local_fire_department, AppColors.training),
      _ => (null, AppColors.textTertiary),
    };
    return Semantics(
      label: week.isPaused
          ? context.l10n.sessionPausedStatus
          : context.l10n.activeDaysFraction(
              active: week.activeDays,
              target: week.targetDays,
            ),
      excludeSemantics: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null)
            Icon(icon, color: color, size: 18)
          else
            const SizedBox(height: 18),
          const SizedBox(height: 2),
          Text(
            week.isPaused
                ? context.l10n.commonPause
                : '${week.activeDays}/${week.targetDays}',
            style: AppTextStyles.caption.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
