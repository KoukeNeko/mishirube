import 'package:flutter/material.dart';

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
      // A reading's week up to its last day, with the weeks before it
      // that the week's usual ranges are drawn from.
      List<(DateTime, double)> recent(ActivityMetric metric, DateTime day) =>
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
          ..._heart(context, heart, recent),
          ..._vitals(context, vitals, recent),
        ],
      );
    },
  );

  /// A reading on its last [day], with its week as a line under the
  /// figure when [recent] is given, opening the reading's own page there.
  static NavRow _readingRow(
    BuildContext context,
    ActivityMetric metric,
    String title,
    String value,
    DateTime day, {
    List<(DateTime, double)>? recent,
  }) => NavRow(
    title: title,
    subtitle: context.dates.monthDay(day),
    trailing: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(value, style: AppTextStyles.itemTitle),
        if (recent != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          UsualRangeSpark(
            points: recent,
            day: day,
            color: metricColor(metric),
            formatRange: (low, high) => withUnit(
              '${metric.format(low)}–${metric.format(high)}',
              metric.unitIn(context.l10n),
            ),
          ),
        ],
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
    List<(DateTime, double)> Function(ActivityMetric, DateTime) recent,
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
                recent: recent(metric, day),
              ),
          ],
        ),
      ),
    ];
  }

  /// Blood pressure as the pair it is taken as, which one line cannot
  /// stand for, so without its week.
  static List<Widget> _vitals(
    BuildContext context,
    Map<ActivityMetric, (DateTime, double)> latest,
    List<(DateTime, double)> Function(ActivityMetric, DateTime) recent,
  ) {
    if (latest.isEmpty) return const [];
    final l10n = context.l10n;
    NavRow row(
      ActivityMetric metric,
      String title,
      String value, {
      bool hasWeek = true,
    }) {
      final day = latest[metric]!.$1;
      return _readingRow(
        context,
        metric,
        title,
        value,
        day,
        recent: hasWeek ? recent(metric, day) : null,
      );
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
                hasWeek: false,
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
