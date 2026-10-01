import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../backend/engines/sleep_metrics.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'sleep_goal_rows.dart';
import 'sleep_view_model.dart';
import '../../l10n/l10n.dart';

/// The days summed for the shortfall. Van Dongen 2003 saw restriction's
/// cost keep adding up over the 14 days it ran; that is why 14, not a
/// period after which a short night stops counting.
const shortfallDays = 14;

/// Days recorded, of the 14, before the sum is shown: Banks 2010 saw five
/// short nights already add up, and Oura asks as many. Fewer are a night
/// or two, not a debt.
const minimumShortfallDays = 5;

/// Days recorded before the sum stops being preliminary: a whole week,
/// working days and days off both.
const settledShortfallDays = 7;

/// How far back the trend reads.
enum _Range {
  month(30),
  quarter(91),
  half(182);

  const _Range(this.days);

  final int days;

  String labelIn(AppLocalizations l10n) => switch (this) {
    month => l10n.chartRangeMonth,
    quarter => l10n.monthsCount(count: 3),
    half => l10n.monthsCount(count: 6),
  };
}

/// 睡眠債: the last 14 days against the sleep goal, how far short they
/// fell, how that sum moved day by day over a month or more, how short
/// each night fell, and each of the 14 days' sleep. Called a
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
  _Range _range = _Range.month;

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
      // Each point of the trend sums the 14 days ending with it.
      final days = _model.shortfallDays(_range.days + shortfallDays - 1);
      final shown = days.sublist(shortfallDays - 1);
      final sums = [
        for (var end = shortfallDays; end <= days.length; end++)
          shortfallOf(days.sublist(end - shortfallDays, end), _model.need),
      ];
      final summed = shown.sublist(shown.length - shortfallDays);
      return DetailPage(
        appBar: PageAppBar(
          title: context.l10n.sleepDebtSection,
          subtitle: context.dates.dayWithWeekday(day),
        ),
        children: [
          Gutter(child: SleepShortfallCard(model: _model)),
          PageSection(
            label: context.l10n.trendSection,
            children: [
              Gutter(
                child: SegmentedChoice<_Range>(
                  options: _Range.values,
                  selected: _range,
                  labelOf: (range) => range.labelIn(context.l10n),
                  selectedColor: AppColors.wellness,
                  onChanged: (range) => setState(() => _range = range),
                ),
              ),
              Gutter(
                child: AppCard(
                  child: _chart([for (final day in shown) day.day], sums),
                ),
              ),
              Gutter(child: AppCard(child: _nights(shown))),
            ],
          ),
          PageSection(
            label: context.l10n.eachDaySection,
            children: [
              Gutter(
                child: GroupedCard(
                  children: [
                    for (final day in summed.reversed)
                      KeyValueRow(
                        label: context.dates.dayWithWeekday(day.day),
                        value: _dayValue(context.l10n, day.slept, _model.need),
                      ),
                  ],
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
        ],
      );
    },
  );

  /// The 14-day sum as of each day; a day whose 14 days hold too few
  /// records is a gap, not a zero.
  Widget _chart(List<DateTime> days, List<SleepShortfall> sums) {
    bool isShown(SleepShortfall sum) => sum.recorded >= minimumShortfallDays;
    final values = [
      for (final sum in sums) isShown(sum) ? sum.short.inMinutes / 60 : null,
    ];
    final known = [
      for (final sum in sums)
        if (isShown(sum)) sum.short,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CategoryLabel(
          label: context.l10n.rollingSum(count: shortfallDays),
          color: AppColors.wellness,
        ),
        const SizedBox(height: AppSpacing.sm),
        ChartScrubber(
          count: sums.length,
          indexAt: ChartScrubber.points(sums.length),
          idle: known.isEmpty
              ? context.l10n.notEnoughEntries
              : context.l10n.highestLowest(
                  high: _hours(
                    context.l10n,
                    known.reduce((a, b) => a > b ? a : b),
                  ),
                  low: _hours(
                    context.l10n,
                    known.reduce((a, b) => a < b ? a : b),
                  ),
                ),
          readoutOf: (index) => [
            context.dates.dayWithWeekday(days[index]),
            if (isShown(sums[index]))
              _hours(context.l10n, sums[index].short)
            else
              context.l10n.notEnoughEntries,
          ].join(' · '),
          builder: (context, selected) => Sparkline(
            values: values,
            color: AppColors.wellness,
            height: 160,
            selected: selected,
          ),
        ),
      ],
    );
  }

  /// How far each night fell short of the night it is read against: a
  /// night that was not short is a line on the axis, one without a
  /// record an empty slot, not a full night.
  Widget _nights(List<SleepDay> days) {
    final need = _model.need;
    int? shortOf(SleepDay day) => switch (day.slept) {
      final slept? => slept >= need ? 0 : (need - slept).inMinutes,
      null => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CategoryLabel(
          label: context.l10n.nightlyShortfall,
          color: AppColors.wellness,
        ),
        const SizedBox(height: AppSpacing.sm),
        ChartScrubber(
          count: days.length,
          indexAt: ChartScrubber.slots(days.length),
          idle: context.l10n.goalValue(
            goal: formatDuration(context.l10n, need),
          ),
          readoutOf: (index) {
            final day = days[index];
            return [
              context.dates.dayWithWeekday(day.day),
              switch (shortOf(day)) {
                null => context.l10n.noEntriesShort,
                0 => context.l10n.goalReached,
                final minutes => context.l10n.shortBy(
                  time: formatDuration(
                    context.l10n,
                    Duration(minutes: minutes),
                  ),
                ),
              },
            ].join(' · ');
          },
          builder: (context, selected) => MiniBarChart(
            bars: [for (final day in days) ('', shortOf(day))],
            height: 80,
            showLabels: false,
            color: AppColors.wellness,
            dimColor: AppColors.wellness.withValues(alpha: 0.45),
            selected: selected,
          ),
        ),
      ],
    );
  }
}

/// The 14 and 7 days ending with the model's day: time short of the
/// goal and time over it, kept apart, with the goal they are read
/// against and how many days had no record. Below
/// [minimumShortfallDays] recorded days there is no sum, only how many
/// more it takes.
class SleepShortfallCard extends StatelessWidget {
  const SleepShortfallCard({super.key, required this.model, this.onTap});

  final SleepViewModel model;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fortnight = model.shortfall(shortfallDays);
    final week = model.shortfall(DateTime.daysPerWeek);
    final isShown = fortnight.recorded >= minimumShortfallDays;
    final tags = [
      if (isShown && fortnight.recorded < settledShortfallDays)
        context.l10n.preliminary,
      if (model.goal == null)
        context.l10n.countedAt(hours: formatDuration(context.l10n, model.need))
      else
        context.l10n.goalValue(goal: formatDuration(context.l10n, model.need)),
      if (isShown && fortnight.missing > 0)
        context.l10n.daysWithoutEntries(count: fortnight.missing),
    ];
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueWithUnit(
            value: isShown ? _number(fortnight.short) : '—',
            unit: context.l10n.hoursUnit,
            style: AppTextStyles.hugeNumber.copyWith(
              color: isShown ? AppColors.wellness : AppColors.textTertiary,
            ),
          ),
          Text(
            isShown
                ? context.l10n.lastFortnightExtra(
                    hours: _hours(context.l10n, fortnight.extra),
                  )
                : context.l10n.needsLoggedDays(
                    minimum: minimumShortfallDays,
                    recorded: fortnight.recorded,
                  ),
            style: AppTextStyles.caption,
          ),
          if (isShown && week.recorded > 0)
            Text(
              context.l10n.lastWeekDebt(
                short: _hours(context.l10n, week.short),
                extra: _hours(context.l10n, week.extra),
              ),
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

/// `6.3 小時`, `6.3 h`.
String _hours(AppLocalizations l10n, Duration hours) =>
    l10n.hoursValue(hours: _number(hours));

/// A day's time asleep and how far it was from [need].
String _dayValue(AppLocalizations l10n, Duration? slept, Duration need) {
  if (slept == null) return l10n.noEntriesShort;
  final gap = slept - need;
  if (gap.inMinutes == 0) return formatDuration(l10n, slept);
  return '${formatDuration(l10n, slept)} · '
      '${gap.isNegative ? l10n.shortBy(time: formatDuration(l10n, -gap)) : l10n.overBy(time: formatDuration(l10n, gap))}';
}
