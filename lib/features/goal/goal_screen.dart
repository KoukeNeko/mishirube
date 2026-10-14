import 'package:flutter/material.dart';

import '../../app/navigation.dart';
import '../../app/view_model.dart';
import '../../app/theme.dart';
import '../../backend/application/goal_service.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import 'goal_setup_sheet.dart';
import 'goal_view_model.dart';
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
      child: SegmentedGroup(
        rows: [
          [
            Segment(
              child: Padding(
                padding: segmentPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.weeklyGoalPrompt,
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PrimaryButton(
                      label: context.l10n.setWeeklyGoal,
                      onPressed: () => pushPage(
                        context,
                        GoalSetupScreen(overview: overview),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  ];

  List<Widget> _progress(
    BuildContext context,
    GoalOverview overview,
    DateTime today,
  ) {
    final l10n = context.l10n;
    final week = overview.thisWeek;
    return [
      Gutter(
        child: CategoryGroup(
          label: _headline(l10n, week),
          color: AppColors.training,
          children: [
            SegmentedGroup(
              rows: [
                [
                  Segment(
                    surface: AppColors.surfaceRaised,
                    semanticLabel: week.isPaused
                        ? l10n.thisWeekPaused
                        : l10n.thisWeekActiveDays(
                            active: week.activeDays,
                            target: week.targetDays,
                          ),
                    child: SegmentHero(
                      label: _detail(l10n, week),
                      color: week.isPaused
                          ? AppColors.textTertiary
                          : AppColors.training,
                      value: '${week.activeDays}',
                      unit: '/ ${week.targetDays}',
                      progress: week.isPaused || week.targetDays <= 0
                          ? null
                          : week.activeDays / week.targetDays,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      Gutter(
        child: CategoryGroup(
          label: l10n.streakSection,
          color: AppColors.training,
          children: [
            SegmentedGroup(
              rows: [
                [Segment(child: _streak(l10n, overview.streak))],
              ],
            ),
          ],
        ),
      ),
      Gutter(
        child: CategoryGroup(
          label: context.dates.month(today.month),
          color: AppColors.textSecondary,
          children: [
            SegmentedGroup(
              rows: [
                [
                  Segment(
                    child: Padding(
                      padding: segmentPadding,
                      child: _GoalMonth(
                        month: today,
                        today: today,
                        overview: overview,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ];
  }

  /// The run of weeks met. Nothing to keep alive yet, and nothing lost
  /// either.
  Widget _streak(AppLocalizations l10n, StreakSummary streak) {
    Widget fire(Color tint) =>
        Icon(Icons.local_fire_department, size: 16, color: tint);
    if (!streak.hasRun) {
      return SegmentStat(
        label: streak.previous > 0
            ? l10n.lastStreak(previous: streak.previous, best: streak.best)
            : l10n.streakStartsAfterGoal,
        color: AppColors.training,
        mark: fire,
        placeholder: streak.previous > 0
            ? l10n.streakRestartsThisWeek
            : l10n.noStreakYet,
      );
    }
    return SegmentStat(
      label: streak.isThisWeekPending
          ? l10n.streakPendingBest(best: streak.best)
          : l10n.streakBest(best: streak.best),
      color: AppColors.training,
      mark: fire,
      placeholder: '—',
      value: l10n.streakWeeks(count: streak.current),
    );
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
