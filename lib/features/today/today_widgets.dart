import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../backend/engines/nutrition_summary.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../../l10n/l10n.dart';

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
                label: isActive
                    ? context.l10n.weekdayActive(
                        weekday: context.dates.weekdayName(day),
                      )
                    : context.dates.weekdayName(day),
                excludeSemantics: true,
                child: Column(
                  children: [
                    Text(
                      context.dates.weekday(day),
                      style: AppTextStyles.caption,
                    ),
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
    this.level,
    this.motion,
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

  /// How full the tile is drawn, 0–1 from the bottom, in [color]; null
  /// for no level.
  final double? level;

  /// How the device moves, for the level to answer as water would.
  final Stream<Offset>? motion;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CategoryLabel(label: category, color: color),
          const SizedBox(height: AppSpacing.xs),
          if (value == null)
            Text(context.l10n.noEntriesShort, style: AppTextStyles.caption)
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
    // The level reaches the card's edges, so the card pads nothing and
    // the content pads itself.
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: switch (level) {
        final level? => Stack(
          children: [
            Positioned.fill(
              child: LevelFill(level: level, color: color, motion: motion),
            ),
            content,
          ],
        ),
        null => content,
      },
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
          CardEyebrow(label: context.l10n.nextStep, color: AppColors.nutrition),
          const SizedBox(height: AppSpacing.xs),
          Text(mealType.labelIn(context.l10n), style: AppTextStyles.pageTitle),
          const SizedBox(height: AppSpacing.md),
          NutritionButton(
            label: context.l10n.logItem(item: mealType.labelIn(context.l10n)),
            icon: Icons.search,
            onPressed: onLog,
          ),
        ],
      ),
    );
  }
}

class IntakeCard extends StatelessWidget {
  const IntakeCard({
    super.key,
    required this.store,
    required this.kcalTarget,
    required this.onTap,
  });

  final AppStore store;

  /// What the day's energy is set against; null draws no bar.
  final double? kcalTarget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final summary = store.todaySummary;
    final convention = store.backend.nutrition.convention;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryLabel(
                label: context.l10n.moduleNutrition,
                color: AppColors.nutrition,
              ),
              const Spacer(),
              if (summary.hasEstimates)
                TagChip(
                  label: context.l10n.includesEstimates,
                  tone: TagTone.nutrition,
                ),
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
                  text:
                      '${kcalTarget == null ? '' : ' / ${formatKcal(kcalTarget!)}'}'
                      ' kcal · ${context.l10n.mealsCount(count: summary.mealCount)}',
                  style: AppTextStyles.caption.copyWith(fontSize: 15),
                ),
              ],
            ),
          ),
          if (kcalTarget case final target? when target > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            ProgressLine(
              progress: store.todayKcal / target,
              color: AppColors.nutrition,
              height: 6,
            ),
          ],
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
                      convention.proteinName(context.l10n),
                      summary.proteinGrams,
                      summary.mealsWithoutProtein,
                    ),
                    (
                      convention.carbName(context.l10n),
                      convention.countsAvailableCarb
                          ? summary.availableCarbGrams
                          : summary.carbGrams,
                      convention.countsAvailableCarb
                          ? summary.mealsWithoutAvailableCarb
                          : summary.mealsWithoutCarb,
                    ),
                    (
                      convention.fatName(context.l10n),
                      summary.fatGrams,
                      summary.mealsWithoutFat,
                    ),
                    (
                      convention.fibreName(context.l10n),
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
          if (_leftOut(context.l10n, summary, convention) case final note?) ...[
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
String? _leftOut(
  AppLocalizations l10n,
  DaySummary summary,
  NutritionConvention convention,
) {
  bool partial(int missing) => missing > 0 && missing < summary.recordCount;
  final macros = [
    if (partial(summary.mealsWithoutProtein)) convention.proteinName(l10n),
    if (partial(
      convention.countsAvailableCarb
          ? summary.mealsWithoutAvailableCarb
          : summary.mealsWithoutCarb,
    ))
      convention.carbName(l10n),
    if (partial(summary.mealsWithoutFat)) convention.fatName(l10n),
    if (partial(summary.mealsWithoutFibre)) convention.fibreName(l10n),
  ];
  if (macros.isEmpty) return null;
  return l10n.partialMacros(macros: joinList(l10n, macros));
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
  final double grams;

  /// Records in the day with no figure for this macro, out of [records].
  final int missing;
  final int records;

  @override
  Widget build(BuildContext context) {
    final isUnknown = missing == records && records > 0;
    return StatBlock(
      value: isUnknown ? '—' : formatAmount(grams),
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
                  context.l10n.routineCompleted(name: session.routineName),
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
              StatBlock(
                value: '${session.completedSets}',
                label: context.l10n.totalSets,
              ),
              StatBlock(
                value: '${session.exercises.length}',
                label: context.l10n.exercisesLabel,
              ),
              StatBlock(
                value:
                    '${AppStoreScope.of(context).workoutReview(session).records}',
                label: context.l10n.personalRecords,
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
            withUnit(metric.format(value), metric.unitIn(context.l10n)),
    ];
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CategoryLabel(
            label: context.l10n.dailyActivityTitle,
            color: AppColors.activity,
          ),
          const SizedBox(height: AppSpacing.xs),
          ValueWithUnit(
            value: lead.format(totals[lead]!),
            unit: lead.unitIn(context.l10n),
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

/// Today's resting heart rate and vitals as recorded: blood pressure as
/// its pair, the others each at the day's figure beside their week, at
/// most three in a fixed order and a count of the rest. Nothing is
/// called normal, high or low, and no colour says so; the order never
/// follows how far a figure is from usual, which would be a judgement.
class VitalsCard extends StatelessWidget {
  const VitalsCard({
    super.key,
    required this.vitals,
    required this.weekOf,
    required this.onTap,
  });

  final Map<ActivityMetric, double> vitals;

  /// A reading's week, drawn small beside its figure; blood pressure's
  /// is asked for by its systolic figure.
  final Widget Function(ActivityMetric metric) weekOf;
  final VoidCallback onTap;

  static const _shown = 3;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String figure(ActivityMetric metric) =>
        withUnit(metric.format(vitals[metric]!), metric.unitIn(l10n));
    final day = DateTime(0);
    final rows = <(String, String, ActivityMetric)>[
      if (vitals.containsKey(ActivityMetric.restingHeartRate))
        (
          ActivityMetric.restingHeartRate.labelIn(l10n),
          figure(ActivityMetric.restingHeartRate),
          ActivityMetric.restingHeartRate,
        ),
      if (bloodPressureOf({
            for (final MapEntry(key: metric, value: value) in vitals.entries)
              metric: (day, value),
          })
          case final pressure?)
        (
          l10n.vitalBloodPressure,
          pressure,
          ActivityMetric.bloodPressureSystolic,
        ),
      for (final metric in [
        ActivityMetric.bodyTemperature,
        ActivityMetric.oxygenSaturation,
        ActivityMetric.respiratoryRate,
      ])
        if (vitals.containsKey(metric))
          (metric.labelIn(l10n), figure(metric), metric),
    ];
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CategoryLabel(label: l10n.vitalsTitle, color: AppColors.heart),
          for (final (label, value, metric) in rows.take(_shown)) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(child: Text(label, style: AppTextStyles.body)),
                weekOf(metric),
                const SizedBox(width: AppSpacing.sm),
                Text(value, style: AppTextStyles.itemTitle),
              ],
            ),
          ],
          if (rows.length > _shown) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.moreItemsCount(count: rows.length - _shown),
              style: AppTextStyles.caption,
            ),
          ],
        ],
      ),
    );
  }
}

/// A section of Today with nothing to show today, kept in its place
/// when sections are shown whether or not they have figures. It still
/// opens the section's own page, where the day can be logged or read.
class EmptySectionCard extends StatelessWidget {
  const EmptySectionCard({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    child: Row(
      children: [
        CategoryLabel(label: label, color: color),
        const Spacer(),
        Text(context.l10n.noEntriesShort, style: AppTextStyles.caption),
      ],
    ),
  );
}
