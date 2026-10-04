import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'journal_view_model.dart';
import '../../l10n/l10n.dart';

/// Longest a bath is taken to last when the user gives a length.
const _longestBathMinutes = 600;

/// Logging one shower or bath: when it ended, and, if the user says, how
/// warm the water was, which kind it was and how long it took.
///
/// Only the end is ever filled in for the user. The rest starts empty,
/// stays empty unless chosen, and is not carried over from the last bath:
/// a value the user never gave would read as theirs.
class BathEntryScreen extends StatefulWidget {
  const BathEntryScreen({super.key, this.editing});

  /// A bath to correct instead of logging a new one.
  final BathEntry? editing;

  @override
  State<BathEntryScreen> createState() => _BathEntryScreenState();
}

class _BathEntryScreenState extends State<BathEntryScreen> {
  late final JournalViewModel _journal;
  late DateTime _end;
  late BathWater? _water = widget.editing?.water;
  late BathKind? _kind = widget.editing?.kind;
  late final _minutes = TextEditingController(
    text: switch (widget.editing?.duration) {
      final duration? => '${duration.inMinutes}',
      null => '',
    },
  );
  String? _error;

  @override
  void initState() {
    super.initState();
    final store = AppStoreScope.read(context);
    _journal = JournalViewModel(store.backend);
    _end = widget.editing?.bathedAt ?? store.now();
  }

  @override
  void dispose() {
    _minutes.dispose();
    _journal.dispose();
    super.dispose();
  }

  Future<void> _pickEnd() async {
    final picked = await pickDateTime(
      context,
      initial: _end,
      latest: AppStoreScope.read(context).now(),
    );
    if (picked == null || !mounted) return;
    setState(() => _end = picked);
  }

  void _save() {
    final text = _minutes.text.trim();
    final minutes = text.isEmpty ? null : int.tryParse(text);
    if (text.isNotEmpty &&
        (minutes == null || minutes < 1 || minutes > _longestBathMinutes)) {
      setState(
        () => _error = context.l10n.valueRangeError(
          field: context.l10n.durationLabel,
          min: '1',
          max: '$_longestBathMinutes',
          unit: context.l10n.unitMinutes,
        ),
      );
      return;
    }
    final duration = minutes == null ? null : Duration(minutes: minutes);
    final editing = widget.editing;
    if (editing == null) {
      _journal.recordBath(
        at: _end,
        water: _water,
        kind: _kind,
        duration: duration,
      );
    } else {
      _journal.updateBath(
        BathEntry(
          id: editing.id,
          bathedAt: _end,
          water: _water,
          kind: _kind,
          duration: duration,
        ),
      );
    }
    Navigator.of(context).pop();
    showToast(
      context,
      (editing == null ? context.l10n.loggedValue : context.l10n.updatedValue)(
        item: context.l10n.recordBath,
        value: formatTimeOfDay(_end),
      ),
      kind: ToastKind.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DetailPage(
      appBar: PageAppBar(title: l10n.recordBath),
      footer: PrimaryButton(label: l10n.commonSave, onPressed: _save),
      children: [
        Gutter(
          child: GroupedCard(
            children: [
              NavRow(
                title: l10n.commonEnd,
                subtitle:
                    '${context.dates.monthDay(_end)} ${formatTimeOfDay(_end)}',
                onTap: _pickEnd,
              ),
            ],
          ),
        ),
        Gutter(child: SectionLabel(l10n.bathWaterSection)),
        Gutter(
          child: ChipWrap<BathWater>(
            options: BathWater.values,
            labelOf: (water) => water.labelIn(l10n),
            isSelected: (water) => _water == water,
            selectedColor: AppColors.wellness,
            // Tapping the chosen one again clears it: no answer is valid.
            onTap: (water) =>
                setState(() => _water = _water == water ? null : water),
          ),
        ),
        Gutter(child: SectionLabel(l10n.bathKindSection)),
        Gutter(
          child: ChipWrap<BathKind>(
            options: BathKind.values,
            labelOf: (kind) => kind.labelIn(l10n),
            isSelected: (kind) => _kind == kind,
            selectedColor: AppColors.wellness,
            onTap: (kind) =>
                setState(() => _kind = _kind == kind ? null : kind),
          ),
        ),
        Gutter(
          child: NumberFieldRow(
            fieldKey: const ValueKey('bath-minutes'),
            label: l10n.durationLabel,
            unit: l10n.unitMinutes,
            controller: _minutes,
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
