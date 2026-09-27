import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import 'journal_view_model.dart';
import '../../l10n/l10n.dart';

/// Logging how the day felt: one of the kinds, a 1–5 rating and a note.
/// It is a log, not a score to improve: nothing here is graded.
class WellnessEntryScreen extends StatefulWidget {
  const WellnessEntryScreen({super.key, this.editing});

  /// A check-in to correct. Its kind stays what it was: changing an
  /// energy rating into a mood would be a different record.
  final WellnessEntry? editing;

  @override
  State<WellnessEntryScreen> createState() => _WellnessEntryScreenState();
}

class _WellnessEntryScreenState extends State<WellnessEntryScreen> {
  late final JournalViewModel _journal;

  @override
  void initState() {
    super.initState();
    _journal = JournalViewModel(AppStoreScope.read(context).backend);
  }

  late WellnessKind _kind = widget.editing?.kind ?? WellnessKind.energy;
  late int _score = widget.editing?.score ?? 3;
  late final _note = TextEditingController(text: widget.editing?.note ?? '');

  @override
  void dispose() {
    _journal.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final editing = widget.editing;
    if (editing == null) {
      _journal.recordWellness(_kind, _score, note: _note.text.trim());
    } else {
      _journal.updateWellness(
        WellnessEntry(
          id: editing.id,
          recordedAt: editing.recordedAt,
          kind: editing.kind,
          score: _score,
          note: _note.text.trim(),
        ),
      );
    }
    Navigator.of(context).pop();
    showToast(
      context,
      (editing == null ? context.l10n.loggedValue : context.l10n.updatedValue)(
        item: _kind.labelIn(context.l10n),
        value: '$_score / 5',
      ),
      kind: ToastKind.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DetailPage(
      appBar: widget.editing == null
          ? PageAppBar(title: context.l10n.moduleWellness)
          : PageAppBar(title: _kind.labelIn(context.l10n)),
      footer: PrimaryButton(label: context.l10n.commonSave, onPressed: _save),
      children: [
        if (widget.editing == null)
          Gutter(
            child: SegmentedChoice(
              options: const [
                WellnessKind.energy,
                WellnessKind.mood,
                WellnessKind.symptom,
              ],
              selected: _kind,
              labelOf: (kind) => kind.labelIn(context.l10n),
              selectedColor: AppColors.wellness,
              onChanged: (kind) => setState(() => _kind = kind),
            ),
          ),
        Gutter(
          child: SectionLabel(
            _kind == WellnessKind.symptom
                ? context.l10n.symptomSeverity
                : context.l10n.wellnessKindHow(
                    kind: _kind.labelIn(context.l10n),
                  ),
          ),
        ),
        Gutter(
          child: ChipWrap(
            options: const [1, 2, 3, 4, 5],
            labelOf: (score) => '$score',
            isSelected: (score) => _score == score,
            selectedColor: AppColors.wellness,
            onTap: (score) => setState(() => _score = score),
          ),
        ),
        Gutter(
          child: SectionLabel(
            context.l10n.optionalField(field: context.l10n.notesSection),
          ),
        ),
        Gutter(
          child: AppTextField(
            controller: _note,
            hint: context.l10n.wellnessNoteHint,
          ),
        ),
      ],
    );
  }
}
