import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../backend/engines/figure_reader.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../nutrition/camera_screen.dart';
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
  const BodyReadingEntryScreen({
    super.key,
    this.editing,
    this.only,
    this.takePhoto,
  });

  /// One reading to correct; only its figure is shown.
  final BodyReading? editing;

  /// A single figure to log, such as height; every figure when null.
  final BodyMetric? only;

  /// Takes the photo to read; the app's camera unless a test hands one in.
  final Future<String?> Function(String title)? takePhoto;

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

  /// How many figures the last photo filled in, for the note to check
  /// them.
  int? _read;

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

  /// A photo of the scale's screen or a body composition sheet, read on
  /// the device into the fields. Nothing is saved until the user does.
  Future<void> _scan() async {
    final store = AppStoreScope.read(context);
    final path =
        await (widget.takePhoto ?? (title) => takePhoto(context, title))(
          '身體組成',
        );
    if (path == null || !mounted) return;
    final String text;
    try {
      text = await store.readPhotoText(path);
    } on AiException {
      if (mounted) setState(() => _error = '這台裝置無法讀取照片中的文字。');
      return;
    }
    if (!mounted) return;
    final found = {
      for (final MapEntry(key: metric, value: value) in readBodyFigures(
        text,
      ).entries)
        if (_fields.containsKey(metric)) metric: value,
    };
    setState(() {
      if (found.isEmpty) {
        _read = null;
        _error = '照片中沒有讀到身體組成的數字。';
        return;
      }
      for (final MapEntry(key: metric, value: value) in found.entries) {
        _fields[metric]!.text = formatAmount(value);
      }
      _read = found.length;
      _error = null;
    });
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
        actions: [
          if (widget.editing == null)
            HeaderAction(
              icon: Icons.photo_camera_outlined,
              label: '掃描',
              semanticLabel: '拍照讀取身體組成',
              onTap: _scan,
            ),
        ],
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
        if (_read case final count?)
          Gutter(child: TagWrap(labels: ['照片讀到 $count 項，請核對']))
        else if (metrics.any((metric) => metric.isEstimated))
          Gutter(child: const TagWrap(labels: ['照體脂計顯示填寫'])),
        if (_error case final error?)
          Gutter(
            child: InfoBanner(tone: CardTone.warning, message: error),
          ),
      ],
    );
  }
}
