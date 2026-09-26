import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../backend/engines/sleep_metrics.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'sleep_goal_rows.dart';
import 'sleep_view_model.dart';

/// The days summed for the shortfall. Van Dongen 2003 saw restriction's
/// cost keep adding up over the 14 days it ran; that is why 14, not a
/// period after which a short night stops counting.
const shortfallDays = 14;

/// 睡眠債: the last 14 days against the sleep goal, how far short they
/// fell, how that sum moved day by day, and each day's sleep. Called a
/// debt as other apps call it; it is the sum of the goal's shortfall,
/// not a quantity the body keeps.
class SleepShortfallScreen extends StatefulWidget {
  const SleepShortfallScreen({super.key, required this.day});

  /// The last day summed.
  final DateTime day;

  @override
  State<SleepShortfallScreen> createState() => _SleepShortfallScreenState();
}

class _SleepShortfallScreenState extends State<SleepShortfallScreen> {
  late final _model = SleepViewModel(
    AppStoreScope.read(context).backend,
    day: widget.day,
  );

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _model,
    builder: (context, _) {
      final day = _model.day;
      // Each point of the chart sums the 14 days ending with it.
      final days = _model.sleepDays(shortfallDays * 2 - 1);
      final shown = days.sublist(shortfallDays - 1);
      final sums = [
        for (var end = shortfallDays; end <= days.length; end++)
          shortfallOf(days.sublist(end - shortfallDays, end), _model.need),
      ];
      return DetailPage(
        appBar: PageAppBar(
          title: '睡眠債',
          subtitle: '${day.month} 月 ${day.day} 日（週${weekdayLabel(day)}）',
        ),
        children: [
          Gutter(child: SleepShortfallCard(model: _model)),
          PageSection(
            label: '走勢',
            children: [
              Gutter(
                child: AppCard(
                  child: _chart([for (final day in shown) day.day], sums),
                ),
              ),
            ],
          ),
          PageSection(
            label: '每天',
            children: [
              Gutter(
                child: GroupedCard(
                  children: [
                    for (final day in shown.reversed)
                      KeyValueRow(
                        label: _date(day.day),
                        value: _dayValue(day.slept, _model.need),
                      ),
                  ],
                ),
              ),
            ],
          ),
          PageSection(
            label: '目標',
            children: [
              Gutter(
                child: GroupedCard(children: sleepGoalRows(context, _model)),
              ),
            ],
          ),
        ],
      );
    },
  );

  /// The 14-day sum as of each day; a day whose 14 days hold no record
  /// is a gap, not a zero.
  Widget _chart(List<DateTime> days, List<SleepShortfall> sums) {
    double? hours(SleepShortfall sum) =>
        sum.recorded == 0 ? null : sum.short.inMinutes / 60;
    final values = [for (final sum in sums) hours(sum)];
    final known = [
      for (final sum in sums)
        if (sum.recorded > 0) sum.short,
    ];
    return ChartScrubber(
      count: sums.length,
      indexAt: ChartScrubber.points(sums.length),
      idle: known.isEmpty
          ? '沒有紀錄'
          : '最高 ${_hours(known.reduce((a, b) => a > b ? a : b))}'
                ' · 最低 ${_hours(known.reduce((a, b) => a < b ? a : b))}',
      readoutOf: (index) => [
        _date(days[index]),
        if (sums[index].recorded == 0) '沒有紀錄' else _hours(sums[index].short),
      ].join(' · '),
      builder: (context, selected) => Sparkline(
        values: values,
        color: AppColors.wellness,
        height: 64,
        selected: selected,
      ),
    );
  }
}

/// The 14 and 7 days ending with the model's day: time short of the
/// goal and time over it, kept apart, with the goal they are read
/// against and how many days had no record.
class SleepShortfallCard extends StatelessWidget {
  const SleepShortfallCard({super.key, required this.model, this.onTap});

  final SleepViewModel model;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fortnight = model.shortfall(shortfallDays);
    final week = model.shortfall(DateTime.daysPerWeek);
    final tags = [
      if (model.goal == null)
        '以 ${formatHoursMinutes(model.need)} 計'
      else
        '目標 ${formatHoursMinutes(model.need)}',
      if (fortnight.missing > 0) '${fortnight.missing} 天沒有紀錄',
    ];
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueWithUnit(
            value: _number(fortnight.short),
            unit: '小時',
            style: AppTextStyles.hugeNumber.copyWith(color: AppColors.wellness),
          ),
          Text(
            '近 14 天 · 多睡 ${_hours(fortnight.extra)}',
            style: AppTextStyles.caption,
          ),
          if (week.recorded > 0)
            Text(
              '近 7 天 ${_hours(week.short)} · 多睡 ${_hours(week.extra)}',
              style: AppTextStyles.caption,
            ),
          const SizedBox(height: AppSpacing.sm),
          TagWrap(labels: tags),
        ],
      ),
    );
  }
}

/// A sum of hours to one decimal, `6.3`, as other apps write a debt; a
/// night's own length stays `h:mm`.
String _number(Duration hours) => (hours.inMinutes / 60).toStringAsFixed(1);

/// `6.3 小時`.
String _hours(Duration hours) => '${_number(hours)} 小時';

/// A day's time asleep and how far it was from [need].
String _dayValue(Duration? slept, Duration need) {
  if (slept == null) return '沒有紀錄';
  final gap = slept - need;
  if (gap.inMinutes == 0) return formatHoursMinutes(slept);
  return '${formatHoursMinutes(slept)} · '
      '${gap.isNegative ? '少 ${formatHoursMinutes(-gap)}' : '多 ${formatHoursMinutes(gap)}'}';
}

/// `9 月 22 日（週一）`.
String _date(DateTime day) =>
    '${day.month} 月 ${day.day} 日（週${weekdayLabel(day)}）';
