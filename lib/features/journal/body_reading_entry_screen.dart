import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'journal_view_model.dart';

/// Each figure is plausible between these; outside them it is a typo
/// rather than a body.
const _ranges = {
  BodyMetric.height: (100.0, 230.0),
  BodyMetric.bodyFat: (2.0, 70.0),
  BodyMetric.skeletalMuscle: (5.0, 80.0),
  BodyMetric.muscleMass: (10.0, 120.0),
  BodyMetric.leanMass: (20.0, 150.0),
  BodyMetric.visceralFat: (1.0, 30.0),
  BodyMetric.bodyWater: (20.0, 80.0),
  BodyMetric.boneMass: (0.5, 10.0),
  BodyMetric.basalMetabolicRate: (500.0, 4000.0),
};

/// Logging height or what a body composition scale showed. Only the
/// figures filled in are saved, all at the same moment, as a scale gives
/// them.
class BodyReadingEntryScreen extends StatefulWidget {
  const BodyReadingEntryScreen({super.key, this.editing, this.only});

  /// One reading to correct; only its figure is shown.
  final BodyReading? editing;

  /// A single figure to log, such as height; every figure when null.
  final BodyMetric? only;

  @override
  State<BodyReadingEntryScreen> createState() => _BodyReadingEntryScreenState();
}

class _BodyReadingEntryScreenState extends State<BodyReadingEntryScreen> {
  late final JournalViewModel _journal;
  late final Map<BodyMetric, BodyReading> _previous;
  late final _fields = {
    for (final metric in _metrics)
      metric: TextEditingController(
        text: widget.editing == null ? '' : formatAmount(widget.editing!.value),
      ),
  };
  String? _error;

  List<BodyMetric> get _metrics => switch ((widget.editing, widget.only)) {
    (final editing?, _) => [editing.metric],
    (_, final only?) => [only],
    _ => BodyMetric.values,
  };

  @override
  void initState() {
    super.initState();
    _journal = JournalViewModel(AppStoreScope.read(context).backend);
    _previous = _journal.latestBodyReadings;
  }

  @override
  void dispose() {
    _journal.dispose();
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    final entered = <BodyMetric, double>{};
    for (final MapEntry(key: metric, value: field) in _fields.entries) {
      final text = field.text.trim();
      if (text.isEmpty) continue;
      final value = double.tryParse(text);
      final (low, high) = _ranges[metric]!;
      if (value == null || value < low || value > high) {
        setState(
          () => _error =
              '${metric.label}請輸入 ${formatAmount(low)} – '
              '${formatAmount(high)} ${metric.unit} 之間。',
        );
        return;
      }
      entered[metric] = value;
    }
    if (entered.isEmpty) {
      setState(() => _error = '至少填一項。');
      return;
    }
    final editing = widget.editing;
    if (editing != null) {
      final value = entered[editing.metric]!;
      _journal.updateBodyReading(
        BodyReading(
          id: editing.id,
          measuredAt: editing.measuredAt,
          metric: editing.metric,
          value: value,
          note: editing.note,
        ),
      );
    } else {
      _journal.recordBodyReadings(entered);
    }
    Navigator.of(context).pop();
    final (metric, value) = (entered.keys.first, entered.values.first);
    showToast(
      context,
      entered.length == 1
          ? '${editing == null ? '已記錄' : '已更新'}${metric.label} '
                '${formatAmount(value)} ${metric.unit}'
          : '已記錄 ${entered.length} 項',
      kind: ToastKind.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _metrics;
    return DetailPage(
      appBar: PageAppBar(
        title: metrics.length == 1 ? metrics.single.label : '身體組成',
      ),
      footer: PrimaryButton(label: '儲存', onPressed: _save),
      children: [
        for (final metric in metrics)
          Gutter(
            child: NumberFieldRow(
              fieldKey: ValueKey('body-${metric.name}'),
              label: metric.label,
              unit: metric.unit,
              controller: _fields[metric]!,
              caption: switch (_previous[metric]) {
                final last? =>
                  '上次 ${formatAmount(last.value)} ${metric.unit} · '
                      '${last.measuredAt.month}/${last.measuredAt.day}',
                null => null,
              },
            ),
          ),
        if (metrics.any((metric) => metric.isEstimated))
          Gutter(child: const TagWrap(labels: ['照體脂計顯示填寫'])),
        if (_error case final error?)
          Gutter(
            child: InfoBanner(tone: CardTone.warning, message: error),
          ),
      ],
    );
  }
}
