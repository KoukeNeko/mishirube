import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../backend/engines/sleep_metrics.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'sleep_schedule_chart.dart';
import '../../l10n/l10n.dart';

/// The span the card reads, and the one before it it is set against.
const regularityWindowDays = 28;

/// Nights with both times the window needs before the index is shown: a
/// product rule for a figure steady enough to read, not a number from
/// the literature.
const _minimumNights = 14;

/// The nights drawn as rows: two weeks keeps each row readable.
const _shownNights = 14;

/// How regular the nights have been (see `research/80-sleep-regularity-card.md`):
/// the Sleep Regularity Index over the last four weeks against the four
/// before, each recent night as a row from falling asleep to waking, the
/// usual bedtime and waking, and how far weekends sit from weekdays. No
/// score out of a hundred, no good or bad: the rows show what the
/// number counts.
class SleepRegularityCard extends StatelessWidget {
  const SleepRegularityCard({
    super.key,
    required this.nights,
    required this.day,
  });

  /// Nights asleep over the last two windows, any order.
  final List<SleepEntry> nights;

  /// The day the window ends on.
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final end = DateTime(day.year, day.month, day.day + 1);
    final start = end.subtract(const Duration(days: regularityWindowDays));
    final recent = [
      for (final night in nights)
        if (!night.sleptAt.isBefore(start) && night.sleptAt.isBefore(end))
          night,
    ]..sort((a, b) => a.sleptAt.compareTo(b.sleptAt));
    final prior = [
      for (final night in nights)
        if (night.sleptAt.isBefore(start)) night,
    ];
    final timed = [
      for (final night in recent)
        if (night.startedAt != null) night,
    ];
    int? indexOf(List<SleepEntry> span) =>
        span.where((night) => night.startedAt != null).length < _minimumNights
        ? null
        : sleepRegularityIndex(span);
    final index = indexOf(recent);
    final before = indexOf(prior);
    final regularity = regularityOf(recent);
    final shown = timed
        .skip(timed.length > _shownNights ? timed.length - _shownNights : 0)
        .toList();
    // The figures' rows pad themselves, as in a GroupedCard; the rest
    // sits in from the card's edge.
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (index != null) ...[
                  ValueWithUnit(
                    value: '$index',
                    unit: null,
                    style: AppTextStyles.bigNumber,
                  ),
                  Text(
                    '${l10n.sleepRegularityIndexLabel} · '
                    '${l10n.lastDaysCount(count: regularityWindowDays)}',
                    style: AppTextStyles.caption,
                  ),
                  if (before != null)
                    Text(
                      '${l10n.priorDays(count: regularityWindowDays)} $before',
                      style: AppTextStyles.caption,
                    ),
                ] else
                  Text(
                    l10n.regularityNeeds(count: timed.length),
                    style: AppTextStyles.caption,
                  ),
                if (shown.length > 1) ...[
                  const SizedBox(height: AppSpacing.md),
                  ChartScrubber(
                    count: shown.length,
                    indexAt: ChartScrubber.rows(
                      shown.length,
                      SleepScheduleChart.rowExtentFor(shown.length),
                    ),
                    idle: l10n.scheduleChartLabel(count: shown.length),
                    readoutOf: (row) {
                      final night = shown[row];
                      return '${context.dates.dayWithWeekday(night.sleptAt)} · '
                          '${formatTimeOfDay(night.startedAt!)}–'
                          '${formatTimeOfDay(night.sleptAt)}';
                    },
                    builder: (context, selected) =>
                        SleepScheduleChart(nights: shown, selected: selected),
                  ),
                ],
                if (socialJetlag(recent) case final gap?) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(switch (gap.inMinutes) {
                    > 0 => l10n.weekendMidsleepLater(
                      time: formatHoursMinutes(gap),
                    ),
                    < 0 => l10n.weekendMidsleepEarlier(
                      time: formatHoursMinutes(-gap),
                    ),
                    _ => l10n.weekendMidsleepSame,
                  }, style: AppTextStyles.body),
                ],
              ],
            ),
          ),
          if (regularity != null) ...[
            KeyValueRow(
              label: l10n.averageBedtime,
              value:
                  '${_clock(regularity.bedtime)} · '
                  '${l10n.plusMinusMinutes(minutes: regularity.bedtimeSpread.inMinutes)}',
            ),
            KeyValueRow(
              label: l10n.averageWake,
              value:
                  '${_clock(regularity.wake)} · '
                  '${l10n.plusMinusMinutes(minutes: regularity.wakeSpread.inMinutes)}',
            ),
          ],
        ],
      ),
    );
  }
}

/// `23:42`: a time after midnight as a clock.
String _clock(Duration sinceMidnight) =>
    '${sinceMidnight.inHours.toString().padLeft(2, '0')}:'
    '${(sinceMidnight.inMinutes % 60).toString().padLeft(2, '0')}';
