import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
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
        Gutter(
          child: GroupedCard(
            children: [
              for (final metric in metrics)
                _MetricRow(
                  metric: metric,
                  controller: _fields[metric]!,
                  previous: _previous[metric],
                ),
            ],
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

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.metric,
    required this.controller,
    required this.previous,
  });

  final BodyMetric metric;
  final TextEditingController controller;
  final BodyReading? previous;

  @override
  Widget build(BuildContext context) {
    final last = previous;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(metric.label, style: AppTextStyles.body),
                if (last != null)
                  Text(
                    '上次 ${formatAmount(last.value)} ${metric.unit} · '
                    '${last.measuredAt.month}/${last.measuredAt.day}',
                    style: AppTextStyles.caption,
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 72,
            child: TextField(
              onTapOutside: dismissKeyboardOnTapOutside,
              key: ValueKey('body-${metric.name}'),
              controller: controller,
              textAlign: TextAlign.end,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: AppTextStyles.itemTitle,
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: last == null ? '—' : formatAmount(last.value),
                hintStyle: const TextStyle(color: AppColors.textTertiary),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          SizedBox(
            width: 32,
            child: Text(metric.unit, style: AppTextStyles.caption),
          ),
        ],
      ),
    );
  }
}
