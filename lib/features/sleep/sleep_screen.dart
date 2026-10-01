import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/application/sleep_service.dart';
import '../../backend/engines/overnight_series.dart';
import '../../backend/engines/sleep_nights.dart';
import '../../backend/engines/trend_findings.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../journal/sleep_entry_screen.dart';
import '../me/data_sources_screen.dart';
import '../trends/trend_detail_screen.dart';
import 'sleep_shortfall_screen.dart';
import 'sleep_stage_chart.dart';
import 'sleep_goal_rows.dart';
import 'sleep_view_model.dart';
import '../../l10n/l10n.dart';

/// One day's sleep: the night, what each stage took, what was measured
/// overnight, the day's naps, the sleep owed up to it and tonight's plan,
/// and which source it all comes from. How nights go over weeks and
/// months is the sleep trend's, from the header.
///
/// It shows what the source recorded and what follows from it, and
/// nothing it did not: no score, no target for a stage, no efficiency
/// without time in bed, and time in bed is never called time asleep.
class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key, this.day});

  /// The day to open on; today when null.
  final DateTime? day;

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  late final _model = SleepViewModel(
    AppStoreScope.read(context).backend,
    day: widget.day,
  );

  /// The shown night's heart rate and breathing through the night, read
  /// from the health platform when the night is shown, and which night
  /// it was read for.
  Future<Map<OvernightMeasure, List<(DateTime, double)>>>? _series;
  (DateTime, DateTime)? _seriesFor;

  /// [_series] for [night], read again only when the night changes.
  Future<Map<OvernightMeasure, List<(DateTime, double)>>> _seriesOf(
    SleepRecord night,
  ) {
    final entry = night.entry;
    final span = (
      entry.startedAt ?? entry.sleptAt.subtract(entry.duration),
      entry.sleptAt,
    );
    if (span != _seriesFor || _series == null) {
      _seriesFor = span;
      _series = AppStoreScope.read(context).overnightSeries(span.$1, span.$2);
    }
    return _series!;
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  void _delete(SleepRecord record) {
    final toast = ToastScope.read(context);
    final id = record.entry.id;
    _model.delete(id);
    toast.showUndo(
      context.l10n.deletedItem(item: record.entry.kind.labelIn(context.l10n)),
      onUndo: () => _model.restore(id),
    );
  }

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: _model, builder: (context, _) => _page());

  Widget _page() {
    final day = _model.day;
    final night = _model.night;
    final naps = _model.naps;
    return PageScaffold(
      appBar: PageAppBar(
        title: context.l10n.moduleSleep,
        subtitle: context.dates.dayWithWeekday(day),
        actions: [
          HeaderAction(
            icon: Icons.insights,
            label: context.l10n.tabTrends,
            semanticLabel: context.l10n.areaTrend(
              area: context.l10n.moduleSleep,
            ),
            onTap: () => pushPage(
              context,
              const TrendDetailScreen(domain: TrendDomain.sleep),
            ),
          ),
        ],
      ),
      // The same week header as 飲食: any night is a swipe away.
      pinned: WeekDayStrip(
        selected: day,
        latest: _model.today,
        firstWeekday: AppStoreScope.of(context).firstWeekday,
        color: AppColors.wellness,
        markedDays: _model.daysWithSleep([
          for (var back = -35; back <= 35; back++)
            DateTime(day.year, day.month, day.day + back),
        ]),
        onSelected: _model.show,
      ),
      pinnedHeight: WeekDayStrip.pinnedHeightOf(context),
      children: [
        if (night == null && naps.isEmpty)
          Gutter(
            child: EmptyStateCard(
              icon: Icons.bedtime_outlined,
              title: context.l10n.noSleepRecords,
              action: PrimaryButton(
                label: context.l10n.logByHand,
                onPressed: () => pushPage(context, const SleepEntryScreen()),
              ),
            ),
          ),
        if (night == null && naps.isEmpty)
          Gutter(
            child: Center(
              child: LinkText(
                label: context.l10n.dataSourcesLink,
                onTap: () => pushPage(context, const DataSourcesScreen()),
              ),
            ),
          ),
        if (night != null) ...[
          Gutter(
            child: _Summary(
              record: night,
              goal: _model.goal,
              usual: _model.usualNight,
              naps: naps,
            ),
          ),
          ..._stages(night),
          ..._continuity(night),
          ..._readings(night),
          _NightCharts(
            series: _seriesOf(night),
            from: _seriesFor!.$1,
            to: _seriesFor!.$2,
            isRead: !night.isTypedIn,
          ),
        ],
        if (_model.shortfall(shortfallDays).recorded > 0)
          PageSection(
            label: context.l10n.sleepDebtSection,
            children: [
              Gutter(
                child: SleepShortfallCard(
                  model: _model,
                  onTap: () =>
                      pushPage(context, SleepShortfallScreen(day: day)),
                ),
              ),
            ],
          ),
        ..._tonight(),
        if (naps.isNotEmpty)
          PageSection(
            label: context.l10n.napsSection,
            children: [
              for (final nap in naps)
                Gutter(
                  child: NavCard(
                    title:
                        _span(nap.entry) ??
                        nap.entry.kind.labelIn(context.l10n),
                    subtitle: nap.shownSource?.sourceName,
                    trailing: Text(
                      formatHoursMinutes(nap.entry.duration),
                      style: AppTextStyles.itemTitle,
                    ),
                  ),
                ),
            ],
          ),
        PageSection(
          label: context.l10n.goalSection,
          children: [
            Gutter(
              child: GroupedCard(children: sleepGoalRows(context, _model)),
            ),
          ],
        ),
        if (night != null) ..._sources(night),
        if (night != null)
          PageSection(
            label: context.l10n.manageSection,
            children: [
              Gutter(
                child: GroupedCard(
                  children: [
                    NavRow(
                      title: context.l10n.commonEdit,
                      onTap: () => pushPage(
                        context,
                        SleepEntryScreen(editing: night.entry),
                      ),
                    ),
                    NavRow(
                      title: context.l10n.recordDelete,
                      isDestructive: true,
                      onTap: () => _delete(night),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// The stage chart and each stage's time, when the source staged the
  /// sleep; a line saying it did not when it only knew asleep or in bed;
  /// nothing for a length typed in.
  List<Widget> _stages(SleepRecord record) {
    if (record.isTypedIn) return const [];
    if (!record.hasStages) {
      return [
        Gutter(
          child: GroupedCard(
            children: [
              KeyValueRow(
                label: context.l10n.sleepStagesSection,
                value: context.l10n.notProvided,
              ),
            ],
          ),
        ),
      ];
    }
    final average = _model.averageStages(stageAverageDays);
    return [
      PageSection(
        label: context.l10n.sleepStagesSection,
        children: [
          Gutter(
            child: AppCard(child: SleepStageChart(stages: record.stages)),
          ),
          Gutter(
            child: _StageShares(
              totals: stageTotals(record.stages),
              average: average.nights < _minimumNightsForStageAverage
                  ? null
                  : average,
            ),
          ),
        ],
      ),
    ];
  }

  /// Time to fall asleep, efficiency and time awake, each only when the
  /// source recorded what it takes; nothing for a length typed in.
  List<Widget> _continuity(SleepRecord record) {
    final continuity = record.continuity;
    if (continuity == null) return const [];
    final efficiency = continuity.efficiency;
    final latency = continuity.latency;
    final awake = continuity.awake;
    final rows = [
      if (latency != null)
        KeyValueRow(
          label: context.l10n.fallAsleepTime,
          value: context.l10n.aboutMinutes(minutes: latency.inMinutes),
        ),
      if (efficiency != null)
        KeyValueRow(
          label: context.l10n.sleepEfficiency,
          value: '${(efficiency * 100).round()}%',
        ),
      if (awake != null)
        KeyValueRow(
          label: context.l10n.awakeAtNight,
          value: [
            formatHoursMinutes(awake),
            if (continuity.awakenings case final times? when times > 0)
              context.l10n.wokeTimes(count: times),
          ].join(' · '),
        ),
    ];
    if (rows.isEmpty) return const [];
    return [
      PageSection(
        label: context.l10n.continuitySection,
        children: [
          Gutter(child: GroupedCard(children: rows)),
          if (latency != null || efficiency != null)
            Gutter(child: TagWrap(labels: [context.l10n.estimatedFromInBed])),
        ],
      ),
    ];
  }

  /// When to sleep tonight for the goal; only on today, with a goal.
  List<Widget> _tonight() {
    final plan = _model.tonightPlan;
    if (plan == null) return const [];
    return [
      PageSection(
        label: context.l10n.tonightSection,
        children: [
          Gutter(
            child: GroupedCard(
              children: [
                KeyValueRow(
                  label: context.l10n.suggestedBedtime,
                  value:
                      '${formatTimeOfDay(plan.bedtime)} · '
                      '${context.l10n.wakeAt(time: formatTimeOfDay(plan.wake))}',
                ),
              ],
            ),
          ),
          Gutter(child: TagWrap(labels: [context.l10n.fromUsualWake])),
        ],
      ),
    ];
  }

  List<Widget> _readings(SleepRecord record) {
    if (record.readings.isEmpty) return const [];
    return [
      PageSection(
        label: context.l10n.healthDataOvernight,
        children: [
          Gutter(
            child: GroupedCard(
              children: [
                for (final reading in record.readings)
                  KeyValueRow(
                    label: reading.measure.labelIn(context.l10n),
                    value: [
                      overnightValue(context.l10n, reading),
                      if (_model.baseline(reading.measure) case final usual?
                          when reading.measure !=
                              OvernightMeasure.breathingDisturbances)
                        context.l10n.usualRangeValue(
                          range:
                              '${overnightNumber(reading.measure, usual.low)}–'
                              '${overnightNumber(reading.measure, usual.high)}',
                        ),
                    ].join(' · '),
                  ),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  /// Every source that recorded the night, the shown one checked; tapping
  /// another shows the night from it.
  List<Widget> _sources(SleepRecord record) {
    final store = AppStoreScope.read(context);
    if (record.isTypedIn) {
      return [
        PageSection(
          label: context.l10n.journalSourceRow,
          children: [
            Gutter(
              child: GroupedCard(
                children: [
                  KeyValueRow(
                    label: context.l10n.recordMethod,
                    value: context.l10n.sourceManual,
                  ),
                ],
              ),
            ),
          ],
        ),
      ];
    }
    final shown = record.shownSource;
    return [
      PageSection(
        label: context.l10n.journalSourceRow,
        children: [
          Gutter(
            child: GroupedCard(
              children: [
                for (final source in record.sources)
                  Semantics(
                    selected: source.source == shown?.source,
                    child: NavRow(
                      title: source.sourceName.isEmpty
                          ? store.healthSourceName
                          : source.sourceName,
                      subtitle: [
                        '${formatTimeOfDay(source.start)} – '
                            '${formatTimeOfDay(source.end)}',
                        source.isManual
                            ? context.l10n.sourceManual
                            : source.hasStages
                            ? context.l10n.withStages
                            : source.measure.labelIn(context.l10n),
                      ].join(' · '),
                      trailing: source.source == shown?.source
                          ? const Icon(Icons.check, color: AppColors.training)
                          : null,
                      showChevron: false,
                      onTap: source.source == shown?.source
                          ? null
                          : () => _model.chooseSource(
                              record.entry.id,
                              source.source,
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ];
  }
}

/// `23:41 – 07:34`, or null for a length typed in without times.
String? _span(SleepEntry entry) => switch (entry.startedAt) {
  final start? =>
    '${formatTimeOfDay(start)} – ${formatTimeOfDay(entry.sleptAt)}',
  null => null,
};

/// One value of [measure] as its readings are written.
String overnightNumber(OvernightMeasure measure, double value) =>
    switch (measure) {
      OvernightMeasure.wristTemperature ||
      OvernightMeasure.respiratoryRate => value.toStringAsFixed(1),
      OvernightMeasure.skinTemperatureChange =>
        '${value >= 0 ? '+' : '−'}${value.abs().toStringAsFixed(1)}',
      _ => value.round().toString(),
    };

/// `52–68`, or one value when both ends read the same.
String _range(OvernightMeasure measure, double low, double high) {
  final lowText = overnightNumber(measure, low);
  final highText = overnightNumber(measure, high);
  return lowText == highText ? lowText : '$lowText–$highText';
}

/// What was measured, as the platform reports it: a range, or one value
/// when the range is a single one; Apple's own reading for breathing
/// disturbances.
String overnightValue(AppLocalizations l10n, OvernightReading reading) {
  final measure = reading.measure;
  if (measure == OvernightMeasure.breathingDisturbances) {
    return switch (reading.isElevated) {
      true => l10n.elevated,
      false => l10n.notElevated,
      null => formatAmount(reading.average),
    };
  }
  final range = _range(measure, reading.minimum, reading.maximum);
  final unit = measure.unitIn(l10n);
  return unit.isEmpty ? range : '$range $unit';
}

/// The span a night's stages are set against.
const stageAverageDays = 30;

/// Staged nights the average needs before it is drawn: a product rule,
/// so one or two nights are not called usual.
const _minimumNightsForStageAverage = 7;

/// Each stage's time and share, as Google Health draws them, with the
/// average night's share across each bar. A share is of time asleep;
/// time awake is set against the same time asleep but given no
/// percentage, as it is not part of it, and time in bed has no bar.
class _StageShares extends StatelessWidget {
  const _StageShares({required this.totals, required this.average});

  final Map<SleepStage, Duration> totals;
  final ({Map<SleepStage, Duration> stages, int nights})? average;

  static Duration _asleep(Map<SleepStage, Duration> stages) => stages.entries
      .where((entry) => entry.key.isAsleep)
      .fold(Duration.zero, (sum, entry) => sum + entry.value);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final asleep = _asleep(totals);
    final average = this.average;
    final usualAsleep = average == null ? null : _asleep(average.stages);
    double? shareOf(Duration time, Duration? of) =>
        of == null || of <= Duration.zero
        ? null
        : time.inSeconds / of.inSeconds;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, MapEntry(key: stage, value: time))
              in totals.entries.indexed) ...[
            if (index > 0) const SizedBox(height: AppSpacing.sm),
            () {
              final share = shareOf(time, asleep);
              final usual = switch (average?.stages[stage]) {
                final time? => shareOf(time, usualAsleep),
                null => null,
              };
              final label = [
                stage.labelIn(l10n),
                formatHoursMinutes(time),
                if (stage.isAsleep && share != null)
                  '${(share * 100).round()}%',
              ].join(' · ');
              return Semantics(
                label: [
                  label,
                  if (stage.isAsleep && usual != null)
                    '${l10n.lastDaysAverage(count: stageAverageDays)} '
                        '${(usual * 100).round()}%',
                ].join(' · '),
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyles.body),
                    if (stage != SleepStage.inBed && share != null)
                      ShareBar(
                        share: share,
                        color: sleepStageColor(stage),
                        reference: usual,
                      ),
                  ],
                ),
              );
            }(),
          ],
          if (average != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ChartKey(
              color: AppColors.textPrimary,
              label:
                  '${l10n.lastDaysAverage(count: stageAverageDays)} · '
                  '${l10n.nightsCount(count: average.nights)}',
            ),
          ],
        ],
      ),
    );
  }
}

/// The night's length, what it measures and when it began and ended, and
/// where it came from.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.record,
    required this.goal,
    required this.usual,
    required this.naps,
  });

  final SleepRecord record;

  /// The night's length is read against it when there is one.
  final Duration? goal;

  /// The average night of the four weeks before.
  final Duration? usual;

  /// The day's naps, which add to the day's sleep but not to the night.
  final List<SleepRecord> naps;

  /// The night against the usual one, when both measure time asleep.
  String? _againstUsual(AppLocalizations l10n, SleepEntry entry) {
    final usual = this.usual;
    if (usual == null || entry.measure != SleepMeasure.asleep) return null;
    final gap = entry.duration - usual;
    if (gap.inMinutes.abs() < 1) return l10n.sameAsUsual;
    return l10n.versusUsual(
      change: '${gap.isNegative ? '−' : '+'}${formatHoursMinutes(gap.abs())}',
    );
  }

  /// The night against the goal: time in bed is not measured against a
  /// goal for sleep.
  String? _againstGoal(AppLocalizations l10n, SleepEntry entry) {
    final goal = this.goal;
    if (goal == null || entry.measure != SleepMeasure.asleep) return null;
    final gap = entry.duration - goal;
    if (gap >= Duration.zero) {
      return l10n.goalMet(goal: formatHoursMinutes(goal));
    }
    return l10n.goalShort(
      goal: formatHoursMinutes(goal),
      gap: formatHoursMinutes(-gap),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = record.entry;
    final label = record.isTypedIn
        ? context.l10n.recordedSleep
        : entry.measure.labelIn(context.l10n);
    final tags = [
      if (record.isTypedIn)
        context.l10n.sourceManual
      else if (record.shownSource case final source?) ...[
        if (source.sourceName.isNotEmpty) source.sourceName,
        if (source.isManual)
          context.l10n.sourceManual
        else if (record.hasStages)
          context.l10n.deviceEstimate,
      ],
      if (entry.score case final score?)
        context.l10n.sleepQualityScore(score: score),
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatHoursMinutes(entry.duration),
            style: AppTextStyles.hugeNumber.copyWith(color: AppColors.wellness),
          ),
          Text(
            [label, ?_span(entry)].join(' · '),
            style: AppTextStyles.caption,
          ),
          if (_againstGoal(context.l10n, entry) case final line?)
            Text(line, style: AppTextStyles.caption),
          if (_againstUsual(context.l10n, entry) case final line?)
            Text(line, style: AppTextStyles.caption),
          if (naps.isNotEmpty)
            Text(
              context.l10n.withNapsTotal(
                time: formatHoursMinutes(
                  naps.fold(
                    entry.duration,
                    (sum, nap) => sum + nap.entry.duration,
                  ),
                ),
              ),
              style: AppTextStyles.caption,
            ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            TagWrap(labels: tags),
          ],
          if (entry.note.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(entry.note, style: AppTextStyles.body),
          ],
        ],
      ),
    );
  }
}

/// Heart rate and breathing through the night, in half-hour stretches,
/// once the health platform has answered; nothing without samples.
class _NightCharts extends StatelessWidget {
  const _NightCharts({
    required this.series,
    required this.from,
    required this.to,
    required this.isRead,
  });

  final Future<Map<OvernightMeasure, List<(DateTime, double)>>> series;
  final DateTime from;
  final DateTime to;

  /// Whether the night came from the health platform, which then likely
  /// has readings for it: their cards hold their place while it answers,
  /// so the page below does not move once they arrive.
  final bool isRead;

  static final _shown = [
    (
      OvernightMeasure.heartRate,
      (AppLocalizations l10n) => l10n.heartRateAsleep,
      AppColors.heart,
    ),
    (
      OvernightMeasure.respiratoryRate,
      (AppLocalizations l10n) => l10n.respiratoryAsleep,
      AppColors.activity,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: series,
      builder: (context, snapshot) {
        // While the platform answers, an earlier night's readings are not
        // this night's: the cards stand empty at their full height.
        final isWaiting = snapshot.connectionState == ConnectionState.waiting;
        final byMeasure = isWaiting
            ? const <OvernightMeasure, List<(DateTime, double)>>{}
            : snapshot.data ?? const {};
        return Column(
          spacing: pageItemSpacing,
          children: [
            for (final (measure, title, color) in _shown)
              if (byMeasure[measure] ??
                      (isWaiting && isRead
                          ? const <(DateTime, double)>[]
                          : null)
                  case final points? when points.isNotEmpty || isWaiting)
                Gutter(
                  child: _NightChartCard(
                    title: title(context.l10n),
                    measure: measure,
                    color: color,
                    points: points,
                    from: from,
                    to: to,
                  ),
                ),
          ],
        );
      },
    );
  }
}

/// Bars an empty card is drawn with while its readings are on the way.
const _emptyBins = 24;

class _NightChartCard extends StatelessWidget {
  const _NightChartCard({
    required this.title,
    required this.measure,
    required this.color,
    required this.points,
    required this.from,
    required this.to,
  });

  final String title;
  final OvernightMeasure measure;
  final Color color;
  final List<(DateTime, double)> points;
  final DateTime from;
  final DateTime to;

  @override
  Widget build(BuildContext context) {
    final values = [for (final (_, value) in points) value];
    final ranges = points.isEmpty
        ? List<(double, double)?>.filled(_emptyBins, null)
        : rangeBins(points, from, to);
    // Each bar is an equal share of the night.
    final stretch = to.difference(from) ~/ ranges.length;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CategoryLabel(label: title, color: color),
          const SizedBox(height: AppSpacing.xs),
          Text(
            values.isEmpty
                ? '—'
                : '${_range(measure, values.reduce(math.min), values.reduce(math.max))} '
                      '${measure.unitIn(context.l10n)}',
            style: AppTextStyles.itemTitle,
          ),
          const SizedBox(height: AppSpacing.md),
          ChartScrubber(
            count: ranges.length,
            indexAt: ChartScrubber.slots(ranges.length),
            idle: context.l10n.everyMinutes(
              minutes: (stretch.inSeconds / 60).round(),
            ),
            readoutOf: (index) {
              final start = from.add(stretch * index);
              return [
                '${formatTimeOfDay(start)}–'
                    '${formatTimeOfDay(start.add(stretch))}',
                switch (ranges[index]) {
                  (final low, final high) =>
                    '${_range(measure, low, high)} ${measure.unitIn(context.l10n)}',
                  null => context.l10n.noEntriesShort,
                },
              ].join(' · ');
            },
            builder: (context, selected) => RangeBarChart(
              ranges: ranges,
              color: color,
              labelOf: (value) => overnightNumber(measure, value),
              start: formatTimeOfDay(from),
              end: formatTimeOfDay(to),
              selected: selected,
            ),
          ),
        ],
      ),
    );
  }
}
