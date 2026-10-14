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

/// The day's eating as pills under its name: the energy against its
/// target, filled from the left as far as it is reached and no further past
/// it, then the macros two by two. Any of them opens the day.
class IntakeCard extends StatelessWidget {
  const IntakeCard({
    super.key,
    required this.summary,
    required this.convention,
    required this.kcalTarget,
    required this.onTap,
    this.extra = const [],
  });

  /// What was eaten on the day.
  final DaySummary summary;
  final NutritionConvention convention;

  /// What the day's energy is set against; null draws no fill.
  final double? kcalTarget;
  final VoidCallback onTap;

  /// What else belongs to eating, under the totals: the water drunk.
  final List<Widget> extra;

  @override
  Widget build(BuildContext context) {
    final target = kcalTarget;
    final macros = [
      (
        convention.proteinName(context.l10n),
        summary.proteinGrams,
        summary.mealsWithoutProtein,
        AppColors.macroProtein,
      ),
      (
        convention.carbName(context.l10n),
        convention.countsAvailableCarb
            ? summary.availableCarbGrams
            : summary.carbGrams,
        convention.countsAvailableCarb
            ? summary.mealsWithoutAvailableCarb
            : summary.mealsWithoutCarb,
        AppColors.macroCarb,
      ),
      (
        convention.fatName(context.l10n),
        summary.fatGrams,
        summary.mealsWithoutFat,
        AppColors.macroFat,
      ),
      (
        convention.fibreName(context.l10n),
        summary.fibreGrams,
        summary.mealsWithoutFibre,
        AppColors.macroFibre,
      ),
    ];
    return PillGroup(
      label: context.l10n.moduleNutrition,
      color: AppColors.nutrition,
      tag: summary.hasEstimates
          ? TagChip(
              label: context.l10n.includesEstimates,
              tone: TagTone.nutrition,
            )
          : null,
      children: [
        PillTile(
          label: context.l10n.mealsCount(count: summary.mealCount),
          color: AppColors.nutrition,
          surface: AppColors.nutritionSurface,
          outline: AppColors.nutritionOutline,
          leading: const Icon(Icons.restaurant),
          placeholder: context.l10n.noEntriesShort,
          value: formatKcal(summary.kcal.roundToDouble()),
          unit: target == null ? 'kcal' : '/ ${formatKcal(target)} kcal',
          progress: switch (target) {
            final target? when target > 0 => summary.kcal / target,
            _ => null,
          },
          onTap: onTap,
        ),
        // Two across, one to a row where two do not fit.
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 260 ? 2 : 1;
            final width =
                (constraints.maxWidth - AppSpacing.xs * (columns - 1)) /
                columns;
            return Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final (label, grams, missing, color) in macros)
                  SizedBox(
                    width: width,
                    child: PillTile(
                      isCompact: true,
                      label: label,
                      color: AppColors.nutrition,
                      surface: AppColors.nutritionSurface,
                      outline: AppColors.nutritionOutline,
                      leading: DecoratedBox(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox.square(dimension: 8),
                      ),
                      placeholder: '—',
                      // Unknown when no record had the figure.
                      value:
                          missing == summary.recordCount &&
                              summary.recordCount > 0
                          ? null
                          : formatAmount(grams),
                      unit: 'g',
                      onTap: onTap,
                    ),
                  ),
              ],
            );
          },
        ),
        if (_leftOut(context.l10n, summary, convention) case final note?)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(note, style: AppTextStyles.caption),
          ),
        ...extra,
      ],
    );
  }
}

/// A category of Today: its name under a dot in its colour, and the pills
/// that belong to it, one gap apart so they read as one group.
class PillGroup extends StatelessWidget {
  const PillGroup({
    super.key,
    required this.label,
    required this.color,
    required this.children,
    this.tag,
  });

  final String label;
  final Color color;

  /// Beside the name, at the end.
  final Widget? tag;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xs,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            children: [
              CategoryLabel(label: label, color: color),
              const Spacer(),
              ?tag,
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}

/// Pills side by side, two across and as tall as the tallest; a last one
/// alone takes the row.
class PillRow extends StatelessWidget {
  const PillRow({super.key, required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: AppSpacing.xs,
      children: [
        for (var row = 0; row < tiles.length; row += 2)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.xs,
              children: [
                Expanded(child: tiles[row]),
                if (row + 1 < tiles.length) Expanded(child: tiles[row + 1]),
              ],
            ),
          ),
      ],
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

/// Resting heart rate and vitals, or the readings pinned to the card,
/// each beside its week: blood pressure as its pair, a reading from
/// before [today] with its date, at most three in a fixed order and a
/// count of the rest. Nothing is called normal, high or low, and no
/// colour says so; the order never follows how far a figure is from
/// usual, which would be a judgement.
class VitalsCard extends StatelessWidget {
  const VitalsCard({
    super.key,
    required this.readings,
    required this.today,
    required this.weekOf,
    required this.onTap,
  });

  /// Each reading's day and figure, in the card's order; blood pressure
  /// as its systolic and diastolic figures.
  final Map<ActivityMetric, (DateTime, double)> readings;

  /// Midnight today.
  final DateTime today;

  /// A reading's week up to [day], drawn small beside its figure; blood
  /// pressure's is asked for by its systolic figure.
  final Widget Function(ActivityMetric metric, DateTime day) weekOf;
  final VoidCallback onTap;

  static const _shown = 3;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rows = <(String, String, ActivityMetric, DateTime)>[
      for (final MapEntry(key: metric, value: (day, value)) in readings.entries)
        if (metric == ActivityMetric.bloodPressureSystolic)
          if (bloodPressureOf(readings) case final pressure?)
            (l10n.vitalBloodPressure, pressure, metric, day)
          else
            (
              l10n.vitalBloodPressure,
              withUnit(metric.format(value), metric.unitIn(l10n)),
              metric,
              day,
            )
        else if (metric != ActivityMetric.bloodPressureDiastolic)
          (
            metric.labelIn(l10n),
            withUnit(metric.format(value), metric.unitIn(l10n)),
            metric,
            day,
          ),
    ];
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CategoryLabel(label: l10n.vitalsTitle, color: AppColors.heart),
          for (final (label, value, metric, day) in rows.take(_shown)) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: AppTextStyles.body),
                      if (day.isBefore(today))
                        Text(
                          context.dates.monthDay(day),
                          style: AppTextStyles.caption,
                        ),
                    ],
                  ),
                ),
                weekOf(metric, day),
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
