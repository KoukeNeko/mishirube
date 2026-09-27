import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import 'journal_view_model.dart';
import '../../l10n/l10n.dart';

/// Writing down something about today, in the user's own words.
///
/// It sits in the log beside the records, as the context they cannot
/// carry themselves: a dinner out, a bad night, a sore shoulder. Given
/// [editing], it rewrites that note and leaves it on its day.
class NoteEntryScreen extends StatefulWidget {
  const NoteEntryScreen({super.key, this.editing});

  final Note? editing;

  @override
  State<NoteEntryScreen> createState() => _NoteEntryScreenState();
}

class _NoteEntryScreenState extends State<NoteEntryScreen> {
  late final JournalViewModel _journal;

  @override
  void initState() {
    super.initState();
    _journal = JournalViewModel(AppStoreScope.read(context).backend);
  }

  late final _text = TextEditingController(text: widget.editing?.text ?? '')
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _journal.dispose();
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final text = _text.text.trim();
    final editing = widget.editing;
    if (editing == null) {
      _journal.recordNote(text);
    } else {
      _journal.updateNote(
        Note(id: editing.id, notedAt: editing.notedAt, text: text),
      );
    }
    Navigator.of(context).pop();
    showToast(
      context,
      editing == null ? context.l10n.noteLogged : context.l10n.noteUpdated,
      kind: ToastKind.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DetailPage(
      appBar: PageAppBar(title: context.l10n.moduleNotes),
      footer: PrimaryButton(
        label: context.l10n.commonSave,
        onPressed: _text.text.trim().isEmpty ? null : _save,
      ),
      children: [
        Gutter(
          child: AppTextField(
            controller: _text,
            hint: context.l10n.noteHint,
            autofocus: widget.editing == null,
            maxLines: 6,
          ),
        ),
      ],
    );
  }
}
