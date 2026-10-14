import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../backend/engines/nutrition_summary.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../../l10n/l10n.dart';

/// The week, Monday to Sunday, a segment to a day: a check on each day
/// something was trained or done, today marked with its date, days to
/// come quiet.
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
    return SegmentedGroup(
      rows: [
        [
          for (final (day, isActive) in days)
            Segment(
              onTap: onTap,
              surface: day == today
                  ? AppColors.training
                  : isActive
                  ? AppColors.trainingSurface
                  : AppColors.surface,
              semanticLabel: isActive
                  ? context.l10n.weekdayActive(
                      weekday: context.dates.weekdayName(day),
                    )
                  : context.dates.weekdayName(day),
              child: _WeekDay(
                day: day,
                isToday: day == today,
                isActive: isActive,
                isFuture: day.isAfter(today),
              ),
            ),
        ],
      ],
    );
  }
}

class _WeekDay extends StatelessWidget {
  const _WeekDay({
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        children: [
          Text(
            context.dates.weekday(day),
            style: AppTextStyles.caption.copyWith(
              color: isToday
                  ? AppColors.onTraining
                  : isFuture
                  ? AppColors.textTertiary
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: 20,
            child: Center(
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
            ),
          ),
        ],
      ),
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

/// The meal the user usually logs about now, not yet logged today.
class NextMealCard extends StatelessWidget {
  const NextMealCard({super.key, required this.mealType, required this.onLog});

  final MealType mealType;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    return SegmentedGroup(
      rows: [
        [
          Segment(
            child: Padding(
              padding: segmentPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CardEyebrow(
                    label: context.l10n.nextStep,
                    color: AppColors.nutrition,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    mealType.labelIn(context.l10n),
                    style: AppTextStyles.pageTitle,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  NutritionButton(
                    label: context.l10n.logItem(
                      item: mealType.labelIn(context.l10n),
                    ),
                    icon: Icons.search,
                    onPressed: onLog,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The day's eating as one group under its name: the energy against its
/// target as the figure that matters, then the macros two by two, and what
/// else belongs to eating (the water drunk) as rows of its own. Any part
/// opens the day.
class IntakeCard extends StatelessWidget {
  const IntakeCard({
    super.key,
    required this.summary,
    required this.convention,
    required this.kcalTarget,
    required this.onTap,
    this.extraRows = const [],
  });

  /// What was eaten on the day.
  final DaySummary summary;
  final NutritionConvention convention;

  /// What the day's energy is set against; null draws no bar.
  final double? kcalTarget;
  final VoidCallback onTap;

  /// Rows under the macros.
  final List<List<Segment>> extraRows;

  @override
  Widget build(BuildContext context) {
    final target = kcalTarget;
    Segment macro(String name, double grams, int missing, Color color) =>
        Segment(
          onTap: onTap,
          child: SegmentStat(
            label: name,
            color: color,
            mark: _dot,
            placeholder: '—',
            // Unknown when no record had the figure.
            value: missing == summary.recordCount && summary.recordCount > 0
                ? null
                : formatAmount(grams),
            unit: 'g',
            valueSize: 20,
          ),
        );
    return CategoryGroup(
      label: context.l10n.moduleNutrition,
      color: AppColors.nutrition,
      tag: summary.hasEstimates
          ? TagChip(
              label: context.l10n.includesEstimates,
              tone: TagTone.nutrition,
            )
          : null,
      children: [
        SegmentedGroup(
          rows: [
            [
              Segment(
                onTap: onTap,
                surface: AppColors.surfaceRaised,
                child: SegmentHero(
                  label: context.l10n.mealsCount(count: summary.mealCount),
                  color: AppColors.nutrition,
                  value: formatKcal(summary.kcal.roundToDouble()),
                  unit: target == null
                      ? 'kcal'
                      : '/ ${formatKcal(target)} kcal',
                  progress: switch (target) {
                    final target? when target > 0 => summary.kcal / target,
                    _ => null,
                  },
                ),
              ),
            ],
            [
              macro(
                convention.proteinName(context.l10n),
                summary.proteinGrams,
                summary.mealsWithoutProtein,
                AppColors.macroProtein,
              ),
              macro(
                convention.carbName(context.l10n),
                convention.countsAvailableCarb
                    ? summary.availableCarbGrams
                    : summary.carbGrams,
                convention.countsAvailableCarb
                    ? summary.mealsWithoutAvailableCarb
                    : summary.mealsWithoutCarb,
                AppColors.macroCarb,
              ),
            ],
            [
              macro(
                convention.fatName(context.l10n),
                summary.fatGrams,
                summary.mealsWithoutFat,
                AppColors.macroFat,
              ),
              macro(
                convention.fibreName(context.l10n),
                summary.fibreGrams,
                summary.mealsWithoutFibre,
                AppColors.macroFibre,
              ),
            ],
            ...extraRows,
          ],
        ),
        if (_leftOut(context.l10n, summary, convention) case final note?)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(note, style: AppTextStyles.caption),
          ),
      ],
    );
  }
}

/// The dot a macro has in front of its name, in its colour.
Widget _dot(Color tint) => DecoratedBox(
  decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
  child: const SizedBox.square(dimension: 8),
);

/// A category of Today: its name under a dot in its colour, and what
/// belongs to it, one gap apart so it reads as one group.
class CategoryGroup extends StatelessWidget {
  const CategoryGroup({
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
              // A heading to a screen reader, as a section label is. It
              // takes the room the tag leaves, so a long name shortens.
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Semantics(
                    header: true,
                    child: CategoryLabel(label: label, color: color),
                  ),
                ),
              ),
              ?tag,
            ],
          ),
        ),
        ...children,
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

/// Today's finished workout, once there is nothing left to start: how
/// long it took, and under it the sets, the exercises and the records.
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
    Segment stat(String label, int value) => Segment(
      onTap: onTap,
      child: SegmentStat(
        label: label,
        color: AppColors.training,
        placeholder: '—',
        value: '$value',
      ),
    );
    return CategoryGroup(
      label: context.l10n.moduleTraining,
      color: AppColors.training,
      children: [
        SegmentedGroup(
          rows: [
            [
              Segment(
                onTap: onTap,
                surface: AppColors.surfaceRaised,
                child: SegmentHero(
                  label: context.l10n.routineCompleted(
                    name: session.routineName,
                  ),
                  color: AppColors.training,
                  value: formatClock(session.elapsedAt(session.finishedAt!)),
                ),
              ),
            ],
            [
              stat(context.l10n.totalSets, session.completedSets),
              stat(context.l10n.exercisesLabel, session.exercises.length),
              stat(
                context.l10n.personalRecords,
                AppStoreScope.of(context).workoutReview(session).records,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Today's movement as the health platform counted it: the lead figure
/// hour by hour, and the other counted ones under it two by two.
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
    final l10n = context.l10n;
    final others = [
      for (final metric in ActivityMetric.headline)
        if (metric != lead)
          if (totals[metric] case final value?)
            Segment(
              onTap: onTap,
              child: SegmentStat(
                label: metric.labelIn(l10n),
                color: AppColors.activity,
                mark: _dot,
                placeholder: '—',
                value: metric.format(value),
                unit: metric.unitIn(l10n),
              ),
            ),
    ];
    return CategoryGroup(
      label: l10n.dailyActivityTitle,
      color: AppColors.activity,
      children: [
        SegmentedGroup(
          rows: [
            [
              Segment(
                onTap: onTap,
                surface: AppColors.surfaceRaised,
                child: SegmentHero(
                  label: lead.labelIn(l10n),
                  color: AppColors.activity,
                  value: lead.format(totals[lead]!),
                  unit: lead.unitIn(l10n),
                  chart: ExcludeSemantics(
                    child: MiniBarChart(
                      bars: [for (final value in hours) ('', value.round())],
                      height: 32,
                      showLabels: false,
                      color: AppColors.activity,
                      dimColor: AppColors.activity.withValues(alpha: 0.4),
                      highlightsLast: false,
                    ),
                  ),
                ),
              ),
            ],
            for (var i = 0; i < others.length; i += 2)
              others.sublist(i, i + 2 > others.length ? others.length : i + 2),
          ],
        ),
      ],
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
    return CategoryGroup(
      label: l10n.vitalsTitle,
      color: AppColors.heart,
      children: [
        SegmentedGroup(
          rows: [
            for (final (label, value, metric, day) in rows.take(_shown))
              [
                Segment(
                  onTap: onTap,
                  child: SegmentRow(
                    title: label,
                    caption: day.isBefore(today)
                        ? context.dates.monthDay(day)
                        : null,
                    trailing: weekOf(metric, day),
                    value: value,
                  ),
                ),
              ],
            if (rows.length > _shown)
              [
                Segment(
                  onTap: onTap,
                  child: SegmentRow(
                    title: l10n.moreItemsCount(count: rows.length - _shown),
                  ),
                ),
              ],
          ],
        ),
      ],
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
  Widget build(BuildContext context) => SegmentedGroup(
    rows: [
      [
        Segment(
          onTap: onTap,
          child: SegmentStat(
            label: label,
            color: color,
            // The section keeps its colour though it has no figure.
            mark: (_) => _dot(color),
            placeholder: context.l10n.noEntriesShort,
          ),
        ),
      ],
    ],
  );
}
