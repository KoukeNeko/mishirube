import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../backend/engines/nutrition_summary.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';

const _weekDotSize = 28.0;

/// The week, Monday to Sunday: a check on each day something was trained
/// or done, today marked with its date, days to come left open.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.days,
    required this.today,
    this.onTap,
  });

  /// Each day of the week with whether anything was done on it.
  final List<(DateTime, bool)> days;
  final DateTime today;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          for (final (day, isActive) in days)
            Expanded(
              child: Semantics(
                label:
                    '週${weekdayLabel(day)}'
                    '${isActive ? '，有訓練或運動' : ''}',
                excludeSemantics: true,
                child: Column(
                  children: [
                    Text(weekdayLabel(day), style: AppTextStyles.caption),
                    const SizedBox(height: AppSpacing.xs),
                    _WeekDot(
                      day: day,
                      isToday: day == today,
                      isActive: isActive,
                      isFuture: day.isAfter(today),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WeekDot extends StatelessWidget {
  const _WeekDot({
    required this.day,
    required this.isToday,
    required this.isActive,
    required this.isFuture,
  });

  final DateTime day;
  final bool isToday;
  final bool isActive;
  final bool isFuture;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _weekDotSize,
      height: _weekDotSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isToday
            ? AppColors.training
            : isActive
            ? AppColors.trainingSurface
            : isFuture
            ? Colors.transparent
            : AppColors.surfaceRaised,
        border: Border.all(
          color: isActive
              ? AppColors.trainingDim
              : isFuture
              ? AppColors.outline
              : Colors.transparent,
        ),
      ),
      child: isToday
          ? Text(
              '${day.day}',
              style: const TextStyle(
                color: AppColors.onTraining,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            )
          : isActive
          ? const Icon(Icons.check, size: 16, color: AppColors.training)
          : null,
    );
  }
}

/// Small label pair used at the top of every "接下來" card.
class CardEyebrow extends StatelessWidget {
  const CardEyebrow({
    super.key,
    required this.label,
    required this.color,
    this.trailing,
  });

  final String label;
  final Color color;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const Spacer(),
        if (trailing != null) Text(trailing!, style: AppTextStyles.caption),
      ],
    );
  }
}

/// One of the day's figures: its category, the value or 沒有紀錄, and
/// underneath an optional small picture of it and a caption. Tiles in a
/// row are stretched to one height, so the pictures and captions line up.
class QuickStatTile extends StatelessWidget {
  const QuickStatTile({
    super.key,
    required this.category,
    required this.color,
    required this.value,
    this.unit,
    this.caption,
    this.visual,
    this.onTap,
  });

  final String category;
  final Color color;

  /// Null when nothing is recorded.
  final String? value;
  final String? unit;
  final String? caption;

  /// A progress line or sparkline, drawn in [color].
  final Widget? visual;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CategoryLabel(label: category, color: color),
          const SizedBox(height: AppSpacing.xs),
          if (value == null)
            const Text('沒有紀錄', style: AppTextStyles.caption)
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: ValueWithUnit(
                value: value,
                unit: unit,
                style: AppTextStyles.bigNumber.copyWith(fontSize: 26),
              ),
            ),
          const Spacer(),
          if (visual case final visual?) ...[
            const SizedBox(height: AppSpacing.xs),
            visual,
          ],
          if (caption case final caption?) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              caption,
              style: AppTextStyles.caption.copyWith(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// The meal the user usually logs about now, not yet logged today.
class NextMealCard extends StatelessWidget {
  const NextMealCard({super.key, required this.mealType, required this.onLog});

  final MealType mealType;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      tone: CardTone.nutrition,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardEyebrow(label: '下一步', color: AppColors.nutrition),
          const SizedBox(height: AppSpacing.xs),
          Text(mealType.label, style: AppTextStyles.pageTitle),
          const SizedBox(height: AppSpacing.md),
          NutritionButton(
            label: '記錄${mealType.label}',
            icon: Icons.search,
            onPressed: onLog,
          ),
        ],
      ),
    );
  }
}

class IntakeCard extends StatelessWidget {
  const IntakeCard({super.key, required this.store, required this.onTap});

  final AppStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final summary = store.todaySummary;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('今日攝取', style: AppTextStyles.overline),
              const Spacer(),
              if (summary.hasEstimates)
                const TagChip(label: '含估計值', tone: TagTone.nutrition),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '~${formatKcal(store.todayKcal)}',
                  style: AppTextStyles.bigNumber,
                ),
                TextSpan(
                  text: ' kcal · ${summary.mealCount} 餐',
                  style: AppTextStyles.caption.copyWith(fontSize: 15),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Four across when the names fit, else two by two: they are
          // written in full, and 碳水化合物 needs the room.
          LayoutBuilder(
            builder: (context, constraints) {
              const minMacroWidth = 72.0;
              final columns =
                  constraints.maxWidth >= 4 * minMacroWidth + 3 * AppSpacing.xs
                  ? 4
                  : 2;
              final width =
                  (constraints.maxWidth - AppSpacing.xs * (columns - 1)) /
                  columns;
              return Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final (label, grams, missing) in [
                    (
                      MacroLabel.protein,
                      summary.proteinGrams,
                      summary.mealsWithoutProtein,
                    ),
                    (
                      MacroLabel.carb,
                      summary.carbGrams,
                      summary.mealsWithoutCarb,
                    ),
                    (MacroLabel.fat, summary.fatGrams, summary.mealsWithoutFat),
                    (
                      MacroLabel.fibre,
                      summary.fibreGrams,
                      summary.mealsWithoutFibre,
                    ),
                  ])
                    SizedBox(
                      width: width,
                      child: _MacroTotal(
                        label: label,
                        grams: grams,
                        missing: missing,
                        records: summary.recordCount,
                      ),
                    ),
                ],
              );
            },
          ),
          if (_leftOut(summary) case final note?) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(note, style: AppTextStyles.caption),
          ],
        ],
      ),
    );
  }
}

/// `蛋白質、碳水化合物有紀錄沒有數字，未計入。`, or null when every
/// total is complete. A total that some records lacked is only what the
/// others add up to, and the tile would not say so on its own.
String? _leftOut(DaySummary summary) {
  bool partial(int missing) => missing > 0 && missing < summary.recordCount;
  final macros = [
    if (partial(summary.mealsWithoutProtein)) MacroLabel.protein,
    if (partial(summary.mealsWithoutCarb)) MacroLabel.carb,
    if (partial(summary.mealsWithoutFat)) MacroLabel.fat,
    if (partial(summary.mealsWithoutFibre)) MacroLabel.fibre,
  ];
  if (macros.isEmpty) return null;
  return '${macros.join('、')}有紀錄沒有數字，未計入。';
}

/// One macro's day total: what the records that carried the figure add
/// up to, or `—` when none did. Records without it are named under the
/// totals rather than marked on the number.
class _MacroTotal extends StatelessWidget {
  const _MacroTotal({
    required this.label,
    required this.grams,
    required this.missing,
    required this.records,
  });

  final String label;
  final int grams;

  /// Records in the day with no figure for this macro, out of [records].
  final int missing;
  final int records;

  @override
  Widget build(BuildContext context) {
    final isUnknown = missing == records && records > 0;
    return StatBlock(
      value: isUnknown ? '—' : '$grams',
      unit: isUnknown ? null : 'g',
      label: label,
      valueStyle: AppTextStyles.bigNumber.copyWith(fontSize: 20),
    );
  }
}

/// Today's finished workout, once there is nothing left to start.
class CompletedWorkoutCard extends StatelessWidget {
  const CompletedWorkoutCard({
    super.key,
    required this.workout,
    required this.onTap,
  });

  final WorkoutSession workout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final session = workout;
    final duration = formatClock(session.elapsedAt(session.finishedAt!));
    return AppCard(
      onTap: onTap,
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.training),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  '${session.routineName} 已完成',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.itemTitle,
                ),
              ),
              Text(
                duration,
                style: AppTextStyles.bigNumber.copyWith(fontSize: 22),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          StatRow(
            stats: [
              StatBlock(value: '${session.completedSets}', label: '總組數'),
              StatBlock(value: '${session.exercises.length}', label: '動作'),
              StatBlock(
                value:
                    '${AppStoreScope.of(context).workoutReview(session).records}',
                label: '個人紀錄',
                valueColor: AppColors.training,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Today's movement as the health platform counted it: the lead figure,
/// the other counted ones, and the lead hour by hour.
class TodayActivityCard extends StatelessWidget {
  const TodayActivityCard({
    super.key,
    required this.lead,
    required this.totals,
    required this.hours,
    required this.onTap,
  });

  final ActivityMetric lead;
  final Map<ActivityMetric, double> totals;
  final List<double> hours;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final others = [
      for (final metric in ActivityMetric.headline)
        if (metric != lead)
          if (totals[metric] case final value?)
            '${metric.format(value)} ${metric.unit}',
    ];
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CategoryLabel(label: '活動', color: AppColors.activity),
          const SizedBox(height: AppSpacing.xs),
          ValueWithUnit(
            value: lead.format(totals[lead]!),
            unit: lead.unit,
            style: AppTextStyles.bigNumber,
          ),
          if (others.isNotEmpty)
            Text(others.join(' · '), style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.sm),
          ExcludeSemantics(
            child: MiniBarChart(
              bars: [for (final value in hours) ('', value.round())],
              height: 32,
              showLabels: false,
              color: AppColors.activity,
              dimColor: AppColors.activity.withValues(alpha: 0.4),
              highlightsLast: false,
            ),
          ),
        ],
      ),
    );
  }
}
