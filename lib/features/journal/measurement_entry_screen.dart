import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';

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
    _previous = AppStoreScope.read(context).latestMeasurements;
  }

  @override
  void dispose() {
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
    final store = AppStoreScope.read(context);
    final editing = widget.editing;
    if (editing != null) {
      final value = entered[editing.site]!;
      store.updateMeasurement(
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
      store.recordMeasurement(site, value);
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
      appBar: PageAppBar(
        title: widget.editing?.site.label ?? '圍度',
      ),
      footer: PrimaryButton(label: '儲存', onPressed: _save),
      children: [
        Gutter(
          child: GroupedCard(
            children: [
              for (final site in _sites)
                _SiteRow(
                  site: site,
                  controller: _fields[site]!,
                  previous: _previous[site],
                ),
            ],
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

class _SiteRow extends StatelessWidget {
  const _SiteRow({
    required this.site,
    required this.controller,
    required this.previous,
  });

  final MeasurementSite site;
  final TextEditingController controller;
  final BodyMeasurement? previous;

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
                Text(site.label, style: AppTextStyles.body),
                if (last != null)
                  Text(
                    '上次 ${formatWeight(last.centimetres)} cm · '
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
              key: ValueKey('measurement-${site.name}'),
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
                hintText: last == null ? '—' : formatWeight(last.centimetres),
                hintStyle: const TextStyle(color: AppColors.textTertiary),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Text('cm', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
