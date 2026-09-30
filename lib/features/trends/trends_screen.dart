import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../app/view_model.dart';
import '../../backend/application/insights_service.dart';
import '../../backend/engines/trend_findings.dart';
import '../../backend/engines/trend_insights.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../body/body_screen.dart';
import '../nutrition/daily_nutrition_screen.dart';
import '../sleep/sleep_screen.dart';
import 'muscle_load_card.dart';
import 'muscle_map.dart';
import 'muscle_trends_screen.dart';
import 'trend_detail_screen.dart';
import 'trends_view_model.dart';
import '../../l10n/l10n.dart';

/// What the records say that no single chart does (see
/// `research/56-trends-insights.md`): what the body actually burns and
/// where the weight is heading, how weekends differ, protein for the
/// body weight, how training is spread over muscles, and, when the
/// records support one, a relation between sleep and training. Each
/// area's long-run line follows and opens that area. Everything is
/// worked out by the engine; an insight without the records to support
/// it says what is missing instead.
class TrendsScreen extends StatelessWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder(
      create: TrendsViewModel.new,
      builder: (context, model) => _TrendsPage(
        report: model.report,
        figure: model.muscleFigure,
        muscleLoad: model.muscleLoad(const Duration(days: 28)),
      ),
    );
  }
}

class _TrendsPage extends StatelessWidget {
  const _TrendsPage({
    required this.report,
    required this.figure,
    required this.muscleLoad,
  });

  final TrendsReport report;

  /// The body the muscle map is drawn on.
  final MuscleFigure figure;

  /// Working sets per muscle a week over the weeks the balance is judged
  /// on; empty with nothing trained.
  final List<(MuscleGroup, int)> muscleLoad;

  /// Narrowest a column reads well at, gutters included.
  static const _minColumnWidth = 380.0;

  @override
  Widget build(BuildContext context) {
    final modules = AppStoreScope.of(context).enabledModules;
    final logsFood = modules.contains(AppModule.nutrition);
    final logsWeight = modules.contains(AppModule.weight);
    final trains = modules.contains(AppModule.training);
    final sleeps = modules.contains(AppModule.sleep);
    final insights = [
      if (logsFood || logsWeight)
        PageSection(
          label: context.l10n.weightAndNutrition,
          children: [
            if (logsFood && logsWeight)
              Gutter(
                child: switch (report.energy) {
                  final energy? => _EnergyCard(
                    energy: energy,
                    onTap: () => pushPage(context, const BodyScreen()),
                  ),
                  null => _Missing(
                    title: context.l10n.energyBalance,
                    needs: context.l10n.energyNeeds(
                      window: energyWindowDays,
                      foodDays: minimumEnergyFoodDays,
                      weighings: minimumEnergyWeighings,
                      currentFood: report.foodDays,
                      currentWeighings: report.weighings,
                    ),
                  ),
                },
              ),
            if (report.weekendIntake case final gap?)
              Gutter(
                child: _WeekendIntakeCard(
                  gap: gap,
                  offset: report.weekendShare,
                  onTap: () => pushPage(context, const DailyNutritionScreen()),
                ),
              ),
            if (logsFood)
              Gutter(
                child: switch (report.protein) {
                  final protein? => _ProteinCard(
                    protein: protein,
                    onTap: () =>
                        pushPage(context, const DailyNutritionScreen()),
                  ),
                  null => _Missing(
                    title: context.l10n.macroProtein,
                    needs: context.l10n.proteinNeeds(
                      window: patternWindowDays,
                      days: minimumProteinDays,
                      current: report.proteinDays,
                    ),
                  ),
                },
              ),
          ],
        ),
      if (trains)
        PageSection(
          label: context.l10n.moduleTraining,
          children: [
            Gutter(
              child: switch (report.training) {
                final training? => _TrainingBalanceCard(
                  balance: training,
                  figure: figure,
                  onTap: () => pushPage(context, const MuscleTrendsScreen()),
                ),
                // Too few workouts to judge the balance, but where the sets
                // went can already be shown.
                null when muscleLoad.isNotEmpty => _InsightCard(
                  domain: TrendDomain.training,
                  picture: _MuscleGlance(load: muscleLoad, figure: figure),
                  headline: context.l10n.muscleSetsTitle,
                  lines: [
                    context.l10n.muscleSetsNeeds(
                      count: minimumBalanceWorkouts,
                      current: report.recentWorkouts,
                    ),
                  ],
                  onTap: () => pushPage(context, const MuscleTrendsScreen()),
                ),
                null => _Missing(
                  title: context.l10n.muscleSetsTitle,
                  needs: context.l10n.muscleSetsNeeds(
                    count: minimumBalanceWorkouts,
                    current: report.recentWorkouts,
                  ),
                ),
              },
            ),
          ],
        ),
      if (sleeps && report.weekendWake != null)
        PageSection(
          label: context.l10n.moduleSleep,
          children: [
            Gutter(
              child: _WeekendWakeCard(
                gap: report.weekendWake!,
                onTap: () => pushPage(context, const SleepScreen()),
              ),
            ),
          ],
        ),
      if (report.relation case final relation?)
        PageSection(
          label: context.l10n.possibleRelations,
          children: [Gutter(child: _RelationCard(relation: relation))],
        ),
    ];
    final linesByDomain = {for (final line in report.lines) line.domain: line};
    final domains = [
      for (final domain in TrendDomain.values)
        if (modules.contains(_moduleOf(domain))) domain,
    ];
    final lines = domains.isEmpty
        ? null
        : PageSection(
            label: context.l10n.longRunSection,
            children: [
              Gutter(
                child: GroupedCard(
                  children: [
                    for (final domain in domains)
                      _LineRow(
                        domain: domain,
                        line: linesByDomain[domain],
                        onTap: () => pushPage(
                          context,
                          TrendDetailScreen(domain: domain),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        // With room for two columns, the long run sits beside the
        // insights instead of below them.
        final isWide =
            insights.isNotEmpty &&
            lines != null &&
            constraints.maxWidth >= _minColumnWidth * 2;
        return CollapsingPage(
          title: context.l10n.tabTrends,
          children: [
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(spacing: pageItemSpacing, children: insights),
                  ),
                  Expanded(child: lines),
                ],
              )
            else ...[
              ...insights,
              ?lines,
            ],
          ],
        );
      },
    );
  }

  static AppModule _moduleOf(TrendDomain domain) => switch (domain) {
    TrendDomain.body => AppModule.weight,
    TrendDomain.training => AppModule.training,
    TrendDomain.sleep => AppModule.sleep,
    TrendDomain.nutrition => AppModule.nutrition,
    TrendDomain.activity => AppModule.activity,
  };
}

/// `+0.3` or `−0.6`: kilograms with their sign, a true minus for a
/// fall.
String _signedKg(double kilograms) =>
    '${kilograms < 0 ? '−' : '+'}${formatWeight(_tenth(kilograms.abs()))}';

double _tenth(double value) => (value * 10).round() / 10;

/// `1:40`: minutes as hours and minutes.
String _clock(double minutes) =>
    formatHoursMinutes(Duration(minutes: minutes.round()));

/// One insight: its area, the conclusion as a headline, the figure it
/// rests on, the lines that support it, and a tag for what kind of
/// figure it is. Opens the area it is about.
class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.domain,
    required this.headline,
    this.picture,
    this.value,
    this.unit,
    this.lines = const [],
    this.warning,
    this.tag,
    this.onTap,
  });

  final TrendDomain domain;
  final String headline;

  /// A figure above the headline, for an insight a picture says faster.
  final Widget? picture;
  final String? value;
  final String? unit;
  final List<String> lines;

  /// A reason to doubt the records rather than the body.
  final String? warning;
  final String? tag;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryLabel(
                label: domain.labelIn(context.l10n),
                color: trendColor(domain),
              ),
              const Spacer(),
              if (onTap != null)
                const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
          if (picture case final picture?) ...[
            const SizedBox(height: AppSpacing.sm),
            picture,
            const SizedBox(height: AppSpacing.sm),
          ] else
            const SizedBox(height: AppSpacing.xs),
          Text(headline, style: AppTextStyles.itemTitle),
          if (value case final value?) ...[
            const SizedBox(height: AppSpacing.xs),
            ValueWithUnit(
              value: value,
              unit: unit,
              style: AppTextStyles.bigNumber,
            ),
          ],
          for (final line in lines) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(line, style: AppTextStyles.caption),
          ],
          if (warning case final warning?) ...[
            const SizedBox(height: AppSpacing.sm),
            InfoBanner(tone: CardTone.warning, message: warning),
          ],
          if (tag case final tag?) ...[
            const SizedBox(height: AppSpacing.sm),
            TagChip(label: tag),
          ],
        ],
      ),
    );
  }
}

/// An insight the records cannot support yet, and what it needs.
class _Missing extends StatelessWidget {
  const _Missing({required this.title, required this.needs});

  final String title;
  final String needs;

  @override
  Widget build(BuildContext context) {
    return NavCard(title: title, subtitle: needs, showChevron: false);
  }
}

class _EnergyCard extends StatelessWidget {
  const _EnergyCard({required this.energy, required this.onTap});

  final EnergyBalance energy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final balance = energy.balance;
    return _InsightCard(
      domain: TrendDomain.body,
      headline: l10n.actualExpenditure(kcal: formatKcal(energy.expenditure)),
      lines: [
        (balance < 0 ? l10n.intakeDeficit : l10n.intakeSurplus)(
          window: energyWindowDays,
          intake: formatKcal(energy.intake),
          balance: formatKcal(balance.abs()),
        ),
        l10n.weightForecast(
          change: _signedKg(energy.weeklyChangeKg),
          weeks: forecastWeeks,
          forecast: formatWeight(_tenth(energy.forecastKg)),
        ),
        l10n.foodDaysWeighings(
          foodDays: energy.foodDays,
          weighings: energy.weighings,
        ),
      ],
      warning: energy.isIntakeLikelyUnderlogged ? l10n.intakeUnderlogged : null,
      tag: l10n.estimatedFromEntries,
      onTap: onTap,
    );
  }
}

class _WeekendIntakeCard extends StatelessWidget {
  const _WeekendIntakeCard({
    required this.gap,
    required this.offset,
    required this.onTap,
  });

  final WeekendGap gap;

  /// How much of the weekdays' deficit the weekends take back.
  final double? offset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final more = gap.difference > 0;
    return _InsightCard(
      domain: TrendDomain.nutrition,
      headline: (more ? l10n.weekendEatsMore : l10n.weekendEatsLess)(
        kcal: formatKcal(gap.difference.abs().round()),
      ),
      lines: [
        l10n.weekdayWeekendKcal(
          weekday: formatKcal(gap.weekday.round()),
          weekend: formatKcal(gap.weekend.round()),
        ),
        if (offset case final offset?)
          offset >= 1
              ? l10n.offsetsAllDeficit
              : l10n.offsetsDeficitShare(percent: (offset * 100).round()),
        l10n.weekdaysWeekends(
          window: patternWindowDays,
          weekdays: gap.weekdays,
          weekends: gap.weekends,
        ),
      ],
      onTap: onTap,
    );
  }
}

class _ProteinCard extends StatelessWidget {
  const _ProteinCard({required this.protein, required this.onTap});

  final ProteinIntake protein;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final short = protein.shortGrams;
    return _InsightCard(
      domain: TrendDomain.nutrition,
      headline: short == 0
          ? l10n.proteinMet(target: '$proteinTargetPerKg')
          : l10n.proteinShort(grams: short),
      value: formatAmount(_tenth(protein.perKg)),
      unit: 'g/kg',
      lines: [
        if ((protein.trainingDayPerKg, protein.restDayPerKg) case (
          final trained?,
          final rest?,
        ))
          l10n.trainingRestProtein(
            trained: formatAmount(_tenth(trained)),
            rest: formatAmount(_tenth(rest)),
          ),
        l10n.proteinBasis(
          weight: formatWeight(_tenth(protein.weightKg)),
          target: '$proteinTargetPerKg',
          days: protein.days,
        ),
      ],
      onTap: onTap,
    );
  }
}

class _TrainingBalanceCard extends StatelessWidget {
  const _TrainingBalanceCard({
    required this.balance,
    required this.figure,
    required this.onTap,
  });

  final TrainingBalance balance;
  final MuscleFigure figure;
  final VoidCallback onTap;

  static (String, String) _sides(AppLocalizations l10n, MusclePair pair) =>
      switch (pair) {
        MusclePair.pushPull => (l10n.musclePush, l10n.musclePull),
        MusclePair.quadsHamstrings => (l10n.muscleQuads, l10n.muscleHamstrings),
      };

  static String _list(
    AppLocalizations l10n,
    List<(MuscleGroup, int)> muscles,
  ) => joinList(l10n, [
    for (final (muscle, sets) in muscles) '${muscle.labelIn(l10n)} $sets',
  ]);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final short = balance.short;
    return _InsightCard(
      domain: TrendDomain.training,
      picture: _MuscleGlance(
        load: [...balance.enough, ...short]
          ..sort((a, b) => b.$2.compareTo(a.$2)),
        figure: figure,
      ),
      headline: short.isEmpty
          ? l10n.allMusclesEnough(target: weeklySetTarget)
          : l10n.muscleOnlySets(
              muscle: short.first.$1.labelIn(l10n),
              sets: short.first.$2,
            ),
      lines: [
        if (short.isNotEmpty)
          l10n.underSets(target: weeklySetTarget, muscles: _list(l10n, short)),
        if (balance.enough.isNotEmpty)
          l10n.atLeastSets(
            target: weeklySetTarget,
            muscles: _list(l10n, balance.enough),
          ),
        for (final (pair, first, second) in balance.imbalances)
          l10n.pairRatio(
            first: _sides(l10n, pair).$1,
            second: _sides(l10n, pair).$2,
            firstSets: first,
            secondSets: second,
          ),
      ],
      tag: l10n.muscleSetsBasis,
      onTap: onTap,
    );
  }
}

/// Where the week's work went, at a glance, half as tall as the card is
/// wide, with the most trained muscles' sets under it; the full map and
/// every muscle's sets are a tap away.
class _MuscleGlance extends StatelessWidget {
  const _MuscleGlance({required this.load, required this.figure});

  /// Most trained first.
  final List<(MuscleGroup, int)> load;
  final MuscleFigure figure;

  static const _shown = 3;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          height: constraints.maxWidth / 2,
          child: Center(
            child: MuscleMap(
              setsByMuscle: {for (final (muscle, sets) in load) muscle: sets},
              figure: figure,
            ),
          ),
        ),
      ),
      if (load.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.md),
        MuscleSetBars(load: load.take(_shown).toList()),
      ],
    ],
  );
}

class _WeekendWakeCard extends StatelessWidget {
  const _WeekendWakeCard({required this.gap, required this.onTap});

  final WeekendGap gap;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final later = gap.difference > 0;
    return _InsightCard(
      domain: TrendDomain.sleep,
      headline: (later ? l10n.weekendWakeLater : l10n.weekendWakeEarlier)(
        time: _clock(gap.difference.abs()),
      ),
      lines: [
        l10n.weekdayWeekendWake(
          weekday: _clock(gap.weekday),
          weekend: _clock(gap.weekend),
        ),
        l10n.weekdaysWeekends(
          window: patternWindowDays,
          weekdays: gap.weekdays,
          weekends: gap.weekends,
        ),
      ],
      onTap: onTap,
    );
  }
}

/// A relation between two areas, with what it rests on, and never more
/// than a relation.
class _RelationCard extends StatelessWidget {
  const _RelationCard({required this.relation});

  final Insight relation;

  @override
  Widget build(BuildContext context) {
    final caveat = context.l10n.correlationCaveat;
    return _InsightCard(
      domain: TrendDomain.sleep,
      headline: relation.statement,
      lines: [
        [
          for (final line in relation.evidence)
            if (line != caveat) line,
        ].join(' · '),
      ],
      tag: caveat,
    );
  }
}

/// An area where it stands, against the stretch before, and its weeks;
/// 沒有紀錄 until it has any.
class _LineRow extends StatelessWidget {
  const _LineRow({required this.domain, this.line, required this.onTap});

  static const _chartWidth = 64.0;

  final TrendDomain domain;
  final TrendLine? line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final line = this.line;
    final color = trendColor(domain);
    return NavRow(
      leading: AccentBar(color: color, height: 28),
      title: domain.labelIn(context.l10n),
      subtitle: line?.value ?? context.l10n.noEntriesShort,
      detail: line?.change,
      trailing: line == null || line.weekly.length < 2
          ? null
          : SizedBox(
              width: _chartWidth,
              child: ExcludeSemantics(
                child: Sparkline(values: line.weekly, color: color, height: 28),
              ),
            ),
      onTap: onTap,
    );
  }
}
