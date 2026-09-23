import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../backend/engines/nutrition_summary.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';

const _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];
const _trainedWeekdays = {1, 3};
const _todayWeekdayIndex = 5;
const _todayDayOfMonth = 19;
const _weekDotSize = 34.0;

/// Mon–Sun strip: checks for trained days, today highlighted.
class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          for (var i = 0; i < _weekdayLabels.length; i++)
            Expanded(
              child: Column(
                children: [
                  Text(_weekdayLabels[i], style: AppTextStyles.caption),
                  const SizedBox(height: AppSpacing.xs),
                  _WeekDot(dayIndex: i),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WeekDot extends StatelessWidget {
  const _WeekDot({required this.dayIndex});

  final int dayIndex;

  @override
  Widget build(BuildContext context) {
    final isToday = dayIndex == _todayWeekdayIndex;
    final isTrained = _trainedWeekdays.contains(dayIndex);
    final isFuture = dayIndex > _todayWeekdayIndex;
    return Container(
      width: _weekDotSize,
      height: _weekDotSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isToday
            ? AppColors.training
            : isTrained
            ? AppColors.trainingSurface
            : isFuture
            ? Colors.transparent
            : AppColors.surfaceRaised,
        border: Border.all(
          color: isTrained
              ? AppColors.trainingDim
              : isFuture
              ? AppColors.outline
              : Colors.transparent,
        ),
      ),
      child: isToday
          ? const Text(
              '$_todayDayOfMonth',
              style: TextStyle(
                color: AppColors.onTraining,
                fontWeight: FontWeight.w800,
              ),
            )
          : isTrained
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
            label: '接下來',
            color: AppColors.training,
            trailing: '約 ${routine.estimatedMinutes} 分',
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

class QuickActionTile extends StatelessWidget {
  const QuickActionTile({
    super.key,
    required this.category,
    required this.color,
    required this.action,
    required this.caption,
    required this.onTap,
  });

  final String category;
  final Color color;
  final String action;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CategoryLabel(label: category, color: color),
          const SizedBox(height: AppSpacing.sm),
          Text(
            action,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
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

class NextMealCard extends StatelessWidget {
  const NextMealCard({super.key, required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      tone: CardTone.nutrition,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardEyebrow(
            label: '接下來',
            color: AppColors.nutrition,
            trailing: '約 12:30',
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text('記錄午餐', style: AppTextStyles.cardTitle),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _MealMethodButton(
                icon: Icons.search,
                label: '搜尋',
                isPrimary: true,
                onTap: onSearch,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MealMethodButton extends StatelessWidget {
  const _MealMethodButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final foreground = isPrimary ? AppColors.onTraining : AppColors.nutrition;
    return Expanded(
      child: Material(
        color: isPrimary
            ? AppColors.nutrition
            : AppColors.nutrition.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.small + 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.small + 4),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Column(
              children: [
                Icon(icon, color: foreground),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  style: TextStyle(
                    color: isPrimary
                        ? AppColors.onTraining
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
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
    final pendingMeals = store.isLunchLogged ? '晚餐未記錄' : '午餐與晚餐未記錄';
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
          Row(
            children: [
              _MacroTile(
                label: '蛋白質',
                grams: summary.proteinGrams,
                missing: summary.mealsWithoutProtein,
                records: summary.recordCount,
              ),
              const SizedBox(width: AppSpacing.xs),
              _MacroTile(
                label: '碳水',
                grams: summary.carbGrams,
                missing: summary.mealsWithoutCarb,
                records: summary.recordCount,
              ),
              const SizedBox(width: AppSpacing.xs),
              _MacroTile(
                label: '脂肪',
                grams: summary.fatGrams,
                missing: summary.mealsWithoutFat,
                records: summary.recordCount,
              ),
              const SizedBox(width: AppSpacing.xs),
              _MacroTile(
                label: '纖維',
                grams: summary.fibreGrams,
                missing: summary.mealsWithoutFibre,
                records: summary.recordCount,
              ),
            ],
          ),
          if (_leftOut(summary) case final note?) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(note, style: AppTextStyles.caption),
          ],
          const Divider(height: AppSpacing.xxl),
          Text(
            store.isLunchLogged
                ? '早餐、午餐已確認 · $pendingMeals'
                : '早餐已確認 · $pendingMeals',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

/// `蛋白質、碳水有 1 筆紀錄沒有數字，未計入。`, or null when every
/// total is complete. A total that some records lacked is only what the
/// others add up to, and the tile would not say so on its own.
String? _leftOut(DaySummary summary) {
  bool partial(int missing) => missing > 0 && missing < summary.recordCount;
  final macros = [
    if (partial(summary.mealsWithoutProtein)) '蛋白質',
    if (partial(summary.mealsWithoutCarb)) '碳水',
    if (partial(summary.mealsWithoutFat)) '脂肪',
    if (partial(summary.mealsWithoutFibre)) '纖維',
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
class NextActionCard extends StatelessWidget {
  const NextActionCard({
    super.key,
    required this.title,
    required this.message,
    required this.onTap,
  });

  final String title;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      tone: CardTone.nutrition,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardEyebrow(label: '接下來', color: AppColors.nutrition),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: AppTextStyles.cardTitle),
          const SizedBox(height: AppSpacing.xxs),
          Text(message, style: AppTextStyles.caption.copyWith(fontSize: 14)),
          const SizedBox(height: AppSpacing.md),
          NutritionButton(label: '搜尋', icon: Icons.search, onPressed: onTap),
        ],
      ),
    );
  }
}

class CompletedWorkoutCard extends StatelessWidget {
  const CompletedWorkoutCard({
    super.key,
    required this.workout,
    required this.onTap,
  });

  /// Falls back to the design's sample numbers when no workout ran yet.
  final WorkoutSession? workout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final session = workout;
    final duration = session == null
        ? '58:02'
        : formatClock(session.elapsedAt(session.finishedAt!));
    return AppCard(
      onTap: onTap,
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.training),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${session?.routineName ?? '下肢 A'} 已完成',
                style: AppTextStyles.itemTitle,
              ),
              const Spacer(),
              Text(
                duration,
                style: AppTextStyles.bigNumber.copyWith(fontSize: 22),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          StatRow(
            stats: [
              StatBlock(value: '${session?.completedSets ?? 16}', label: '總組數'),
              StatBlock(
                value: '${session?.exercises.length ?? 5}',
                label: '動作',
              ),
              StatBlock(
                value: '${session?.personalRecords ?? 1}',
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
