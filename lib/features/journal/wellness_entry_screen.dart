import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';

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
  late WellnessKind _kind = widget.editing?.kind ?? WellnessKind.energy;
  late int _score = widget.editing?.score ?? 3;
  late final _note = TextEditingController(text: widget.editing?.note ?? '');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final store = AppStoreScope.read(context);
    final editing = widget.editing;
    if (editing == null) {
      store.recordWellness(_kind, _score, note: _note.text.trim());
    } else {
      store.updateWellness(
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
      '${editing == null ? '已記錄' : '已更新'}${_kind.label} $_score / 5',
      kind: ToastKind.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DetailPage(
      appBar: widget.editing == null
          ? const PageAppBar(title: '今天的狀態', subtitle: '心情、精力與症狀')
          : PageAppBar(title: _kind.label, subtitle: '修改這筆紀錄'),
      footer: PrimaryButton(label: '儲存', onPressed: _save),
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
              labelOf: (kind) => kind.label,
              selectedColor: AppColors.wellness,
              onChanged: (kind) => setState(() => _kind = kind),
            ),
          ),
        Gutter(
          child: SectionLabel(
            _kind == WellnessKind.symptom ? '不適程度' : '${_kind.label}如何？',
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
        Gutter(child: const SectionLabel('備註（可略過）')),
        Gutter(
          child: AppTextField(controller: _note, hint: '例如：久坐一整天，下背有點緊'),
        ),
        Gutter(
          child: const Text(
            '狀態紀錄用來對照訓練與飲食，不會被評價成好壞。',
            style: AppTextStyles.caption,
          ),
        ),
      ],
    );
  }
}
