import 'package:flutter/material.dart';

import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../app/view_model.dart';
import '../../backend/engines/body_metrics.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../journal/body_reading_entry_screen.dart';
import '../journal/measurement_entry_screen.dart';
import '../journal/weight_entry_screen.dart';
import 'body_history_screen.dart';
import 'body_range.dart';
import 'body_view_model.dart';
import 'weight_trend_chart.dart';
import '../../l10n/l10n.dart';

/// What the body is: weight and its trend first, then what follows from
/// height, what a body composition scale reported and tape measurements.
/// Each figure opens its own history. What a health platform reads of
/// the heart and the vitals is on their own page.
///
/// A scale's composition figures are estimates, comparable only with the
/// same scale; they are marked so once, and no change in them is called
/// good or bad.
class BodyScreen extends StatefulWidget {
  const BodyScreen({super.key});

  @override
  State<BodyScreen> createState() => _BodyScreenState();
}

/// What the add button offers to log.
enum _Log {
  weight,
  girth,
  composition;

  String labelIn(AppLocalizations l10n) => switch (this) {
    weight => l10n.moduleWeight,
    girth => l10n.recordMeasurements,
    composition => l10n.recordBodyComposition,
  };
}

class _BodyScreenState extends State<BodyScreen> {
  BodyRange _range = BodyRange.month;

  Future<void> _log() async {
    final choice = await showAppDialog<_Log>(
      context,
      AppDialog(
        title: context.l10n.logAction,
        isChoiceList: true,
        actions: [
          for (final log in _Log.values)
            DialogAction(
              label: log.labelIn(context.l10n),
              onTap: () => Navigator.of(context).pop(log),
            ),
          DialogAction(
            label: context.l10n.commonCancel,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    pushModalPage<void>(context, switch (choice) {
      _Log.weight => const WeightEntryScreen(),
      _Log.girth => const MeasurementEntryScreen(),
      _Log.composition => const BodyReadingEntryScreen(),
    });
  }

  void _openMetric(BodyMetric metric) => pushModalPage<void>(
    context,
    BodyHistoryScreen(
      title: metric.labelIn(context.l10n),
      unit: metric.unitIn(context.l10n),
      tags: [if (metric.isEstimated) context.l10n.bodyScaleCompareSame],
      load: (model, window) => model.readings(metric, window),
      addPage: () => BodyReadingEntryScreen(only: metric),
      editPage: (record) =>
          BodyReadingEntryScreen(editing: record as BodyReading),
    ),
  );

  void _openWeights() => pushModalPage<void>(
    context,
    BodyHistoryScreen(
      title: context.l10n.moduleWeight,
      unit: 'kg',
      load: (model, window) => model.weights(window),
      addPage: () => const WeightEntryScreen(),
      editPage: (record) => WeightEntryScreen(editing: record as BodyWeight),
    ),
  );

  void _openSite(MeasurementSite site) => pushModalPage<void>(
    context,
    BodyHistoryScreen(
      title: site.labelIn(context.l10n),
      unit: 'cm',
      load: (model, window) => model.measurements(site, window),
      addPage: () => const MeasurementEntryScreen(),
      editPage: (record) =>
          MeasurementEntryScreen(editing: record as BodyMeasurement),
    ),
  );

  @override
  Widget build(BuildContext context) => ViewModelBuilder(
    create: BodyViewModel.new,
    builder: (context, model) => DetailPage(
      appBar: PageAppBar(
        title: context.l10n.recordCategoryBody,
        actions: [
          HeaderAction(
            icon: Icons.add,
            semanticLabel: context.l10n.logAction,
            onTap: _log,
          ),
        ],
      ),
      children: [
        ..._weight(model),
        ..._build(model),
        ..._composition(model),
        ..._girths(model),
      ],
    ),
  );

  List<Widget> _weight(BodyViewModel model) {
    final latest = model.latestWeight;
    final points = model.weightTrend(_range.window);
    return [
      Gutter(child: SectionLabel(context.l10n.moduleWeight)),
      if (latest == null)
        Gutter(
          child: EmptyStateCard(
            icon: Icons.monitor_weight_outlined,
            title: context.l10n.noWeightEntries,
            action: PrimaryButton(
              label: context.l10n.logItem(item: context.l10n.moduleWeight),
              onPressed: () =>
                  pushModalPage<void>(context, const WeightEntryScreen()),
            ),
          ),
        )
      else ...[
        Gutter(
          child: SegmentedChoice<BodyRange>(
            options: BodyRange.values,
            selected: _range,
            labelOf: (range) => range.labelIn(context.l10n),
            selectedColor: AppColors.body,
            onChanged: (range) => setState(() => _range = range),
          ),
        ),
        Gutter(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueWithUnit(
                  value: formatWeight(
                    points.isEmpty ? latest.weightKg : _round(points.last.$3),
                  ),
                  unit: 'kg',
                  style: AppTextStyles.hugeNumber.copyWith(
                    color: AppColors.body,
                  ),
                ),
                Text(
                  [
                    context.l10n.trendWeight,
                    context.l10n.latestOn(
                      date: context.dates.monthDay(latest.measuredAt),
                      value: '${formatWeight(latest.weightKg)} kg',
                    ),
                    if (trendChange(points) case final change?)
                      '${_range.labelIn(context.l10n)} ${_signed(change)} kg',
                  ].join(' · '),
                  style: AppTextStyles.caption,
                ),
                if (points.length > 1) ...[
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    label: context.l10n.weightChartLabel(count: points.length),
                    child: ChartScrubber(
                      count: points.length,
                      indexAt: ChartScrubber.points(points.length),
                      idle: context.l10n.weightChartIdle(count: points.length),
                      readoutOf: (index) {
                        final (at, weight, trend) = points[index];
                        return '${context.dates.monthDay(at)} · '
                            '${formatWeight(weight)} kg · '
                            '${context.l10n.trendValue(value: '${formatWeight(_round(trend))} kg')}';
                      },
                      builder: (context, selected) =>
                          WeightTrendChart(points: points, selected: selected),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Gutter(
          child: GroupedCard(
            children: [
              NavRow(title: context.l10n.allWeightEntries, onTap: _openWeights),
            ],
          ),
        ),
      ],
    ];
  }

  /// BMI, FFMI and waist-to-hip: what follows from height and the other
  /// figures, each only when what it needs was recorded.
  List<Widget> _build(BodyViewModel model) {
    final height = model.latestReadings[BodyMetric.height];
    final bmi = model.bmi;
    final ffmi = model.ffmi;
    final waistToHip = model.waistToHip;
    return [
      Gutter(child: SectionLabel(context.l10n.buildSection)),
      Gutter(
        child: GroupedCard(
          children: [
            NavRow(
              title: context.l10n.bodyMetricHeight,
              trailing: Text(
                height == null
                    ? context.l10n.notSet
                    : '${formatAmount(height.value)} cm',
                style: AppTextStyles.caption,
              ),
              onTap: () => height == null
                  ? pushModalPage<void>(
                      context,
                      const BodyReadingEntryScreen(only: BodyMetric.height),
                    )
                  : _openMetric(BodyMetric.height),
            ),
            if (bmi != null)
              KeyValueRow(
                label: 'BMI',
                value:
                    '${bmi.toStringAsFixed(1)} · ${bmiBandOf(bmi).labelIn(context.l10n)}',
              ),
            if (ffmi != null)
              KeyValueRow(label: 'FFMI', value: ffmi.toStringAsFixed(1)),
            if (waistToHip != null)
              KeyValueRow(
                label: context.l10n.waistToHipRatio,
                value: waistToHip.toStringAsFixed(2),
              ),
          ],
        ),
      ),
      if (bmi != null)
        Gutter(child: TagWrap(labels: [context.l10n.bmiStandardTaiwan])),
    ];
  }

  List<Widget> _composition(BodyViewModel model) {
    final latest = model.latestReadings;
    final metrics = [
      for (final metric in BodyMetric.values)
        if (metric != BodyMetric.height && latest[metric] != null) metric,
    ];
    final fatMass = model.fatMassKg;
    return [
      Gutter(child: SectionLabel(context.l10n.recordBodyComposition)),
      Gutter(
        child: GroupedCard(
          children: [
            for (final metric in metrics)
              NavRow(
                title: metric.labelIn(context.l10n),
                subtitle: context.dates.monthDay(latest[metric]!.measuredAt),
                trailing: Text(
                  withUnit(
                    formatAmount(latest[metric]!.value),
                    metric.unitIn(context.l10n),
                  ),
                  style: AppTextStyles.itemTitle,
                ),
                onTap: () => _openMetric(metric),
              ),
            if (fatMass != null)
              KeyValueRow(
                label: context.l10n.fatMass,
                value: '${formatWeight(_round(fatMass))} kg',
              ),
            NavRow(
              title: context.l10n.logItem(
                item: context.l10n.recordBodyComposition,
              ),
              leading: const Icon(Icons.add, color: AppColors.body),
              onTap: () =>
                  pushModalPage<void>(context, const BodyReadingEntryScreen()),
            ),
          ],
        ),
      ),
      if (metrics.isNotEmpty)
        Gutter(child: TagWrap(labels: [context.l10n.bodyScaleCompareSame])),
    ];
  }

  List<Widget> _girths(BodyViewModel model) {
    final latest = model.latestMeasurements;
    return [
      Gutter(child: SectionLabel(context.l10n.recordMeasurements)),
      Gutter(
        child: GroupedCard(
          children: [
            for (final site in MeasurementSite.values)
              if (latest[site] case final measurement?)
                NavRow(
                  title: site.labelIn(context.l10n),
                  subtitle: context.dates.monthDay(measurement.measuredAt),
                  trailing: Text(
                    '${formatAmount(measurement.centimetres)} cm',
                    style: AppTextStyles.itemTitle,
                  ),
                  onTap: () => _openSite(site),
                ),
            NavRow(
              title: context.l10n.logItem(
                item: context.l10n.recordMeasurements,
              ),
              leading: const Icon(Icons.add, color: AppColors.body),
              onTap: () =>
                  pushModalPage<void>(context, const MeasurementEntryScreen()),
            ),
          ],
        ),
      ),
      if (latest[MeasurementSite.waist] != null)
        Gutter(child: TagWrap(labels: [context.l10n.waistAdviceTaiwan])),
    ];
  }

  static double _round(double value) => (value * 10).round() / 10;

  static String _signed(double change) =>
      '${change < 0 ? '−' : '+'}${formatWeight(_round(change.abs()))}';
}
