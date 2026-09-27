import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../backend/engines/figure_reader.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../nutrition/camera_screen.dart';
import 'journal_view_model.dart';
import '../../l10n/l10n.dart';

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
          context.l10n.recordBodyComposition,
        );
    if (path == null || !mounted) return;
    final String text;
    try {
      text = await store.readPhotoText(path);
    } on AiException {
      if (mounted) setState(() => _error = context.l10n.photoTextUnavailable);
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
        _error = context.l10n.photoNoBodyComposition;
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
          () => _error = context.l10n.valueRangeError(
            field: metric.labelIn(context.l10n),
            min: formatAmount(low),
            max: formatAmount(high),
            unit: metric.unitIn(context.l10n),
          ),
        );
        return;
      }
      entered[metric] = value;
    }
    if (entered.isEmpty) {
      setState(() => _error = context.l10n.fillAtLeastOne);
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
          ? (editing == null
                ? context.l10n.loggedValue
                : context.l10n.updatedValue)(
              item: metric.labelIn(context.l10n),
              value: '${formatAmount(value)} ${metric.unitIn(context.l10n)}',
            )
          : context.l10n.loggedItemsCount(count: entered.length),
      kind: ToastKind.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _metrics;
    return DetailPage(
      appBar: PageAppBar(
        title: metrics.length == 1
            ? metrics.single.labelIn(context.l10n)
            : context.l10n.recordBodyComposition,
        actions: [
          if (widget.editing == null)
            HeaderAction(
              icon: Icons.photo_camera_outlined,
              label: context.l10n.scanAction,
              semanticLabel: context.l10n.scanBodyComposition,
              onTap: _scan,
            ),
        ],
      ),
      footer: PrimaryButton(label: context.l10n.commonSave, onPressed: _save),
      children: [
        for (final metric in metrics)
          Gutter(
            child: NumberFieldRow(
              fieldKey: ValueKey('body-${metric.name}'),
              label: metric.labelIn(context.l10n),
              unit: metric.unitIn(context.l10n),
              controller: _fields[metric]!,
              caption: switch (_previous[metric]) {
                final last? => context.l10n.lastReadingOn(
                  value:
                      '${formatAmount(last.value)} ${metric.unitIn(context.l10n)}',
                  date: context.dates.compactMonthDay(last.measuredAt),
                ),
                null => null,
              },
            ),
          ),
        if (_read case final count?)
          Gutter(
            child: TagWrap(labels: [context.l10n.photoReadCheck(count: count)]),
          )
        else if (metrics.any((metric) => metric.isEstimated))
          Gutter(child: TagWrap(labels: [context.l10n.fillFromScale])),
        if (_error case final error?)
          Gutter(
            child: InfoBanner(tone: CardTone.warning, message: error),
          ),
      ],
    );
  }
}
