import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/application/sleep_service.dart';
import '../../backend/engines/overnight_series.dart';
import '../../backend/engines/sleep_nights.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../journal/sleep_entry_screen.dart';
import '../me/data_sources_screen.dart';
import 'sleep_regularity_card.dart';
import 'sleep_schedule_chart.dart';
import 'sleep_shortfall_screen.dart';
import 'sleep_stage_chart.dart';
import 'sleep_goal_rows.dart';
import 'sleep_view_model.dart';
import '../../l10n/l10n.dart';

/// One day's sleep: the night, what each stage took, what was measured
/// overnight, the day's naps, how nights have gone lately, and which
/// source it all comes from.
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
        if (_model.nightsAsleep(2 * regularityWindowDays) case final nights
            when nights.any((night) => night.startedAt != null))
          PageSection(
            label: context.l10n.sleepRegularitySection,
            children: [
              Gutter(
                child: SleepRegularityCard(nights: nights, day: day),
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
        _History(model: _model),
        ..._factors(),
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
    final totals = stageTotals(record.stages);
    final asleep = totals.entries
        .where((entry) => entry.key.isAsleep)
        .fold(Duration.zero, (sum, entry) => sum + entry.value);
    return [
      PageSection(
        label: context.l10n.sleepStagesSection,
        children: [
          Gutter(
            child: AppCard(child: SleepStageChart(stages: record.stages)),
          ),
          Gutter(
            child: GroupedCard(
              children: [
                for (final MapEntry(key: stage, value: time) in totals.entries)
                  KeyValueRow(
                    label: stage.labelIn(context.l10n),
                    // A stage's share is of time asleep; time awake is
                    // not part of it.
                    value: stage.isAsleep && asleep > Duration.zero
                        ? '${formatHoursMinutes(time)} · '
                              '${(time.inSeconds * 100 / asleep.inSeconds).round()}%'
                        : formatHoursMinutes(time),
                  ),
              ],
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

  /// Nights after training, late caffeine or a late meal against the
  /// others, with how many nights each side has. Only what both sides
  /// have enough nights for.
  List<Widget> _factors() {
    final factors = _model.factors;
    final rows = [
      for (final (label, comparison) in [
        (context.l10n.afterTraining, factors.training),
        (context.l10n.caffeineAfter2pm, factors.lateCaffeine),
        (context.l10n.mealAfter9pm, factors.lateMeal),
      ])
        if (comparison != null)
          KeyValueRow(
            label: label,
            value:
                '${_signed(context.l10n, comparison.difference)} · '
                '${context.l10n.nightsVersus(withCount: comparison.withCount, withoutCount: comparison.withoutCount)}',
          ),
    ];
    if (rows.isEmpty) return const [];
    return [
      PageSection(
        label: context.l10n.factorsSection,
        children: [
          Gutter(child: GroupedCard(children: rows)),
          Gutter(
            child: TagWrap(
              labels: [
                context.l10n.factorsBasis,
                context.l10n.correlationNotCause,
              ],
            ),
          ),
        ],
      ),
    ];
  }

  static String _signed(AppLocalizations l10n, Duration difference) =>
      difference.isNegative
      ? l10n.sleptLess(time: formatHoursMinutes(-difference))
      : l10n.sleptMore(time: formatHoursMinutes(difference));

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
                              '${_number(reading.measure, usual.low)}–'
                              '${_number(reading.measure, usual.high)}',
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
String _number(OvernightMeasure measure, double value) => switch (measure) {
  OvernightMeasure.wristTemperature ||
  OvernightMeasure.respiratoryRate => value.toStringAsFixed(1),
  OvernightMeasure.skinTemperatureChange =>
    '${value >= 0 ? '+' : '−'}${value.abs().toStringAsFixed(1)}',
  _ => value.round().toString(),
};

/// `52–68`, or one value when both ends read the same.
String _range(OvernightMeasure measure, double low, double high) {
  final lowText = _number(measure, low);
  final highText = _number(measure, high);
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

enum _Range {
  week(7),
  month(30),
  halfYear(182);

  const _Range(this.days);

  final int days;

  String labelIn(AppLocalizations l10n) => switch (this) {
    week => l10n.chartRangeWeek,
    month => l10n.chartRangeMonth,
    halfYear => l10n.chartRangeSixMonths,
  };
}

/// How nights have gone up to the day shown: each night's length, their
/// average, and when they usually began and ended. Naps are not nights
/// and time in bed is not sleep, so neither is counted.
class _History extends StatefulWidget {
  const _History({required this.model});

  final SleepViewModel model;

  @override
  State<_History> createState() => _HistoryState();
}

class _HistoryState extends State<_History> {
  _Range _range = _Range.week;

  @override
  Widget build(BuildContext context) {
    final end = widget.model.day.add(const Duration(days: 1));
    final start = end.subtract(Duration(days: _range.days));
    final nights = widget.model.nightsAsleep(_range.days);
    return PageSection(
      label: context.l10n.tabTrends,
      children: [
        Gutter(
          child: SegmentedChoice<_Range>(
            options: _Range.values,
            selected: _range,
            labelOf: (range) => range.labelIn(context.l10n),
            onChanged: (range) => setState(() => _range = range),
            selectedColor: AppColors.wellness,
          ),
        ),
        if (nights.isEmpty)
          Gutter(
            child: GroupedCard(
              children: [
                KeyValueRow(
                  label: context.l10n.sleepMeasureAsleep,
                  value: context.l10n.noEntriesShort,
                ),
              ],
            ),
          )
        else ...[
          Gutter(child: AppCard(child: _lengthChart(nights, start))),
          if (_range != _Range.halfYear &&
              nights.where((night) => night.startedAt != null).length > 1)
            Gutter(child: AppCard(child: _scheduleChart(nights))),
          Gutter(
            child: GroupedCard(
              children: [
                KeyValueRow(
                  label: context.l10n.averageTimeAsleep,
                  value: formatHoursMinutes(
                    nights.fold(
                          Duration.zero,
                          (sum, night) => sum + night.duration,
                        ) ~/
                        nights.length,
                  ),
                ),
                // Bedtimes straddle midnight, so they are averaged from
                // noon; waking straddles nothing, so from midnight.
                if (_averageClock([
                      for (final night in nights) ?night.startedAt,
                    ], fromHour: 12)
                    case final bedtime?)
                  KeyValueRow(
                    label: context.l10n.averageBedtime,
                    value: bedtime,
                  ),
                if (_averageClock([
                      for (final night in nights) night.sleptAt,
                    ], fromHour: 0)
                    case final wake?)
                  KeyValueRow(label: context.l10n.averageWake, value: wake),
                KeyValueRow(
                  label: context.l10n.nightsRecorded,
                  value: context.l10n.nightsCount(count: nights.length),
                ),
              ],
            ),
          ),
          ..._stageAverages(),
          ..._vitals(),
        ],
      ],
    );
  }

  /// Each night's length; reading a bar says its night.
  Widget _lengthChart(List<SleepEntry> nights, DateTime start) {
    final bars = _bars(nights, start);
    final average =
        nights.fold(Duration.zero, (sum, night) => sum + night.duration) ~/
        nights.length;
    final goal = widget.model.goal;
    final metCount = bars.where((bar) => bar.isMet).length;
    return ChartScrubber(
      count: bars.length,
      indexAt: ChartScrubber.slots(bars.length),
      idle: [
        context.l10n.statAverage(value: formatHoursMinutes(average)),
        context.l10n.nightsCount(count: nights.length),
        if (metCount > 0) context.l10n.goalMetNights(count: metCount),
      ].join(' · '),
      readoutOf: (index) => bars[index].readout,
      builder: (context, selected) => MiniBarChart(
        bars: [for (final bar in bars) (bar.label, bar.minutes)],
        height: 64,
        showLabels: _range == _Range.week,
        color: AppColors.wellness,
        dimColor: AppColors.wellness.withValues(alpha: 0.4),
        selected: selected,
        goal: goal?.inMinutes,
        met: {
          for (final (index, bar) in bars.indexed)
            if (bar.isMet) index,
        },
      ),
    );
  }

  /// Each night from falling asleep to waking; reading a row says its
  /// times.
  Widget _scheduleChart(List<SleepEntry> nights) {
    final timed = [
      for (final night in nights)
        if (night.startedAt != null) night,
    ];
    return ChartScrubber(
      count: timed.length,
      indexAt: ChartScrubber.rows(
        timed.length,
        SleepScheduleChart.rowExtentFor(timed.length),
      ),
      idle:
          '${context.l10n.bedAndWake} · '
          '${context.l10n.nightsCount(count: timed.length)}',
      readoutOf: (index) {
        final night = timed[index];
        return '${context.dates.dayWithWeekday(night.sleptAt)} · '
            '${formatTimeOfDay(night.startedAt!)}–'
            '${formatTimeOfDay(night.sleptAt)} · '
            '${formatHoursMinutes(night.duration)}';
      },
      builder: (context, selected) =>
          SleepScheduleChart(nights: timed, selected: selected),
    );
  }

  /// Each stage's average a night, over the nights that were staged.
  List<Widget> _stageAverages() {
    final average = widget.model.averageStages(_range.days);
    if (average.nights == 0) return const [];
    final asleep = average.stages.entries
        .where((entry) => entry.key.isAsleep)
        .fold(Duration.zero, (sum, entry) => sum + entry.value);
    return [
      Gutter(
        child: GroupedCard(
          children: [
            for (final MapEntry(key: stage, value: time)
                in average.stages.entries)
              KeyValueRow(
                label: context.l10n.averageStage(
                  stage: stage.labelIn(context.l10n),
                ),
                value: stage.isAsleep && asleep > Duration.zero
                    ? '${formatHoursMinutes(time)} · '
                          '${(time.inSeconds * 100 / asleep.inSeconds).round()}%'
                    : formatHoursMinutes(time),
              ),
          ],
        ),
      ),
      Gutter(
        child: TagWrap(
          labels: [
            context.l10n.nightsWithStages(count: average.nights),
            context.l10n.deviceEstimate,
          ],
        ),
      ),
    ];
  }

  /// Each overnight reading's nightly average across the range.
  List<Widget> _vitals() {
    final rows = [
      for (final measure in OvernightMeasure.values)
        if (measure != OvernightMeasure.breathingDisturbances)
          if (widget.model.nightlyAverages(measure, _range.days)
              case final values when values.length > 1)
            (measure, values),
    ];
    if (rows.isEmpty) return const [];
    String withUnit(OvernightMeasure measure, double value) =>
        '${_number(measure, value)}'
        '${measure.unitIn(context.l10n).isEmpty ? '' : ' ${measure.unitIn(context.l10n)}'}';
    return [
      for (final (measure, readings) in rows)
        Gutter(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  measure.labelIn(context.l10n),
                  style: AppTextStyles.itemTitle,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Semantics(
                  label: context.l10n.trendOverNights(
                    measure: measure.labelIn(context.l10n),
                    count: readings.length,
                  ),
                  child: ChartScrubber(
                    count: readings.length,
                    indexAt: ChartScrubber.points(readings.length),
                    idle:
                        '${context.l10n.statAverage(value: withUnit(measure, readings.map((r) => r.$2).reduce((a, b) => a + b) / readings.length))}'
                        ' · ${context.l10n.nightsCount(count: readings.length)}',
                    readoutOf: (index) =>
                        '${context.dates.dayWithWeekday(readings[index].$1)} · '
                        '${withUnit(measure, readings[index].$2)}',
                    builder: (context, selected) => Sparkline(
                      values: [for (final (_, value) in readings) value],
                      color: AppColors.wellness,
                      height: 40,
                      selected: selected,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  /// One bar a night for a week or a month, one a week for half a year,
  /// each with what its reading says; a night without a record is an
  /// empty bar, not a zero-hour night.
  List<({String label, int? minutes, String readout, bool isMet})> _bars(
    List<SleepEntry> nights,
    DateTime start,
  ) {
    DateTime dayOf(SleepEntry night) =>
        DateTime(night.sleptAt.year, night.sleptAt.month, night.sleptAt.day);
    final byDay = {
      for (final night in nights) dayOf(night): night.duration.inMinutes,
    };
    // Time in bed is not held against a goal for sleep.
    final goal = widget.model.goal;
    final metDays = {
      for (final night in nights)
        if (goal != null &&
            night.measure == SleepMeasure.asleep &&
            night.duration >= goal)
          dayOf(night),
    };
    final days = [
      for (var i = 0; i < _range.days; i++)
        DateTime(start.year, start.month, start.day + i),
    ];
    String length(int minutes) =>
        formatHoursMinutes(Duration(minutes: minutes));
    if (_range != _Range.halfYear) {
      return [
        for (final day in days)
          (
            label: context.dates.weekday(day),
            minutes: byDay[day],
            readout: [
              context.dates.dayWithWeekday(day),
              if (byDay[day] case final minutes?)
                length(minutes)
              else
                context.l10n.noEntriesShort,
              if (metDays.contains(day)) context.l10n.goalReached,
            ].join(' · '),
            isMet: metDays.contains(day),
          ),
      ];
    }
    return [
      for (var week = 0; week < days.length; week += DateTime.daysPerWeek)
        () {
          final first = days[week];
          final minutes = [
            for (final day in days.skip(week).take(DateTime.daysPerWeek))
              ?byDay[day],
          ];
          final average = minutes.isEmpty
              ? null
              : minutes.reduce((a, b) => a + b) ~/ minutes.length;
          return (
            label: '',
            minutes: average,
            isMet: false,
            readout:
                '${context.l10n.weekOf(date: context.dates.monthDay(first))} · '
                '${average == null ? context.l10n.noEntriesShort : '${context.l10n.statAverage(value: length(average))} · ${context.l10n.nightsCount(count: minutes.length)}'}',
          );
        }(),
    ];
  }
}

/// The average time of day of [times], counted from [fromHour] so the
/// times fall in one unbroken stretch: from noon, 23:30 and 00:30 average
/// to midnight rather than noon. Null when empty.
String? _averageClock(List<DateTime> times, {required int fromHour}) {
  if (times.isEmpty) return null;
  const day = Duration.minutesPerDay;
  final from = fromHour * 60;
  final shifted = [
    for (final time in times) (time.hour * 60 + time.minute - from) % day,
  ];
  final average =
      (shifted.reduce((a, b) => a + b) ~/ shifted.length + from) % day;
  final hours = average ~/ 60;
  final minutes = average % 60;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}';
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
              labelOf: (value) => _number(measure, value),
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
