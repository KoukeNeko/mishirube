import 'package:flutter/material.dart';

import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/engines/caffeine.dart';
import '../../backend/engines/caffeine_history.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../nutrition/meal_detail_screen.dart';
import 'caffeine_view_model.dart';
import '../../l10n/l10n.dart';

/// Days the list of last intakes reaches back over.
const _lastIntakeDays = 7;

/// The caffeine page below the last 24 hours: the last 28 days as the
/// records say them. Only what the user logged: no limit, no usual range,
/// and nothing set against sleep.
List<Widget> caffeineHistorySections(
  BuildContext context,
  CaffeineViewModel model,
) {
  final history = model.history;
  final usualBedtime = model.usualBedtime;
  final hasCompleteDay = history.days.any((day) => day.isComplete);
  final hasRecords = history.days.any((day) => day.records.isNotEmpty);
  return [
    if (hasCompleteDay) _DailySection(history: history),
    if (hasRecords) ...[
      _LastIntakeSection(history: history, usualBedtime: usualBedtime),
      if (usualBedtime != null && history.atBedtime.any((mg) => mg != null))
        _BedtimeSection(history: history),
      _SourcesSection(history: history),
      _BandsSection(history: history),
    ],
    if (hasCompleteDay) _WeekdaySection(history: history),
  ];
}

String _mg(double milligrams) =>
    '${formatAmount(milligrams.roundToDouble())} mg';

(String, String) _ends(BuildContext context, CaffeineHistory history) => context
    .dates
    .compactSpanEnds(history.days.first.day, history.days.last.day);

Color _dim(Color color) => color.withValues(alpha: 0.45);

class _DailySection extends StatelessWidget {
  const _DailySection({required this.history});

  final CaffeineHistory history;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final days = history.days;
    final (from, to) = _ends(context, history);
    final average = history.average;
    final highest = history.highest;
    return PageSection(
      label: l10n.caffeineDailySection,
      children: [
        Gutter(
          child: AppCard(
            child: ChartScrubber(
              count: days.length,
              indexAt: ChartScrubber.slots(days.length),
              idle: '$from–$to',
              readoutOf: (index) => [
                context.dates.dayWithWeekday(days[index].day),
                switch (days[index].completeTotal) {
                  final total? => _mg(total),
                  null => l10n.noEntriesShort,
                },
              ].join(' · '),
              builder: (context, selected) => MiniBarChart(
                bars: [
                  for (final day in days) ('', day.completeTotal?.round()),
                ],
                height: 96,
                showLabels: false,
                color: AppColors.caffeine,
                dimColor: _dim(AppColors.caffeine),
                selected: selected,
                highlightsLast: false,
              ),
            ),
          ),
        ),
        Gutter(
          child: FigureGrid(
            figures: [
              (
                label: l10n.statAverageLabel,
                value: average == null
                    ? '—'
                    : formatAmount(average.roundToDouble()),
                unit: average == null ? null : 'mg',
                color: null,
              ),
              (
                label: l10n.statHighest,
                value: highest == null
                    ? '—'
                    : formatAmount(highest.roundToDouble()),
                unit: highest == null ? null : 'mg',
                color: null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A time of day as minutes on the chart's clock, which runs from
/// midnight; a bedtime after midnight is the end of that clock's day.
double _clockMinutes(DateTime at) => (at.hour * 60 + at.minute).toDouble();

class _LastIntakeSection extends StatelessWidget {
  const _LastIntakeSection({required this.history, required this.usualBedtime});

  final CaffeineHistory history;
  final Duration? usualBedtime;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final days = history.days;
    final ranges = [
      for (final day in days)
        if (day.first case final first? when day.last != null)
          (_clockMinutes(first.at), _clockMinutes(day.last!.at))
        else
          null,
    ];
    final (from, to) = _ends(context, history);
    final recent = [
      for (final day in days.reversed.take(_lastIntakeDays))
        if (day.last != null) day,
    ];
    return PageSection(
      label: l10n.caffeineLastIntakeSection,
      children: [
        Gutter(
          child: AppCard(
            child: ChartScrubber(
              count: days.length,
              indexAt: ChartScrubber.slots(days.length),
              idle: '$from–$to',
              readoutOf: (index) {
                final day = days[index];
                return [
                  context.dates.dayWithWeekday(day.day),
                  switch ((day.first, day.last)) {
                    (final first?, final last?) =>
                      '${formatTimeOfDay(first.at)}–${formatTimeOfDay(last.at)}',
                    _ => l10n.noEntriesShort,
                  },
                ].join(' · ');
              },
              builder: (context, selected) => RangeBarChart(
                ranges: ranges,
                color: AppColors.caffeine,
                labelOf: (minutes) => formatMinutesOfDay(minutes.round()),
                start: from,
                end: to,
                selected: selected,
                downward: true,
                levels: [
                  if (usualBedtime case final bedtime?)
                    // After midnight is the end of the day on this clock.
                    (bedtime < const Duration(hours: 12)
                            ? bedtime + const Duration(days: 1)
                            : bedtime)
                        .inMinutes
                        .toDouble(),
                ],
              ),
            ),
          ),
        ),
        for (final day in recent)
          Gutter(
            child: NavCard(
              title: context.dates.dayWithWeekday(day.day),
              subtitle: [
                l10n.lastIntakeAt(time: formatTimeOfDay(day.last!.at)),
                if (caffeineBeforeBedtime(day.last!.at, usualBedtime)
                    case final before?)
                  l10n.timeBeforeBedtime(time: formatDuration(l10n, before)),
              ].join(' · '),
              trailing: Text(
                _mg(day.last!.milligrams),
                style: AppTextStyles.itemTitle,
              ),
              onTap: () =>
                  pushPage(context, MealDetailScreen(meal: day.last!.meal)),
            ),
          ),
      ],
    );
  }
}

class _BedtimeSection extends StatelessWidget {
  const _BedtimeSection({required this.history});

  final CaffeineHistory history;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final days = history.days;
    final values = history.atBedtime;
    final (from, to) = _ends(context, history);
    return PageSection(
      label: l10n.caffeineAtBedtimeSection,
      children: [
        Gutter(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChartScrubber(
                  count: days.length,
                  indexAt: ChartScrubber.points(days.length),
                  idle: '$from–$to',
                  readoutOf: (index) => [
                    context.dates.dayWithWeekday(days[index].day),
                    switch (values[index]) {
                      final mg? => _mg(mg),
                      null => l10n.noEntriesShort,
                    },
                  ].join(' · '),
                  builder: (context, selected) => Sparkline(
                    values: values,
                    color: AppColors.caffeine,
                    height: 120,
                    selected: selected,
                    isEstimate: true,
                    levels: [
                      ChartLevel(
                        value: caffeineBedtimeReferenceMg,
                        from: 0,
                        to: days.length - 1,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xxs,
                  children: [
                    ChartKey(
                      color: AppColors.textSecondary,
                      label: l10n.caffeineReference(
                        mg: formatAmount(caffeineBedtimeReferenceMg),
                      ),
                    ),
                    Text(
                      l10n.halfLifeBasis(
                        hours: formatAmount(caffeineHalfLifeHours),
                      ),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SourcesSection extends StatelessWidget {
  const _SourcesSection({required this.history});

  final CaffeineHistory history;

  /// Each source's share of the bar, from the strongest colour down.
  static const _shades = [1.0, 0.75, 0.55, 0.4, 0.28];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sources = history.sources;
    Color shade(int index) =>
        AppColors.caffeine.withValues(alpha: _shades[index]);
    return PageSection(
      label: l10n.sourceLabel,
      children: [
        Gutter(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentBar(
                  segments: [
                    for (final (index, source) in sources.indexed)
                      (source.milligrams, shade(index)),
                  ],
                ),
                for (final (index, source) in sources.indexed)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Row(
                      children: [
                        Expanded(
                          child: CategoryLabel(
                            label: source.name,
                            color: shade(index),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '${_mg(source.milligrams)} · '
                          '${l10n.timesCount(count: source.count)}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BandsSection extends StatelessWidget {
  const _BandsSection({required this.history});

  final CaffeineHistory history;

  /// `12–15`, and `21–24` for the last band.
  static String _label(int band) {
    String hour(int value) => value.toString().padLeft(2, '0');
    final end = band + 1 < caffeineBandStartHours.length
        ? caffeineBandStartHours[band + 1]
        : 24;
    return '${hour(caffeineBandStartHours[band])}–${hour(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bands = history.bands;
    final (from, to) = _ends(context, history);
    return PageSection(
      label: l10n.timeOfDaySection,
      children: [
        Gutter(
          child: AppCard(
            child: ChartScrubber(
              count: bands.length,
              indexAt: ChartScrubber.slots(bands.length),
              idle: '$from–$to',
              readoutOf: (index) => '${_label(index)} · ${_mg(bands[index])}',
              builder: (context, selected) => MiniBarChart(
                bars: [
                  for (final (index, milligrams) in bands.indexed)
                    (_label(index), milligrams.round()),
                ],
                height: 96,
                color: AppColors.caffeine,
                dimColor: _dim(AppColors.caffeine),
                selected: selected,
                highlightsLast: false,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WeekdaySection extends StatelessWidget {
  const _WeekdaySection({required this.history});

  final CaffeineHistory history;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Figure figure(String label, double? average) => (
      label: label,
      value: average == null ? '—' : formatAmount(average.roundToDouble()),
      unit: average == null ? null : 'mg',
      color: null,
    );
    return PageSection(
      label: l10n.weekdaysAndDaysOffSection,
      children: [
        Gutter(
          child: FigureGrid(
            figures: [
              figure(l10n.weekdaysLabel, history.weekdayAverage),
              figure(l10n.daysOffLabel, history.weekendAverage),
            ],
          ),
        ),
      ],
    );
  }
}
