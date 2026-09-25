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
import 'muscle_trends_screen.dart';
import 'trend_detail_screen.dart';
import 'trends_view_model.dart';

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
      builder: (context, model) => _TrendsPage(report: model.report),
    );
  }
}

class _TrendsPage extends StatelessWidget {
  const _TrendsPage({required this.report});

  final TrendsReport report;

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
          label: '體重與飲食',
          children: [
            if (logsFood && logsWeight)
              Gutter(
                child: switch (report.energy) {
                  final energy? => _EnergyCard(
                    energy: energy,
                    onTap: () => pushPage(context, const BodyScreen()),
                  ),
                  null => _Missing(
                    title: '能量平衡',
                    needs:
                        '需要近 $energyWindowDays 天有 '
                        '$minimumEnergyFoodDays 天完整飲食、'
                        '$minimumEnergyWeighings 次體重'
                        '（目前 ${report.foodDays} 天、${report.weighings} 次）',
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
                  null => const _Missing(
                    title: '蛋白質',
                    needs:
                        '需要近 $patternWindowDays 天有 '
                        '$minimumProteinDays 天完整飲食與體重',
                  ),
                },
              ),
          ],
        ),
      if (trains)
        PageSection(
          label: '訓練',
          children: [
            Gutter(
              child: switch (report.training) {
                final training? => _TrainingBalanceCard(
                  balance: training,
                  onTap: () => pushPage(context, const MuscleTrendsScreen()),
                ),
                null => const _Missing(
                  title: '肌群組數',
                  needs: '需要近 4 週至少 $minimumBalanceWorkouts 次訓練',
                ),
              },
            ),
          ],
        ),
      if (sleeps && report.weekendWake != null)
        PageSection(
          label: '睡眠',
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
          label: '可能的關聯',
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
            label: '長期走向',
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
          title: '趨勢',
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
    this.value,
    this.unit,
    this.lines = const [],
    this.warning,
    this.tag,
    this.onTap,
  });

  final TrendDomain domain;
  final String headline;
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
              CategoryLabel(label: domain.label, color: trendColor(domain)),
              const Spacer(),
              if (onTap != null)
                const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
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
    final balance = energy.balance;
    return _InsightCard(
      domain: TrendDomain.body,
      headline: '實際消耗約 ${formatKcal(energy.expenditure)} kcal/天',
      lines: [
        '近 $energyWindowDays 天平均攝取 ${formatKcal(energy.intake)} kcal，'
            '每天${balance < 0 ? '赤字' : '盈餘'} ${formatKcal(balance.abs())} kcal',
        '趨勢體重每週 ${_signedKg(energy.weeklyChangeKg)} kg，'
            '$forecastWeeks 週後約 ${formatWeight(_tenth(energy.forecastKg))} kg',
        '${energy.foodDays} 天完整飲食 · ${energy.weighings} 次體重',
      ],
      warning: energy.isIntakeLikelyUnderlogged
          ? '估計的消耗低於靜止代謝，紀錄的攝取可能少於實際。'
          : null,
      tag: '依紀錄估算，非實測',
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
    final more = gap.difference > 0;
    return _InsightCard(
      domain: TrendDomain.nutrition,
      headline:
          '週末每天${more ? '多' : '少'}吃 '
          '${formatKcal(gap.difference.abs().round())} kcal',
      lines: [
        '平日 ${formatKcal(gap.weekday.round())} kcal · '
            '週末 ${formatKcal(gap.weekend.round())} kcal',
        if (offset case final offset?)
          offset >= 1 ? '抵掉平日全部的赤字' : '抵掉平日赤字約 ${(offset * 100).round()}%',
        '近 $patternWindowDays 天，${gap.weekdays} 個平日、${gap.weekends} 個週末日',
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
    final short = protein.shortGrams;
    return _InsightCard(
      domain: TrendDomain.nutrition,
      headline: short == 0
          ? '蛋白質達到 $proteinTargetPerKg g/kg'
          : '蛋白質每天約差 $short g',
      value: formatAmount(_tenth(protein.perKg)),
      unit: 'g/kg',
      lines: [
        if ((protein.trainingDayPerKg, protein.restDayPerKg) case (
          final trained?,
          final rest?,
        ))
          '訓練日 ${formatAmount(_tenth(trained))} · '
              '休息日 ${formatAmount(_tenth(rest))} g/kg',
        '以 ${formatWeight(_tenth(protein.weightKg))} kg、'
            '目標 $proteinTargetPerKg g/kg 計 · ${protein.days} 天完整飲食',
      ],
      onTap: onTap,
    );
  }
}

class _TrainingBalanceCard extends StatelessWidget {
  const _TrainingBalanceCard({required this.balance, required this.onTap});

  final TrainingBalance balance;
  final VoidCallback onTap;

  static String _list(List<(MuscleGroup, int)> muscles) =>
      [for (final (muscle, sets) in muscles) '${muscle.label} $sets'].join('、');

  @override
  Widget build(BuildContext context) {
    final short = balance.short;
    return _InsightCard(
      domain: TrendDomain.training,
      headline: short.isEmpty
          ? '練到的肌群每週都有 $weeklySetTarget 組以上'
          : '${short.first.$1.label}每週只有 ${short.first.$2} 組',
      lines: [
        if (short.isNotEmpty) '不到 $weeklySetTarget 組：${_list(short)}',
        if (balance.enough.isNotEmpty)
          '$weeklySetTarget 組以上：${_list(balance.enough)}',
        for (final (pair, first, second) in balance.imbalances)
          '${pair.first}對${pair.second} $first : $second 組',
      ],
      tag: '近 4 週每週組數，只計主要肌群',
      onTap: onTap,
    );
  }
}

class _WeekendWakeCard extends StatelessWidget {
  const _WeekendWakeCard({required this.gap, required this.onTap});

  final WeekendGap gap;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final later = gap.difference > 0;
    return _InsightCard(
      domain: TrendDomain.sleep,
      headline: '週末起床${later ? '晚' : '早'} ${_clock(gap.difference.abs())}',
      lines: [
        '平日約 ${_clock(gap.weekday)} · 週末約 ${_clock(gap.weekend)} 起床',
        '近 $patternWindowDays 天，${gap.weekdays} 個平日、${gap.weekends} 個週末日',
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
    const caveat = '關聯，不代表因果';
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
      title: domain.label,
      subtitle: line?.value ?? '沒有紀錄',
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
