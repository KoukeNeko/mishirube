import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../backend/engines/figure_reader.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../nutrition/camera_screen.dart';
import 'journal_view_model.dart';
import '../../l10n/l10n.dart';

/// A tape measurement is plausible between these; outside them it is a
/// typo rather than a body.
const _minCm = 10.0;
const _maxCm = 250.0;

/// Logging tape measurements. Each site is saved as its own record, and
/// only the ones filled in are saved: a session where the waist was
/// measured says that, not that everything else is unchanged.
class MeasurementEntryScreen extends StatefulWidget {
  const MeasurementEntryScreen({super.key, this.editing, this.takePhoto});

  /// One reading to correct; only its site is shown.
  final BodyMeasurement? editing;

  /// Takes the photo to read; the app's camera unless a test hands one in.
  final Future<String?> Function(String title)? takePhoto;

  @override
  State<MeasurementEntryScreen> createState() => _MeasurementEntryScreenState();
}

class _MeasurementEntryScreenState extends State<MeasurementEntryScreen> {
  late final JournalViewModel _journal;
  late final _fields = {
    for (final site in _sites)
      site: TextEditingController(
        text: widget.editing == null
            ? ''
            : formatWeight(widget.editing!.centimetres),
      ),
  };

  List<MeasurementSite> get _sites => switch (widget.editing) {
    final editing? => [editing.site],
    null => MeasurementSite.values,
  };
  late final Map<MeasurementSite, BodyMeasurement> _previous;
  String? _error;

  /// How many sites the last photo filled in, for the note to check them.
  int? _read;

  @override
  void initState() {
    super.initState();
    _journal = JournalViewModel(AppStoreScope.read(context).backend);
    _previous = _journal.latestMeasurements;
  }

  @override
  void dispose() {
    _journal.dispose();
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// A photo of measurements written down or shown in another app, read
  /// on the device into the fields. Nothing is saved until the user does.
  Future<void> _scan() async {
    final store = AppStoreScope.read(context);
    final path =
        await (widget.takePhoto ?? (title) => takePhoto(context, title))(
          context.l10n.recordMeasurements,
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
    final found = readGirths(text);
    setState(() {
      if (found.isEmpty) {
        _read = null;
        _error = context.l10n.photoNoGirths;
        return;
      }
      for (final MapEntry(key: site, value: value) in found.entries) {
        _fields[site]!.text = formatWeight(value);
      }
      _read = found.length;
      _error = null;
    });
  }

  void _save() {
    final entered = <MeasurementSite, double>{};
    for (final MapEntry(key: site, value: field) in _fields.entries) {
      final text = field.text.trim();
      if (text.isEmpty) continue;
      final value = double.tryParse(text);
      if (value == null || value < _minCm || value > _maxCm) {
        setState(
          () => _error = context.l10n.valueRangeError(
            field: site.labelIn(context.l10n),
            min: '${_minCm.round()}',
            max: '${_maxCm.round()}',
            unit: 'cm',
          ),
        );
        return;
      }
      entered[site] = value;
    }
    if (entered.isEmpty) {
      setState(() => _error = context.l10n.fillAtLeastOneSite);
      return;
    }
    final editing = widget.editing;
    if (editing != null) {
      final value = entered[editing.site]!;
      _journal.updateMeasurement(
        BodyMeasurement(
          id: editing.id,
          measuredAt: editing.measuredAt,
          site: editing.site,
          centimetres: value,
          note: editing.note,
        ),
      );
      Navigator.of(context).pop();
      showToast(
        context,
        context.l10n.updatedValue(
          item: editing.site.labelIn(context.l10n),
          value: '${formatWeight(value)} cm',
        ),
        kind: ToastKind.success,
      );
      return;
    }
    for (final MapEntry(key: site, value: value) in entered.entries) {
      _journal.recordMeasurement(site, value);
    }
    Navigator.of(context).pop();
    showToast(
      context,
      entered.length == 1
          ? context.l10n.loggedValue(
              item: entered.keys.first.labelIn(context.l10n),
              value: '${formatWeight(entered.values.first)} cm',
            )
          : context.l10n.loggedSitesCount(count: entered.length),
      kind: ToastKind.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DetailPage(
      appBar: PageAppBar(
        title:
            widget.editing?.site.labelIn(context.l10n) ??
            context.l10n.recordMeasurements,
        actions: [
          if (widget.editing == null)
            HeaderAction(
              icon: Icons.photo_camera_outlined,
              label: context.l10n.scanAction,
              semanticLabel: context.l10n.scanGirths,
              onTap: _scan,
            ),
        ],
      ),
      footer: PrimaryButton(label: context.l10n.commonSave, onPressed: _save),
      children: [
        for (final site in _sites)
          Gutter(
            child: NumberFieldRow(
              fieldKey: ValueKey('measurement-${site.name}'),
              label: site.labelIn(context.l10n),
              unit: 'cm',
              controller: _fields[site]!,
              caption: switch (_previous[site]) {
                final last? => context.l10n.lastReadingOn(
                  value: '${formatWeight(last.centimetres)} cm',
                  date: context.dates.compactMonthDay(last.measuredAt),
                ),
                null => null,
              },
            ),
          ),
        if (_read case final count?)
          Gutter(
            child: TagWrap(labels: [context.l10n.photoReadCheck(count: count)]),
          ),
        if (_error case final error?)
          Gutter(
            child: InfoBanner(tone: CardTone.warning, message: error),
          ),
      ],
    );
  }
}
