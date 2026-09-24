import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../backend/engines/nutrition_summary.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';

const _weekDotSize = 34.0;

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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
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
                fontWeight: FontWeight.w800,
              ),
            )
          : isActive
          ? const Icon(Icons.check, size: 18, color: AppColors.training)
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

class NextWorkoutCard extends StatelessWidget {
  const NextWorkoutCard({
    super.key,
    required this.routine,
    required this.onStart,
    required this.onOpenRoutine,
  });

  final Routine routine;
  final VoidCallback onStart;
  final VoidCallback onOpenRoutine;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      tone: CardTone.training,
      onTap: onOpenRoutine,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardEyebrow(
            label: '下一步',
            color: AppColors.training,
            trailing:
                '約 ${AppStoreScope.of(context).expectedMinutes(routine)} 分',
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(routine.name, style: AppTextStyles.cardTitle),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${routine.lastCompletedLabel} · ${routine.exercises.length} 個動作'
            ' · ${routine.totalSets} 組',
            style: AppTextStyles.caption.copyWith(fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: '開始訓練',
            icon: Icons.play_arrow_outlined,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}

class QuickStatTile extends StatelessWidget {
  const QuickStatTile({
    super.key,
    required this.category,
    required this.color,
    required this.value,
    required this.caption,
    this.unit,
    this.onTap,
  });

  final String category;
  final Color color;
  final String value;
  final String? unit;
  final String caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CategoryLabel(label: category, color: color),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: ValueWithUnit(value: value, unit: unit),
          ),
          Text(
            caption,
            style: AppTextStyles.caption.copyWith(fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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
          const SizedBox(height: AppSpacing.sm),
          Text('記錄${mealType.label}', style: AppTextStyles.cardTitle),
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
          const SizedBox(height: AppSpacing.sm),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '~${formatKcal(store.todayKcal)}',
                  style: AppTextStyles.hugeNumber,
                ),
                TextSpan(
                  text: ' kcal · ${summary.mealCount} 餐',
                  style: AppTextStyles.caption.copyWith(fontSize: 15),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Two by two: the names are written in full, and four across a
          // phone leaves too little room for 碳水化合物.
          for (final (index, pair) in [
            [
              (
                MacroLabel.protein,
                summary.proteinGrams,
                summary.mealsWithoutProtein,
              ),
              (MacroLabel.carb, summary.carbGrams, summary.mealsWithoutCarb),
            ],
            [
              (MacroLabel.fat, summary.fatGrams, summary.mealsWithoutFat),
              (MacroLabel.fibre, summary.fibreGrams, summary.mealsWithoutFibre),
            ],
          ].indexed) ...[
            if (index > 0) const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                for (final (i, (label, grams, missing)) in pair.indexed) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.xs),
                  _MacroTile(
                    label: label,
                    grams: grams,
                    missing: missing,
                    records: summary.recordCount,
                  ),
                ],
              ],
            ),
          ],
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
/// tiles rather than marked on the number.
class _MacroTile extends StatelessWidget {
  const _MacroTile({
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

  String get _value => missing == records && records > 0 ? '—' : '$grams';

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        tone: CardTone.raised,
        radius: AppRadius.small,
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: StatBlock(
          value: _value,
          unit: missing == records && records > 0 ? null : 'g',
          label: label,
          valueStyle: AppTextStyles.bigNumber.copyWith(fontSize: 22),
        ),
      ),
    );
  }
}

/// Generic nutrition "接下來" card with one big orange button.
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
