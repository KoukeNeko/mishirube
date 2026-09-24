import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'journal_view_model.dart';

/// A tape measurement is plausible between these; outside them it is a
/// typo rather than a body.
const _minCm = 10.0;
const _maxCm = 250.0;

/// Logging tape measurements. Each site is saved as its own record, and
/// only the ones filled in are saved: a session where the waist was
/// measured says that, not that everything else is unchanged.
class MeasurementEntryScreen extends StatefulWidget {
  const MeasurementEntryScreen({super.key, this.editing});

  /// One reading to correct; only its site is shown.
  final BodyMeasurement? editing;

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

  void _save() {
    final entered = <MeasurementSite, double>{};
    for (final MapEntry(key: site, value: field) in _fields.entries) {
      final text = field.text.trim();
      if (text.isEmpty) continue;
      final value = double.tryParse(text);
      if (value == null || value < _minCm || value > _maxCm) {
        setState(
          () => _error =
              '${site.label}請輸入 ${_minCm.round()} – ${_maxCm.round()} cm 之間。',
        );
        return;
      }
      entered[site] = value;
    }
    if (entered.isEmpty) {
      setState(() => _error = '至少填一個部位。');
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
        '已更新${editing.site.label} ${formatWeight(value)} cm',
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
          ? '已記錄${entered.keys.first.label} ${formatWeight(entered.values.first)} cm'
          : '已記錄 ${entered.length} 個部位',
      kind: ToastKind.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DetailPage(
      appBar: PageAppBar(title: widget.editing?.site.label ?? '圍度'),
      footer: PrimaryButton(label: '儲存', onPressed: _save),
      children: [
        for (final site in _sites)
          Gutter(
            child: NumberFieldRow(
              fieldKey: ValueKey('measurement-${site.name}'),
              label: site.label,
              unit: 'cm',
              controller: _fields[site]!,
              caption: switch (_previous[site]) {
                final last? =>
                  '上次 ${formatWeight(last.centimetres)} cm · '
                      '${last.measuredAt.month}/${last.measuredAt.day}',
                null => null,
              },
            ),
          ),
        if (_error case final error?)
          Gutter(
            child: InfoBanner(tone: CardTone.warning, message: error),
          ),
      ],
    );
  }
}
