import '../../domain/domain.dart';
import '../../shared/format.dart';
import 'database.dart';
import 'timeline_source.dart';

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

  /// Every record of [day], oldest first: the day as it went.
  List<TimelineEntry> day(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day + 1);
    final rows = [for (final source in sources) ...source.entriesIn(start, end)]
      ..sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final (_, entry) in rows) entry];
  }

  /// The kinds of record on each day of [month] that has any, for marking
  /// a calendar: the summaries alone, without reading every entry.
  Map<int, List<RecordCategory>> categoriesIn(DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final byDay = <int, Set<RecordCategory>>{};
    for (final source in sources) {
      for (final day in source.summariesIn(start, end).keys) {
        (byDay[day] ??= {}).add(source.category);
      }
    }
    return {
      for (final MapEntry(key: day, value: categories) in byDay.entries)
        day: [
          for (final category in RecordCategory.values)
            if (categories.contains(category)) category,
        ],
    };
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
