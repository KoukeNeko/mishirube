import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/application/sleep_service.dart';
import '../../backend/engines/overnight_series.dart';
import '../../backend/engines/sleep_metrics.dart';
import '../../backend/engines/sleep_nights.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../journal/sleep_entry_screen.dart';
import '../me/data_sources_screen.dart';
import 'sleep_schedule_chart.dart';
import 'sleep_stage_chart.dart';
import 'sleep_goal_rows.dart';
import 'sleep_view_model.dart';

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
      '已刪除${record.entry.kind.label}',
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
    return DetailPage(
      appBar: PageAppBar(
        title: '睡眠',
        subtitle: '${day.month} 月 ${day.day} 日（週${weekdayLabel(day)}）',
        actions: [
          HeaderAction(
            icon: Icons.chevron_left,
            semanticLabel: '前一天',
            onTap: () => _model.step(-1),
          ),
          HeaderAction(
            icon: Icons.chevron_right,
            semanticLabel: '後一天',
            onTap: _model.canGoForward ? () => _model.step(1) : null,
          ),
        ],
      ),
      children: [
        if (night == null && naps.isEmpty)
          Gutter(
            child: EmptyStateCard(
              icon: Icons.bedtime_outlined,
              title: '沒有睡眠紀錄',
              action: PrimaryButton(
                label: '手動記錄',
                onPressed: () => pushPage(context, const SleepEntryScreen()),
              ),
            ),
          ),
        if (night == null && naps.isEmpty)
          Gutter(
            child: Center(
              child: LinkText(
                label: '資料來源',
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
          ),
        ],
        ..._tonight(),
        if (naps.isNotEmpty)
          PageSection(
            label: '小睡',
            children: [
              for (final nap in naps)
                Gutter(
                  child: NavCard(
                    title: _span(nap.entry) ?? nap.entry.kind.label,
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
          label: '目標',
          children: [
            Gutter(
              child: GroupedCard(children: sleepGoalRows(context, _model)),
            ),
          ],
        ),
        if (night != null) ..._sources(night),
        if (night != null)
          PageSection(
            label: '管理',
            children: [
              Gutter(
                child: GroupedCard(
                  children: [
                    NavRow(
                      title: '編輯',
                      onTap: () => pushPage(
                        context,
                        SleepEntryScreen(editing: night.entry),
                      ),
                    ),
                    NavRow(
                      title: '刪除這筆紀錄',
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
          child: const GroupedCard(
            children: [KeyValueRow(label: '睡眠階段', value: '未提供')],
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
        label: '睡眠階段',
        children: [
          Gutter(
            child: AppCard(child: SleepStageChart(stages: record.stages)),
          ),
          Gutter(
            child: GroupedCard(
              children: [
                for (final MapEntry(key: stage, value: time) in totals.entries)
                  KeyValueRow(
                    label: stage.label,
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
        KeyValueRow(label: '入睡所需', value: '約 ${latency.inMinutes} 分'),
      if (efficiency != null)
        KeyValueRow(label: '睡眠效率', value: '${(efficiency * 100).round()}%'),
      if (awake != null)
        KeyValueRow(
          label: '夜間清醒',
          value: [
            formatHoursMinutes(awake),
            if (continuity.awakenings case final times? when times > 0)
              '醒來 $times 次',
          ].join(' · '),
        ),
    ];
    if (rows.isEmpty) return const [];
    return [
      PageSection(
        label: '連續性',
        children: [
          Gutter(child: GroupedCard(children: rows)),
          if (latency != null || efficiency != null)
            Gutter(child: const TagWrap(labels: ['依裝置的在床時間估算'])),
        ],
      ),
    ];
  }

  /// When to sleep tonight for the goal, and how the week has gone
  /// against it; only on today, with a goal.
  List<Widget> _tonight() {
    final plan = _model.tonightPlan;
    final shortfall = _model.weekShortfall;
    if (plan == null && shortfall == null) return const [];
    return [
      PageSection(
        label: '今晚',
        children: [
          Gutter(
            child: GroupedCard(
              children: [
                if (plan != null)
                  KeyValueRow(
                    label: '建議就寢',
                    value:
                        '${formatTimeOfDay(plan.bedtime)} · '
                        '${formatTimeOfDay(plan.wake)} 起床',
                  ),
                if (shortfall != null)
                  KeyValueRow(
                    label: '近 7 晚與目標',
                    value: shortfall.isNegative
                        ? '多 ${formatHoursMinutes(-shortfall)}'
                        : shortfall == Duration.zero
                        ? '相同'
                        : '少 ${formatHoursMinutes(shortfall)}',
                  ),
              ],
            ),
          ),
          if (plan != null) Gutter(child: const TagWrap(labels: ['依平常的起床時間'])),
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
        ('訓練後', factors.training),
        ('14:00 後有咖啡因', factors.lateCaffeine),
        ('21:00 後進食', factors.lateMeal),
      ])
        if (comparison != null)
          KeyValueRow(
            label: label,
            value:
                '${_signed(comparison.difference)} · '
                '${comparison.withCount} 晚對 ${comparison.withoutCount} 晚',
          ),
    ];
    if (rows.isEmpty) return const [];
    return [
      PageSection(
        label: '影響因素',
        children: [
          Gutter(child: GroupedCard(children: rows)),
          Gutter(child: const TagWrap(labels: ['近 90 天的平均睡著時間差', '相關，不代表因果'])),
        ],
      ),
    ];
  }

  static String _signed(Duration difference) => difference.isNegative
      ? '少睡 ${formatHoursMinutes(-difference)}'
      : '多睡 ${formatHoursMinutes(difference)}';

  List<Widget> _readings(SleepRecord record) {
    if (record.readings.isEmpty) return const [];
    return [
      PageSection(
        label: '夜間數據',
        children: [
          Gutter(
            child: GroupedCard(
              children: [
                for (final reading in record.readings)
                  KeyValueRow(
                    label: reading.measure.label,
                    value: [
                      overnightValue(reading),
                      if (_model.baseline(reading.measure) case final usual?
                          when reading.measure !=
                              OvernightMeasure.breathingDisturbances)
                        '平常 ${_number(reading.measure, usual.low)}–'
                            '${_number(reading.measure, usual.high)}',
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
          label: '來源',
          children: [
            Gutter(
              child: const GroupedCard(
                children: [KeyValueRow(label: '紀錄方式', value: '手動輸入')],
              ),
            ),
          ],
        ),
      ];
    }
    final shown = record.shownSource;
    return [
      PageSection(
        label: '來源',
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
                            ? '手動輸入'
                            : source.hasStages
                            ? '含睡眠階段'
                            : source.measure.label,
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

/// What was measured, as the platform reports it: a range, or one value
/// when the range is a single one; Apple's own reading for breathing
/// disturbances.
String overnightValue(OvernightReading reading) {
  final measure = reading.measure;
  if (measure == OvernightMeasure.breathingDisturbances) {
    return switch (reading.isElevated) {
      true => '升高',
      false => '未升高',
      null => formatAmount(reading.average),
    };
  }
  final low = _number(measure, reading.minimum);
  final high = _number(measure, reading.maximum);
  final range = low == high ? low : '$low–$high';
  return measure.unit.isEmpty ? range : '$range ${measure.unit}';
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
  String? _againstUsual(SleepEntry entry) {
    final usual = this.usual;
    if (usual == null || entry.measure != SleepMeasure.asleep) return null;
    final gap = entry.duration - usual;
    if (gap.inMinutes.abs() < 1) return '與近 28 晚平均相同';
    return '較近 28 晚平均 ${gap.isNegative ? '−' : '+'}'
        '${formatHoursMinutes(gap.abs())}';
  }

  /// The night against the goal: time in bed is not measured against a
  /// goal for sleep.
  String? _againstGoal(SleepEntry entry) {
    final goal = this.goal;
    if (goal == null || entry.measure != SleepMeasure.asleep) return null;
    final gap = entry.duration - goal;
    if (gap >= Duration.zero) return '目標 ${formatHoursMinutes(goal)} · 達成';
    return '目標 ${formatHoursMinutes(goal)} · 少 ${formatHoursMinutes(-gap)}';
  }

  @override
  Widget build(BuildContext context) {
    final entry = record.entry;
    final label = record.isTypedIn ? '紀錄的睡眠' : entry.measure.label;
    final tags = [
      if (record.isTypedIn)
        '手動輸入'
      else if (record.shownSource case final source?) ...[
        if (source.sourceName.isNotEmpty) source.sourceName,
        if (source.isManual) '手動輸入' else if (record.hasStages) '裝置估計',
      ],
      if (entry.score case final score?) '品質 $score / 5',
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
          if (_againstGoal(entry) case final line?)
            Text(line, style: AppTextStyles.caption),
          if (_againstUsual(entry) case final line?)
            Text(line, style: AppTextStyles.caption),
          if (naps.isNotEmpty)
            Text(
              '含小睡共 ${formatHoursMinutes(naps.fold(entry.duration, (sum, nap) => sum + nap.entry.duration))}',
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
  week('週', 7),
  month('月', 30),
  halfYear('6 個月', 182);

  const _Range(this.label, this.days);

  final String label;
  final int days;
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
      label: '趨勢',
      children: [
        Gutter(
          child: SegmentedChoice<_Range>(
            options: _Range.values,
            selected: _range,
            labelOf: (range) => range.label,
            onChanged: (range) => setState(() => _range = range),
            selectedColor: AppColors.wellness,
          ),
        ),
        if (nights.isEmpty)
          Gutter(
            child: const GroupedCard(
              children: [KeyValueRow(label: '睡著時間', value: '沒有紀錄')],
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
                  label: '平均睡著時間',
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
                  KeyValueRow(label: '平均入睡', value: bedtime),
                if (_averageClock([
                      for (final night in nights) night.sleptAt,
                    ], fromHour: 0)
                    case final wake?)
                  KeyValueRow(label: '平均起床', value: wake),
                if (regularityOf(nights) case final regularity?) ...[
                  KeyValueRow(
                    label: '入睡時間變動',
                    value: '±${regularity.bedtimeSpread.inMinutes} 分',
                  ),
                  KeyValueRow(
                    label: '起床時間變動',
                    value: '±${regularity.wakeSpread.inMinutes} 分',
                  ),
                ],
                KeyValueRow(label: '紀錄晚數', value: '${nights.length} 晚'),
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
    return ChartScrubber(
      count: bars.length,
      indexAt: ChartScrubber.slots(bars.length),
      idle: '平均 ${formatHoursMinutes(average)} · ${nights.length} 晚',
      readoutOf: (index) => bars[index].readout,
      builder: (context, selected) => MiniBarChart(
        bars: [for (final bar in bars) (bar.label, bar.minutes)],
        height: 64,
        showLabels: _range == _Range.week,
        color: AppColors.wellness,
        dimColor: AppColors.wellness.withValues(alpha: 0.4),
        selected: selected,
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
      idle: '入睡與起床 · ${timed.length} 晚',
      readoutOf: (index) {
        final night = timed[index];
        return '${_date(night.sleptAt)} · '
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
                label: '平均${stage.label}',
                value: stage.isAsleep && asleep > Duration.zero
                    ? '${formatHoursMinutes(time)} · '
                          '${(time.inSeconds * 100 / asleep.inSeconds).round()}%'
                    : formatHoursMinutes(time),
              ),
          ],
        ),
      ),
      Gutter(child: TagWrap(labels: ['${average.nights} 晚有睡眠階段', '裝置估計'])),
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
        '${measure.unit.isEmpty ? '' : ' ${measure.unit}'}';
    return [
      for (final (measure, readings) in rows)
        Gutter(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(measure.label, style: AppTextStyles.itemTitle),
                const SizedBox(height: AppSpacing.xxs),
                Semantics(
                  label: '${measure.label}走勢，${readings.length} 晚',
                  child: ChartScrubber(
                    count: readings.length,
                    indexAt: ChartScrubber.points(readings.length),
                    idle:
                        '平均 ${withUnit(measure, readings.map((r) => r.$2).reduce((a, b) => a + b) / readings.length)}'
                        ' · ${readings.length} 晚',
                    readoutOf: (index) =>
                        '${_date(readings[index].$1)} · '
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
  List<({String label, int minutes, String readout})> _bars(
    List<SleepEntry> nights,
    DateTime start,
  ) {
    final byDay = {
      for (final night in nights)
        DateTime(night.sleptAt.year, night.sleptAt.month, night.sleptAt.day):
            night.duration.inMinutes,
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
            label: weekdayLabel(day),
            minutes: byDay[day] ?? 0,
            readout:
                '${_date(day)} · '
                '${byDay[day] == null ? '沒有紀錄' : length(byDay[day]!)}',
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
              ? 0
              : minutes.reduce((a, b) => a + b) ~/ minutes.length;
          return (
            label: '',
            minutes: average,
            readout:
                '${first.month} 月 ${first.day} 日起一週 · '
                '${minutes.isEmpty ? '沒有紀錄' : '平均 ${length(average)} · ${minutes.length} 晚'}',
          );
        }(),
    ];
  }
}

/// `9 月 22 日（週一）`.
String _date(DateTime day) =>
    '${day.month} 月 ${day.day} 日（週${weekdayLabel(day)}）';

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
  });

  final Future<Map<OvernightMeasure, List<(DateTime, double)>>> series;
  final DateTime from;
  final DateTime to;

  static const _shown = [
    (OvernightMeasure.heartRate, '睡眠時心率', AppColors.heart),
    (OvernightMeasure.respiratoryRate, '睡眠時呼吸速率', AppColors.activity),
  ];

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: series,
      builder: (context, snapshot) {
        final byMeasure = snapshot.data ?? const {};
        return Column(
          spacing: pageItemSpacing,
          children: [
            for (final (measure, title, color) in _shown)
              if (byMeasure[measure] case final points? when points.isNotEmpty)
                Gutter(
                  child: _NightChartCard(
                    title: title,
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
    final lowText = _number(measure, values.reduce((a, b) => a < b ? a : b));
    final highText = _number(measure, values.reduce((a, b) => a > b ? a : b));
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CategoryLabel(label: title, color: color),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${lowText == highText ? lowText : '$lowText–$highText'} '
            '${measure.unit}',
            style: AppTextStyles.itemTitle,
          ),
          const SizedBox(height: AppSpacing.md),
          RangeBarChart(
            ranges: rangeBins(points, from, to),
            color: color,
            labelOf: (value) => _number(measure, value),
            start: formatTimeOfDay(from),
            end: formatTimeOfDay(to),
          ),
        ],
      ),
    );
  }
}
