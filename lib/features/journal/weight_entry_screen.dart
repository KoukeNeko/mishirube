import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'journal_view_model.dart';
import '../../l10n/l10n.dart';

/// Plausible bounds for a body weight in kilograms; outside them it is a
/// typo rather than a measurement.
const _minKg = 20.0;
const _maxKg = 400.0;

/// Logging a body weight, prefilled with the last one so the usual case
/// is a small correction rather than typing from scratch. Given
/// [editing], it corrects that reading instead; its time stays put.
class WeightEntryScreen extends StatefulWidget {
  const WeightEntryScreen({super.key, this.editing});

  final BodyWeight? editing;

  @override
  State<WeightEntryScreen> createState() => _WeightEntryScreenState();
}

class _WeightEntryScreenState extends State<WeightEntryScreen> {
  late final JournalViewModel _journal;
  late final TextEditingController _weight;
  late final BodyWeight? _previous;
  String? _error;

  @override
  void initState() {
    super.initState();
    _journal = JournalViewModel(AppStoreScope.read(context).backend);
    final editing = widget.editing;
    final previous = _journal.recentWeights.lastOrNull;
    _weight = TextEditingController(
      text: switch (editing ?? previous) {
        final weight? => formatWeight(weight.weightKg),
        null => '',
      },
    );
    // The weight shown is a starting point: typing a new one replaces it
    // instead of joining it ("72.4" and "73" make "72.473").
    _weight.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _weight.text.length,
    );
    _previous = editing == null ? previous : null;
  }

  @override
  void dispose() {
    _journal.dispose();
    _weight.dispose();
    super.dispose();
  }

  void _save() {
    final kilograms = double.tryParse(_weight.text.trim());
    if (kilograms == null || kilograms < _minKg || kilograms > _maxKg) {
      setState(
        () => _error = context.l10n.weightRangeError(
          min: '$_minKg',
          max: '$_maxKg',
        ),
      );
      return;
    }
    final editing = widget.editing;
    if (editing == null) {
      _journal.recordWeight(kilograms, note: _note);
    } else {
      _journal.updateWeight(
        BodyWeight(
          id: editing.id,
          measuredAt: editing.measuredAt,
          weightKg: kilograms,
          note: editing.note,
        ),
      );
    }
    Navigator.of(context).pop();
    showToast(
      context,
      (editing == null
          ? context.l10n.weightLogged
          : context.l10n.weightUpdated)(weight: formatWeight(kilograms)),
      kind: ToastKind.success,
    );
  }

  /// What the reading is, so a later trend can tell morning weights from
  /// weights taken at any hour.
  // l10n-ignore: a stored marker, read back by the weight trend.
  String get _note => '手動輸入';

  @override
  Widget build(BuildContext context) {
    return DetailPage(
      appBar: PageAppBar(title: context.l10n.moduleWeight),
      footer: PrimaryButton(label: context.l10n.commonSave, onPressed: _save),
      children: [
        Gutter(
          child: AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    onTapOutside: dismissKeyboardOnTapOutside,
                    controller: _weight,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    onSubmitted: (_) => _save(),
                    style: AppTextStyles.hugeNumber,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      hintText: '0.0',
                      hintStyle: TextStyle(color: AppColors.textTertiary),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text('kg', style: AppTextStyles.itemTitle),
                ),
              ],
            ),
          ),
        ),
        if (_error case final error?)
          Gutter(
            child: InfoBanner(tone: CardTone.warning, message: error),
          ),
        if (_previous case final previous?)
          Gutter(
            child: Text(
              context.l10n.lastReadingOn(
                value: '${formatWeight(previous.weightKg)} kg',
                date: context.dates.compactMonthDay(previous.measuredAt),
              ),
              style: AppTextStyles.caption,
            ),
          ),
      ],
    );
  }
}
