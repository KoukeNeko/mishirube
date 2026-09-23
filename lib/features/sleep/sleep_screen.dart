import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/application/sleep_service.dart';
import '../../backend/engines/sleep_nights.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../journal/sleep_entry_screen.dart';
import '../me/data_sources_screen.dart';
import 'sleep_stage_chart.dart';

/// One day's sleep: the night, what each stage took, what was measured
/// overnight, the day's naps, how nights have gone lately, and which
/// source it all comes from.
///
/// It shows what the source recorded and nothing it did not: no score, no
/// target for a stage, and time in bed is never called time asleep.
class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key, this.day});

  /// The day to open on; today when null.
  final DateTime? day;

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  late DateTime _day = _dayOf(widget.day ?? AppStoreScope.read(context).now());

  static DateTime _dayOf(DateTime time) =>
      DateTime(time.year, time.month, time.day);

  void _step(int days) =>
      setState(() => _day = DateTime(_day.year, _day.month, _day.day + days));

  Future<void> _delete(SleepRecord record) async {
    final store = AppStoreScope.read(context);
    final toast = ToastScope.read(context);
    final id = record.entry.id;
    store.deleteJournalEntry(id);
    toast.showUndo(
      '已刪除${record.entry.kind.label}',
      onUndo: () => store.restoreJournalEntry(id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final today = _dayOf(store.now());
    final sleeps = store.sleepOn(_day);
    final night = sleeps
        .where((record) => record.entry.kind == SleepKind.night)
        .firstOrNull;
    final naps = [
      for (final record in sleeps)
        if (record.entry.kind == SleepKind.nap) record,
    ];
    return DetailPage(
      appBar: PageAppBar(
        title: '睡眠',
        subtitle: '${_day.month} 月 ${_day.day} 日（週${weekdayLabel(_day)}）',
        actions: [
          HeaderAction(
            icon: Icons.chevron_left,
            semanticLabel: '前一天',
            onTap: () => _step(-1),
          ),
          HeaderAction(
            icon: Icons.chevron_right,
            semanticLabel: '後一天',
            onTap: _day.isBefore(today) ? () => _step(1) : null,
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
          Gutter(child: _Summary(record: night)),
          ..._stages(night),
          ..._readings(night),
        ],
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
        _History(day: _day),
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
                    NavRow(title: '刪除這筆紀錄', onTap: () => _delete(night)),
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
                    value: overnightValue(reading),
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
                          : () => store.chooseSleepSource(
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
  String number(double value) => switch (measure) {
    OvernightMeasure.wristTemperature ||
    OvernightMeasure.respiratoryRate => value.toStringAsFixed(1),
    OvernightMeasure.skinTemperatureChange =>
      '${value >= 0 ? '+' : '−'}${value.abs().toStringAsFixed(1)}',
    _ => value.round().toString(),
  };
  final low = number(reading.minimum);
  final high = number(reading.maximum);
  final range = low == high ? low : '$low–$high';
  return measure.unit.isEmpty ? range : '$range ${measure.unit}';
}

/// The night's length, what it measures and when it began and ended, and
/// where it came from.
class _Summary extends StatelessWidget {
  const _Summary({required this.record});

  final SleepRecord record;

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
          if (tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            TagWrap(labels: tags),
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
  const _History({required this.day});

  final DateTime day;

  @override
  State<_History> createState() => _HistoryState();
}

class _HistoryState extends State<_History> {
  _Range _range = _Range.week;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final end = widget.day.add(const Duration(days: 1));
    final start = end.subtract(Duration(days: _range.days));
    final nights = [
      for (final night in store.sleepNights(start, end))
        if (night.measure == SleepMeasure.asleep) night,
    ];
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
          Gutter(
            child: AppCard(
              child: MiniBarChart(
                bars: _bars(nights, start),
                height: 64,
                showLabels: _range == _Range.week,
                color: AppColors.wellness,
                dimColor: AppColors.wellness.withValues(alpha: 0.4),
              ),
            ),
          ),
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
                KeyValueRow(label: '紀錄晚數', value: '${nights.length} 晚'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// One bar a night for a week or a month, one a week for half a year;
  /// a night without a record is an empty bar, not a zero-hour night.
  List<(String, int)> _bars(List<SleepEntry> nights, DateTime start) {
    final byDay = {
      for (final night in nights)
        DateTime(night.sleptAt.year, night.sleptAt.month, night.sleptAt.day):
            night.duration.inMinutes,
    };
    final days = [
      for (var i = 0; i < _range.days; i++)
        DateTime(start.year, start.month, start.day + i),
    ];
    if (_range != _Range.halfYear) {
      return [for (final day in days) (weekdayLabel(day), byDay[day] ?? 0)];
    }
    return [
      for (var week = 0; week < days.length; week += DateTime.daysPerWeek)
        () {
          final minutes = [
            for (final day in days.skip(week).take(DateTime.daysPerWeek))
              ?byDay[day],
          ];
          return (
            '',
            minutes.isEmpty
                ? 0
                : minutes.reduce((a, b) => a + b) ~/ minutes.length,
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
