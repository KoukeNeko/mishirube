import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/application/goal_service.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import 'goal_setup_sheet.dart';
import 'weekly_goal_ring.dart';

/// This week's rhythm, the run of weeks met, and the month behind it.
/// The order is deliberate: the week comes first, the streak second.
/// The goal is to move, not to keep a number alive.
class GoalScreen extends StatelessWidget {
  const GoalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final overview = store.goalOverview;
    final today = store.now();
    return DetailPage(
      appBar: PageAppBar(
        title: '每週目標',
        subtitle: overview.hasGoal
            ? '每週 ${overview.thisWeek.targetDays} 個運動日'
            : '還沒設定',
        actions: [
          HeaderAction(
            icon: Icons.tune,
            semanticLabel: '調整每週目標',
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
            const Text(
              '設定一週想要有幾個運動日。訓練與運動都算，同一天做幾件事都算一個運動日。',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: '設定每週目標',
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
              Text(_headline(week), style: AppTextStyles.cardTitle),
              const SizedBox(height: AppSpacing.xxs),
              Text(_detail(week), style: AppTextStyles.caption),
            ],
          ),
        ),
      ),
      Gutter(child: const SectionLabel('連續達標')),
      Gutter(child: _StreakCard(streak: streak)),
      Gutter(child: SectionLabel('${today.month} 月')),
      Gutter(
        child: AppCard(
          child: _GoalMonth(month: today, today: today, overview: overview),
        ),
      ),
      Gutter(
        child: const Text(
          '訓練與運動都算，同一天做幾件事都算一個運動日。',
          style: AppTextStyles.caption,
        ),
      ),
    ];
  }

  static String _headline(WeekProgress week) {
    if (week.isPaused) return '已暫停';
    if (week.isMet) return '本週目標已完成';
    return '本週運動';
  }

  static String _detail(WeekProgress week) {
    if (week.isPaused) return '這一週不會累積，也不會中斷連續達標';
    if (week.isMet) return '${week.activeDays} 個運動日';
    return '還差 ${week.remaining} 個運動日';
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
              streak.previous > 0 ? '本週重新開始' : '還沒有連續達標的紀錄',
              style: AppTextStyles.cardTitle,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              streak.previous > 0
                  ? '上次連續達標 ${streak.previous} 週，最佳 ${streak.best} 週'
                  : '達成一週目標後開始累積',
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
                  '連續達標 ${streak.current} 週',
                  style: AppTextStyles.cardTitle,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  streak.isThisWeekPending
                      ? '本週進行中 · 最佳 ${streak.best} 週'
                      : '最佳 ${streak.best} 週',
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
      label: '$day 日${isActive ? '，有運動' : ''}',
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
          ? '已暫停'
          : '${week.activeDays} / ${week.targetDays} 個運動日',
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
            week.isPaused ? '暫停' : '${week.activeDays}/${week.targetDays}',
            style: AppTextStyles.caption.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
