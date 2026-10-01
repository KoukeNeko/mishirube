import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../app/view_model.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../activity/activity_metric_screen.dart';
import '../me/data_sources_screen.dart';
import '../trends/usual_range_trend.dart';
import 'vitals_view_model.dart';
import '../../l10n/l10n.dart';

/// What a health platform read of the heart and the vitals, each at its
/// last reading with the week up to it as a line under the figure, apart
/// from the body's own measurements on the body page, as Apple Health
/// keeps them. Each opens its own page; nothing here is called high or
/// low, and nothing is logged from here.
class VitalsScreen extends StatelessWidget {
  const VitalsScreen({super.key});

  @override
  Widget build(BuildContext context) => ViewModelBuilder(
    create: VitalsViewModel.new,
    builder: (context, model) {
      final heart = model.latestOf(ActivityMetricGroup.heart);
      final vitals = model.latestOf(ActivityMetricGroup.vitals);
      // A reading's days up to its last one, reaching back as far as
      // its week's usual ranges need.
      List<(DateTime, double)> Function(ActivityMetric) recentTo(
        DateTime day,
      ) =>
          (metric) =>
              model.daily(metric, day.subtract(UsualRangeSpark.reach), day);
      return DetailPage(
        appBar: PageAppBar(title: context.l10n.vitalsTitle),
        children: [
          if (heart.isEmpty && vitals.isEmpty) ...[
            Gutter(
              child: EmptyStateCard(
                icon: Icons.favorite_border,
                title: context.l10n.noVitalsData,
              ),
            ),
            Gutter(
              child: Center(
                child: LinkText(
                  label: context.l10n.dataSourcesLink,
                  onTap: () => pushPage(context, const DataSourcesScreen()),
                ),
              ),
            ),
          ],
          ..._heart(context, heart, recentTo),
          ..._vitals(context, vitals, recentTo),
        ],
      );
    },
  );

  /// A reading on its last [day], with its week under the figure,
  /// opening the reading's own page there.
  static NavRow _readingRow(
    BuildContext context,
    ActivityMetric metric,
    String title,
    String value,
    DateTime day,
    List<(DateTime, double)> Function(ActivityMetric) recent,
  ) => NavRow(
    title: title,
    subtitle: context.dates.monthDay(day),
    trailing: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(value, style: AppTextStyles.itemTitle),
        const SizedBox(height: AppSpacing.xxs),
        ReadingWeek(metric: metric, day: day, recent: recent),
      ],
    ),
    onTap: () => pushModalPage<void>(
      context,
      ActivityMetricScreen(metric: metric, day: day),
    ),
  );

  static List<Widget> _heart(
    BuildContext context,
    Map<ActivityMetric, (DateTime, double)> latest,
    List<(DateTime, double)> Function(ActivityMetric) Function(DateTime)
    recentTo,
  ) {
    if (latest.isEmpty) return const [];
    final l10n = context.l10n;
    return [
      Gutter(child: SectionLabel(ActivityMetricGroup.heart.labelIn(l10n))),
      Gutter(
        child: GroupedCard(
          children: [
            for (final MapEntry(key: metric, value: (day, value))
                in latest.entries)
              _readingRow(
                context,
                metric,
                metric.labelIn(l10n),
                withUnit(metric.format(value), metric.unitIn(l10n)),
                day,
                recentTo(day),
              ),
          ],
        ),
      ),
    ];
  }

  /// Blood pressure as the pair it is taken as.
  static List<Widget> _vitals(
    BuildContext context,
    Map<ActivityMetric, (DateTime, double)> latest,
    List<(DateTime, double)> Function(ActivityMetric) Function(DateTime)
    recentTo,
  ) {
    if (latest.isEmpty) return const [];
    final l10n = context.l10n;
    NavRow row(ActivityMetric metric, String title, String value) {
      final day = latest[metric]!.$1;
      return _readingRow(context, metric, title, value, day, recentTo(day));
    }

    String figure(ActivityMetric metric) =>
        withUnit(metric.format(latest[metric]!.$2), metric.unitIn(l10n));
    return [
      Gutter(child: SectionLabel(ActivityMetricGroup.vitals.labelIn(l10n))),
      Gutter(
        child: GroupedCard(
          children: [
            if (bloodPressureOf(latest) case final pressure?)
              row(
                ActivityMetric.bloodPressureSystolic,
                l10n.vitalBloodPressure,
                pressure,
              ),
            for (final metric in [
              ActivityMetric.bodyTemperature,
              ActivityMetric.respiratoryRate,
              ActivityMetric.oxygenSaturation,
            ])
              if (latest.containsKey(metric))
                row(metric, metric.labelIn(l10n), figure(metric)),
          ],
        ),
      ),
    ];
  }
}

/// [metric]'s week up to [day], drawn small beside its figure: a day's
/// lowest to highest heart rate, as the platform's samples have it, once
/// they are read; a blood pressure's diastolic to systolic, the pair it
/// is taken as; any other reading as a line against its usual range
/// ([UsualRangeSpark]). Heart rate falls back to that line where the
/// platform keeps no samples (see `research/87-vitals-presentation.md`).
class ReadingWeek extends StatefulWidget {
  const ReadingWeek({
    super.key,
    required this.metric,
    required this.day,
    required this.recent,
    this.width = 96,
    this.height = 28,
  });

  final ActivityMetric metric;
  final DateTime day;

  /// A metric's daily figures up to [day], reaching
  /// [UsualRangeSpark.reach] before it.
  final List<(DateTime, double)> Function(ActivityMetric metric) recent;
  final double width;
  final double height;

  @override
  State<ReadingWeek> createState() => _ReadingWeekState();
}

class _ReadingWeekState extends State<ReadingWeek> {
  Future<List<(DateTime, double)>>? _samples;

  DateTime get _first => DateTime(
    widget.day.year,
    widget.day.month,
    widget.day.day - (UsualRangeSpark.days - 1),
  );

  List<DateTime> get _days => [
    for (var i = 0; i < UsualRangeSpark.days; i++)
      DateTime(_first.year, _first.month, _first.day + i),
  ];

  /// Heart rate's samples over the week, read from the platform.
  Future<List<(DateTime, double)>> _read() async =>
      (await AppStoreScope.read(context).overnightSeries(
        _first,
        DateTime(widget.day.year, widget.day.month, widget.day.day + 1),
      ))[OvernightMeasure.heartRate] ??
      const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.metric == ActivityMetric.heartRate) _samples ??= _read();
  }

  @override
  void didUpdateWidget(ReadingWeek old) {
    super.didUpdateWidget(old);
    if (widget.metric == ActivityMetric.heartRate && old.day != widget.day) {
      _samples = _read();
    }
  }

  /// Each day's lowest to highest of [points].
  List<(double, double)?> _dailyRanges(List<(DateTime, double)> points) {
    final byDay = <DateTime, (double, double)>{};
    for (final (at, value) in points) {
      final day = DateTime(at.year, at.month, at.day);
      byDay[day] = switch (byDay[day]) {
        (final low, final high) => (
          value < low ? value : low,
          value > high ? value : high,
        ),
        null => (value, value),
      };
    }
    return [for (final day in _days) byDay[day]];
  }

  Widget _line() => UsualRangeSpark(
    points: widget.recent(widget.metric),
    day: widget.day,
    color: metricColor(widget.metric),
    formatRange: (low, high) => withUnit(
      '${widget.metric.format(low)}–${widget.metric.format(high)}',
      widget.metric.unitIn(context.l10n),
    ),
    width: widget.width,
    height: widget.height,
  );

  Widget _ranges(List<(double, double)?> ranges) => RangeSpark(
    ranges: ranges,
    color: metricColor(widget.metric),
    width: widget.width,
    height: widget.height,
  );

  @override
  Widget build(BuildContext context) {
    if (widget.metric == ActivityMetric.bloodPressureSystolic) {
      Map<DateTime, double> byDay(ActivityMetric metric) => {
        for (final (at, value) in widget.recent(metric))
          DateTime(at.year, at.month, at.day): value,
      };
      final systolic = byDay(ActivityMetric.bloodPressureSystolic);
      final diastolic = byDay(ActivityMetric.bloodPressureDiastolic);
      return _ranges([
        for (final day in _days)
          if ((diastolic[day], systolic[day]) case (final low?, final high?))
            (low, high)
          else
            null,
      ]);
    }
    final samples = _samples;
    if (samples == null) return _line();
    return FutureBuilder(
      future: samples,
      builder: (context, snapshot) => switch (snapshot.data) {
        // A platform that could not answer has the daily figures still.
        _ when snapshot.hasError => _line(),
        // Its place held while the platform answers.
        null => SizedBox(width: widget.width, height: widget.height),
        final points when points.isEmpty => _line(),
        final points => _ranges(_dailyRanges(points)),
      },
    );
  }
}
