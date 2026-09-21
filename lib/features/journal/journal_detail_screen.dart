import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'measurement_entry_screen.dart';
import 'note_entry_screen.dart';
import 'sleep_entry_screen.dart';
import 'wellness_entry_screen.dart';
import 'weight_entry_screen.dart';

/// One weight, tape measurement, night, check-in or note from the log.
///
/// Opening a row is for reading, so this shows the record first — the
/// value, when, where it came from, and for a weight how it moved since
/// the last one — and only then offers to correct or delete it. A
/// deletion is taken back from the toast rather than confirmed up front.
class JournalDetailScreen extends StatelessWidget {
  const JournalDetailScreen({super.key, required this.id, required this.at});

  final String id;

  /// When it was taken, on the clock the person was living by.
  final DateTime at;

  void _delete(BuildContext context, String what) {
    final store = AppStoreScope.read(context);
    final toast = ToastScope.read(context);
    store.deleteJournalEntry(id);
    Navigator.of(context).pop();
    toast.showUndo('已刪除$what', onUndo: () => store.restoreJournalEntry(id));
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final entry = store.journalEntry(id);
    final when =
        '${at.month} 月 ${at.day} 日（週${weekdayLabel(at)}）· '
        '${formatTimeOfDay(at)}';
    if (entry == null) {
      return const DetailPage(
        appBar: PageAppBar(title: '紀錄'),
        children: [Gutter(child: InfoBanner(message: '這筆紀錄已經刪除。'))],
      );
    }
    final view = _viewOf(entry, store);
    return DetailPage(
      appBar: PageAppBar(title: view.title, subtitle: when),
      children: [
        Gutter(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (view.value case final value?)
                  StatBlock(
                    value: value,
                    unit: view.unit,
                    label: view.title,
                    valueColor: view.color,
                    valueStyle: AppTextStyles.hugeNumber,
                  )
                else
                  // A note has no figure; its words are the record.
                  Text(view.note, style: AppTextStyles.body),
                if (view.context case final line?) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(line, style: AppTextStyles.caption),
                ],
              ],
            ),
          ),
        ),
        if (view.value != null && view.note.isNotEmpty) ...[
          Gutter(child: const SectionLabel('備註')),
          Gutter(
            child: AppCard(child: Text(view.note, style: AppTextStyles.body)),
          ),
        ],
        Gutter(
          child: GroupedCard(
            children: [
              KeyValueRow(label: '來源', value: store.journalSourceLabel(id)),
            ],
          ),
        ),
        Gutter(child: const SectionLabel('管理')),
        Gutter(
          child: GroupedCard(
            children: [
              NavRow(
                title: '修改',
                subtitle: '時間不會改變，這筆紀錄仍留在同一天',
                onTap: () => pushPage(context, view.editor),
              ),
              NavRow(
                title: '刪除這筆紀錄',
                subtitle: '可以在提示中復原',
                onTap: () => _delete(context, view.title),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// What the page shows for each kind of journal record.
class _View {
  const _View({
    required this.title,
    required this.color,
    this.value,
    required this.editor,
    this.unit,
    this.note = '',
    this.context,
  });

  final String title;

  /// The figure, or null for a record that is only words.
  final String? value;
  final String? unit;
  final Color color;
  final String note;

  /// One line of context, never a chart: the full trend is its own page.
  final String? context;
  final Widget editor;
}

_View _viewOf(Object entry, AppStore store) => switch (entry) {
  BodyWeight weight => _View(
    title: '體重',
    value: formatWeight(weight.weightKg),
    unit: 'kg',
    color: AppColors.body,
    note: weight.note == '手動輸入' ? '' : weight.note,
    context: _sinceLast(weight, store.recentWeights),
    editor: WeightEntryScreen(editing: weight),
  ),
  BodyMeasurement measurement => _View(
    title: measurement.site.label,
    value: formatWeight(measurement.centimetres),
    unit: 'cm',
    color: AppColors.body,
    note: measurement.note,
    editor: MeasurementEntryScreen(editing: measurement),
  ),
  SleepEntry night => _View(
    title: '睡眠',
    value: formatHoursMinutes(night.duration),
    color: AppColors.wellness,
    note: night.note,
    context: night.score == null ? '沒有評分' : '品質 ${night.score} / 5',
    editor: SleepEntryScreen(editing: night),
  ),
  WellnessEntry checkIn => _View(
    title: checkIn.kind.label,
    value: '${checkIn.score}',
    unit: '/ 5',
    color: AppColors.wellness,
    note: checkIn.note,
    editor: WellnessEntryScreen(editing: checkIn),
  ),
  Note note => _View(
    title: '筆記',
    color: AppColors.wellness,
    note: note.text,
    editor: NoteEntryScreen(editing: note),
  ),
  _ => throw ArgumentError.value(entry, 'entry', 'not a journal record'),
};

/// `較上次 −0.3 kg（9/16）`, against the reading just before this one;
/// null when there is none to compare with.
String? _sinceLast(BodyWeight weight, List<BodyWeight> recent) {
  final earlier = recent
      .where((other) => other.measuredAt.isBefore(weight.measuredAt))
      .lastOrNull;
  if (earlier == null) return null;
  final change = weight.weightKg - earlier.weightKg;
  final sign = change > 0 ? '+' : (change < 0 ? '−' : '±');
  return '較上次 $sign${formatWeight(change.abs())} kg'
      '（${earlier.measuredAt.month}/${earlier.measuredAt.day}）';
}
