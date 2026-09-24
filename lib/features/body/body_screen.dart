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

/// What the body is: weight and its trend first, then what follows from
/// height, what a body composition scale reported and tape measurements.
/// Each figure opens its own history.
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
  weight('體重'),
  girth('圍度'),
  composition('身體組成');

  const _Log(this.label);

  final String label;
}

class _BodyScreenState extends State<BodyScreen> {
  BodyRange _range = BodyRange.month;

  Future<void> _log() async {
    final choice = await showAppDialog<_Log>(
      context,
      AppDialog(
        title: '記錄',
        isChoiceList: true,
        actions: [
          for (final log in _Log.values)
            DialogAction(
              label: log.label,
              onTap: () => Navigator.of(context).pop(log),
            ),
          DialogAction(label: '取消', onTap: () => Navigator.of(context).pop()),
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
      title: metric.label,
      unit: metric.unit,
      tags: [if (metric.isEstimated) '體脂計估計，請用同一台比較'],
      load: (model, window) => model.readings(metric, window),
      addPage: () => BodyReadingEntryScreen(only: metric),
    ),
  );

  void _openSite(MeasurementSite site) => pushModalPage<void>(
    context,
    BodyHistoryScreen(
      title: site.label,
      unit: 'cm',
      load: (model, window) => model.measurements(site, window),
      addPage: () => const MeasurementEntryScreen(),
    ),
  );

  @override
  Widget build(BuildContext context) => ViewModelBuilder(
    create: BodyViewModel.new,
    builder: (context, model) => DetailPage(
      appBar: PageAppBar(
        title: '身體',
        actions: [
          HeaderAction(icon: Icons.add, semanticLabel: '記錄', onTap: _log),
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
      Gutter(child: const SectionLabel('體重')),
      if (latest == null)
        Gutter(
          child: EmptyStateCard(
            icon: Icons.monitor_weight_outlined,
            title: '沒有體重紀錄',
            action: PrimaryButton(
              label: '記錄體重',
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
            labelOf: (range) => range.label,
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
                    '趨勢體重',
                    '最近 ${bodyDate(latest.measuredAt)} '
                        '${formatWeight(latest.weightKg)} kg',
                    if (trendChange(points) case final change?)
                      '${_range.label} ${_signed(change)} kg',
                  ].join(' · '),
                  style: AppTextStyles.caption,
                ),
                if (points.length > 1) ...[
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    label: '體重走勢，${points.length} 次',
                    child: ChartScrubber(
                      count: points.length,
                      indexAt: ChartScrubber.points(points.length),
                      idle: '線為 7 日平均 · ${points.length} 次秤重',
                      readoutOf: (index) {
                        final (at, weight, trend) = points[index];
                        return '${bodyDate(at)} · ${formatWeight(weight)} kg'
                            ' · 趨勢 ${formatWeight(_round(trend))} kg';
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
      Gutter(child: const SectionLabel('體位')),
      Gutter(
        child: GroupedCard(
          children: [
            NavRow(
              title: '身高',
              trailing: Text(
                height == null ? '未設定' : '${formatAmount(height.value)} cm',
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
                value: '${bmi.toStringAsFixed(1)} · ${bmiBandOf(bmi).label}',
              ),
            if (ffmi != null)
              KeyValueRow(label: 'FFMI', value: ffmi.toStringAsFixed(1)),
            if (waistToHip != null)
              KeyValueRow(label: '腰臀比', value: waistToHip.toStringAsFixed(2)),
          ],
        ),
      ),
      if (bmi != null) Gutter(child: const TagWrap(labels: ['國健署成人標準'])),
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
      Gutter(child: const SectionLabel('身體組成')),
      Gutter(
        child: GroupedCard(
          children: [
            for (final metric in metrics)
              NavRow(
                title: metric.label,
                subtitle: bodyDate(latest[metric]!.measuredAt),
                trailing: Text(
                  '${formatAmount(latest[metric]!.value)} ${metric.unit}',
                  style: AppTextStyles.itemTitle,
                ),
                onTap: () => _openMetric(metric),
              ),
            if (fatMass != null)
              KeyValueRow(
                label: '脂肪量',
                value: '${formatWeight(_round(fatMass))} kg',
              ),
            NavRow(
              title: '記錄身體組成',
              leading: const Icon(Icons.add, color: AppColors.body),
              onTap: () =>
                  pushModalPage<void>(context, const BodyReadingEntryScreen()),
            ),
          ],
        ),
      ),
      if (metrics.isNotEmpty)
        Gutter(child: const TagWrap(labels: ['體脂計估計，請用同一台比較'])),
    ];
  }

  List<Widget> _girths(BodyViewModel model) {
    final latest = model.latestMeasurements;
    return [
      Gutter(child: const SectionLabel('圍度')),
      Gutter(
        child: GroupedCard(
          children: [
            for (final site in MeasurementSite.values)
              if (latest[site] case final measurement?)
                NavRow(
                  title: site.label,
                  subtitle: bodyDate(measurement.measuredAt),
                  trailing: Text(
                    '${formatAmount(measurement.centimetres)} cm',
                    style: AppTextStyles.itemTitle,
                  ),
                  onTap: () => _openSite(site),
                ),
            NavRow(
              title: '記錄圍度',
              leading: const Icon(Icons.add, color: AppColors.body),
              onTap: () =>
                  pushModalPage<void>(context, const MeasurementEntryScreen()),
            ),
          ],
        ),
      ),
      if (latest[MeasurementSite.waist] != null)
        Gutter(child: const TagWrap(labels: ['國健署建議腰圍：男 < 90 cm、女 < 80 cm'])),
    ];
  }

  static double _round(double value) => (value * 10).round() / 10;

  static String _signed(double change) =>
      '${change < 0 ? '−' : '+'}${formatWeight(_round(change.abs()))}';
}
