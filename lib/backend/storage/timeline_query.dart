import '../../domain/domain.dart';
import '../../shared/format.dart';
import 'database.dart';
import 'timeline_source.dart';

/// Everything recorded in one month, as the log shows it.
class MonthRecords {
  const MonthRecords({required this.days, required this.summaries});

  static const empty = MonthRecords(days: [], summaries: {});

  /// Days with records, newest first.
  final List<TimelineDay> days;

  /// Per day of the month, one short summary per recorded category, in
  /// [RecordCategory] order.
  final Map<int, Map<RecordCategory, String>> summaries;

  Map<int, List<RecordCategory>> get dots => {
    for (final MapEntry(key: day, value: byCategory) in summaries.entries)
      day: byCategory.keys.toList(),
  };
}

/// The unified log: it merges what each [TimelineSource] contributes and
/// knows nothing about workouts, meals or weights itself.
class TimelineQuery {
  TimelineQuery(this._db, this.sources);

  final AppDatabase _db;

  /// In registration order; where two sources share a category, the later
  /// one's summary wins for that day.
  final List<TimelineSource> sources;

  /// The first month holding any record, or null for an empty store.
  DateTime? earliestMonth() {
    DateTime? earliest;
    for (final source in sources) {
      final first = source.earliest();
      if (first != null && (earliest == null || first.isBefore(earliest))) {
        earliest = first;
      }
    }
    return earliest == null ? null : DateTime(earliest.year, earliest.month);
  }

  MonthRecords month(DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final today = _db.now();

    final entriesByDay = <int, List<(DateTime, TimelineEntry)>>{};
    final summaries = <int, Map<RecordCategory, String>>{};
    final warnings = <int, String>{};
    for (final source in sources) {
      for (final row in source.entriesIn(start, end)) {
        (entriesByDay[row.$1.day] ??= []).add(row);
      }
      for (final MapEntry(key: day, value: summary)
          in source.summariesIn(start, end).entries) {
        (summaries[day] ??= {})[source.category] = summary;
      }
      warnings.addAll(source.warningsIn(start, end));
    }

    final days = entriesByDay.keys.toList()..sort((a, b) => b - a);
    return MonthRecords(
      days: [
        for (final day in days)
          TimelineDay(
            label: _dayLabel(DateTime(month.year, month.month, day), today),
            warning: warnings[day],
            entries: [
              for (final (_, entry)
                  in entriesByDay[day]!..sort((a, b) => b.$1.compareTo(a.$1)))
                entry,
            ],
          ),
      ],
      summaries: {
        for (final day in summaries.keys.toList()..sort())
          day: {
            for (final category in RecordCategory.values)
              category: ?summaries[day]![category],
          },
      },
    );
  }

  static String _dayLabel(DateTime day, DateTime today) {
    final label = '${day.month} 月 ${day.day} 日（週${weekdayLabel(day)}）';
    final isToday =
        day.year == today.year &&
        day.month == today.month &&
        day.day == today.day;
    return isToday ? '今天 · $label' : label;
  }
}
