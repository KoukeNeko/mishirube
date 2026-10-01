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

/// A weighing, as a body composition scale gives it with the rest.
const _weightRange = (20.0, 400.0);

/// Logging height or what a body composition scale showed. Only the
/// figures filled in are saved; a measurement's weight and figures are
/// saved as one, at the same moment, as the scale gave them.
class BodyReadingEntryScreen extends StatefulWidget {
  const BodyReadingEntryScreen({
    super.key,
    this.editing,
    this.session,
    this.only,
    this.takePhoto,
  });

  /// One reading to correct; only its figure is shown.
  final BodyReading? editing;

  /// A whole measurement to correct: its weight and every figure.
  final BodySession? session;

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
        text: switch ((widget.editing, _sessionValue(metric))) {
          (final editing?, _) => formatAmount(editing.value),
          (_, final value?) => formatAmount(value),
          _ => '',
        },
      ),
  };

  /// The weight a measurement is logged with; null when only a figure or
  /// a single reading is being entered.
  late final TextEditingController? _weight = _isMeasurement
      ? TextEditingController(
          text: switch (widget.session?.weight) {
            final weight? => formatWeight(weight.weightKg),
            null => '',
          },
        )
      : null;

  bool get _isMeasurement => widget.editing == null && widget.only == null;

  double? _sessionValue(BodyMetric metric) => widget.session?.readings
      .where((reading) => reading.metric == metric)
      .firstOrNull
      ?.value;

  late final BodyWeight? _lastWeight = _journal.latestWeight;
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
    _weight?.dispose();
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
    double? weightKg;
    if (_weight?.text.trim() case final text? when text.isNotEmpty) {
      final value = double.tryParse(text);
      final (low, high) = _weightRange;
      if (value == null || value < low || value > high) {
        setState(
          () => _error = context.l10n.valueRangeError(
            field: context.l10n.moduleWeight,
            min: formatAmount(low),
            max: formatAmount(high),
            unit: 'kg',
          ),
        );
        return;
      }
      weightKg = value;
    }
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
    if (entered.isEmpty && weightKg == null) {
      setState(() => _error = context.l10n.fillAtLeastOne);
      return;
    }
    final editing = widget.editing;
    if (_isMeasurement) {
      final count = entered.length + (weightKg == null ? 0 : 1);
      if (widget.session case final session?) {
        _journal.updateBodySession(
          session,
          weightKg: weightKg,
          readings: entered,
        );
      } else {
        _journal.recordBodySession(weightKg: weightKg, readings: entered);
      }
      Navigator.of(context).pop();
      showToast(
        context,
        widget.session == null
            ? context.l10n.loggedItemsCount(count: count)
            : context.l10n.updatedNamed(
                name: context.l10n.recordBodyComposition,
              ),
        kind: ToastKind.success,
      );
      return;
    }
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
              value: withUnit(formatAmount(value), metric.unitIn(context.l10n)),
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
        if (_weight case final weight?)
          Gutter(
            child: NumberFieldRow(
              fieldKey: const ValueKey('body-weight'),
              label: context.l10n.moduleWeight,
              unit: 'kg',
              controller: weight,
              caption: switch (_lastWeight) {
                final last? when widget.session == null =>
                  context.l10n.lastReadingOn(
                    value: '${formatWeight(last.weightKg)} kg',
                    date: context.dates.compactMonthDay(last.measuredAt),
                  ),
                _ => null,
              },
            ),
          ),
        for (final metric in metrics)
          Gutter(
            child: NumberFieldRow(
              fieldKey: ValueKey('body-${metric.name}'),
              label: metric.labelIn(context.l10n),
              unit: metric.unitIn(context.l10n),
              controller: _fields[metric]!,
              caption: switch (_previous[metric]) {
                final last? when widget.session == null =>
                  context.l10n.lastReadingOn(
                    value: withUnit(
                      formatAmount(last.value),
                      metric.unitIn(context.l10n),
                    ),
                    date: context.dates.compactMonthDay(last.measuredAt),
                  ),
                _ => null,
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
