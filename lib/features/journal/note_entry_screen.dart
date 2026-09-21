import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';

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
  late final _text = TextEditingController(text: widget.editing?.text ?? '')
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final text = _text.text.trim();
    final store = AppStoreScope.read(context);
    final editing = widget.editing;
    if (editing == null) {
      store.recordNote(text);
    } else {
      store.updateNote(
        Note(id: editing.id, notedAt: editing.notedAt, text: text),
      );
    }
    Navigator.of(context).pop();
    showToast(
      context,
      editing == null ? '已記下筆記' : '已更新筆記',
      kind: ToastKind.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DetailPage(
      appBar: PageAppBar(
        title: '筆記',
        subtitle: widget.editing == null ? '關於今天' : '修改這則筆記',
      ),
      footer: PrimaryButton(
        label: '儲存',
        onPressed: _text.text.trim().isEmpty ? null : _save,
      ),
      children: [
        Gutter(
          child: AppTextField(
            controller: _text,
            hint: '例如：晚上聚餐，吃得比平常多',
            autofocus: widget.editing == null,
            maxLines: 6,
          ),
        ),
        Gutter(
          child: const Text(
            '筆記會出現在這一天的紀錄裡，不會被加總或評分。',
            style: AppTextStyles.caption,
          ),
        ),
      ],
    );
  }
}
