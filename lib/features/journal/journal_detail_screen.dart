import 'package:flutter/material.dart';

import '../../app/view_model.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'body_reading_entry_screen.dart';
import 'measurement_entry_screen.dart';
import 'note_entry_screen.dart';
import 'sleep_entry_screen.dart';
import 'wellness_entry_screen.dart';
import 'weight_entry_screen.dart';
import 'journal_view_model.dart';
import '../../l10n/l10n.dart';

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

  void _delete(BuildContext context, JournalViewModel journal, String what) {
    final toast = ToastScope.read(context);
    journal.delete(id);
    Navigator.of(context).pop();
    toast.showUndo(
      context.l10n.deletedItem(item: what),
      onUndo: () => journal.restore(id),
    );
  }

  @override
  Widget build(BuildContext context) => ViewModelBuilder(
    create: JournalViewModel.new,
    builder: (context, journal) => _page(context, journal),
  );

  Widget _page(BuildContext context, JournalViewModel journal) {
    final entry = journal.entry(id);
    final when = '${context.dates.dayWithWeekday(at)} · ${formatTimeOfDay(at)}';
    if (entry == null) {
      return DetailPage(
        appBar: PageAppBar(title: context.l10n.recordTitle),
        children: [
          Gutter(child: InfoBanner(message: context.l10n.recordDeletedNotice)),
        ],
      );
    }
    final view = _viewOf(context, entry, journal);
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
          Gutter(child: SectionLabel(context.l10n.notesSection)),
          Gutter(
            child: AppCard(child: Text(view.note, style: AppTextStyles.body)),
          ),
        ],
        Gutter(
          child: GroupedCard(
            children: [
              KeyValueRow(
                label: context.l10n.journalSourceRow,
                value: journal.sourceLabel(context.l10n, id),
              ),
            ],
          ),
        ),
        Gutter(child: SectionLabel(context.l10n.manageSection)),
        Gutter(
          child: GroupedCard(
            children: [
              NavRow(
                title: context.l10n.commonEdit,
                onTap: () => pushPage(context, view.editor),
              ),
              NavRow(
                title: context.l10n.recordDelete,
                isDestructive: true,
                onTap: () => _delete(context, journal, view.title),
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

_View _viewOf(BuildContext context, Object entry, JournalViewModel journal) =>
    switch (entry) {
      BodyWeight weight => _View(
        title: context.l10n.moduleWeight,
        value: formatWeight(weight.weightKg),
        unit: 'kg',
        color: AppColors.body,
        // l10n-ignore: what older weighings stored as their note.
        note: weight.note == '手動輸入' ? '' : weight.note,
        context: _sinceLast(context, weight, journal.recentWeights),
        editor: WeightEntryScreen(editing: weight),
      ),
      BodyMeasurement measurement => _View(
        title: measurement.site.labelIn(context.l10n),
        value: formatWeight(measurement.centimetres),
        unit: 'cm',
        color: AppColors.body,
        note: measurement.note,
        editor: MeasurementEntryScreen(editing: measurement),
      ),
      BodyReading reading => _View(
        title: reading.metric.labelIn(context.l10n),
        value: formatAmount(reading.value),
        unit: reading.metric.unitIn(context.l10n),
        color: AppColors.body,
        note: reading.note,
        context: reading.metric.isEstimated
            ? context.l10n.bodyScaleEstimate
            : null,
        editor: BodyReadingEntryScreen(editing: reading),
      ),
      SleepEntry night => _View(
        title: context.l10n.moduleSleep,
        value: formatHoursMinutes(night.duration),
        color: AppColors.wellness,
        note: night.note,
        context: switch (night.score) {
          final score? => context.l10n.sleepQualityScore(score: score),
          null => context.l10n.notRated,
        },
        editor: SleepEntryScreen(editing: night),
      ),
      WellnessEntry checkIn => _View(
        title: checkIn.kind.labelIn(context.l10n),
        value: '${checkIn.score}',
        unit: '/ 5',
        color: AppColors.wellness,
        note: checkIn.note,
        editor: WellnessEntryScreen(editing: checkIn),
      ),
      Note note => _View(
        title: context.l10n.moduleNotes,
        color: AppColors.wellness,
        note: note.text,
        editor: NoteEntryScreen(editing: note),
      ),
      _ => throw ArgumentError.value(entry, 'entry', 'not a journal record'),
    };

/// `較上次 −0.3 kg（9/16）`, against the reading just before this one;
/// null when there is none to compare with.
String? _sinceLast(
  BuildContext context,
  BodyWeight weight,
  List<BodyWeight> recent,
) {
  final earlier = recent
      .where((other) => other.measuredAt.isBefore(weight.measuredAt))
      .lastOrNull;
  if (earlier == null) return null;
  final change = weight.weightKg - earlier.weightKg;
  final sign = change > 0 ? '+' : (change < 0 ? '−' : '±');
  return context.l10n.weightSinceLast(
    change: '$sign${formatWeight(change.abs())} kg',
    date: context.dates.monthDay(earlier.measuredAt),
  );
}
